import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException, AuthRetryableFetchException, PostgrestException;

import '../data/storage.dart';
import 'outbox.dart';
import 'remote.dart';

enum SyncStatus { synced, syncing, offline, error }

typedef Snapshot = Map<SyncTable, List<Map<String, dynamic>>>;

/// Sube los cambios locales a Supabase y descarga el estado del servidor.
///
/// La app nunca espera a la red: cada cambio se aplica en el teléfono y entra a
/// una cola ([Outbox]) que se envía en cuanto hay conexión. Al descargar, el
/// estado del servidor se combina con lo que todavía está en la cola.
class SyncService extends ChangeNotifier {
  SyncService({required RemoteBackend backend, required AppStorage storage, DateTime Function()? clock})
      : _remote = backend,
        _outbox = Outbox(storage),
        _clock = clock ?? DateTime.now;

  final RemoteBackend _remote;
  final Outbox _outbox;
  final DateTime Function() _clock;

  /// Recibe lo descargado y los cambios que aún no se suben (ver [AppState.applyRemote]).
  void Function(Snapshot rows, List<Change> pending)? onSnapshot;

  SyncStatus _status = SyncStatus.synced;
  DateTime? _lastSynced;
  String? _lastError;
  int _discarded = 0;

  SyncStatus get status => _status;
  int get pending => _outbox.length;
  DateTime? get lastSynced => _lastSynced;
  String? get lastError => _lastError;

  /// Cambios que el servidor rechazó por inválidos (no deberían ocurrir).
  int get discarded => _discarded;

  Future<void> load() => _outbox.load();

  /// Pone un cambio en la cola y lo envía en breve (agrupa toques seguidos).
  void enqueue(Change change) {
    _outbox.add(change);
    _notify();
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 600), flush);
  }

  /// Sube lo pendiente y descarga todo.
  Future<void> refresh() => _run(pull: true);

  /// Solo sube lo pendiente.
  Future<void> flush() => _run(pull: false);

  // ---------------------------------------------------------------------------

  Timer? _flushTimer;
  Timer? _retryTimer;
  int _attempt = 0;
  Future<void>? _running;
  bool _again = false;
  bool _wantPull = false;
  bool _disposed = false;

  /// Una sola sincronización a la vez; lo pedido mientras corre se hace al terminar.
  Future<void> _run({required bool pull}) async {
    _wantPull |= pull;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final run = _loop();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
    }
  }

  Future<void> _loop() async {
    do {
      _again = false;
      final pull = _wantPull;
      _wantPull = false;
      if (!await _cycle(pull)) return;
    } while (_again && !_disposed);
  }

  Future<bool> _cycle(bool pull) async {
    if (_disposed) return false;
    if (!pull && _outbox.length == 0) return true;
    _retryTimer?.cancel();
    _setStatus(SyncStatus.syncing);
    try {
      await _push();
      if (pull) {
        final rows = <SyncTable, List<Map<String, dynamic>>>{};
        for (final t in SyncTable.values) {
          rows[t] = await _remote.fetch(t);
        }
        // Lo que se registró mientras se descargaba sigue en la cola y se aplica encima.
        if (!_disposed) onSnapshot?.call(rows, _outbox.changes);
      }
      _lastSynced = _clock();
      _attempt = 0;
      _lastError = null;
      _setStatus(SyncStatus.synced);
      return true;
    } catch (e) {
      if (_disposed) return false;
      debugPrint('Temple sync: $e');
      _wantPull |= pull;
      final offline = e is AuthRetryableFetchException || (e is! PostgrestException && e is! AuthException);
      _lastError = offline ? null : _describe(e);
      _setStatus(offline ? SyncStatus.offline : SyncStatus.error);
      // Reintenta con espera creciente: 5 s, 10 s, 20 s… hasta 1 min.
      final wait = Duration(seconds: math.min(60, 5 * (1 << math.min(_attempt, 4))));
      _attempt++;
      _retryTimer = Timer(wait, () => _run(pull: _wantPull));
      return false;
    }
  }

  Future<void> _push() async {
    final batch = _outbox.changes;
    for (final table in SyncTable.values) {
      await _send(table, [for (final c in batch) if (c.table == table && !c.isDelete) c]);
      await _send(table, [for (final c in batch) if (c.table == table && c.isDelete) c]);
    }
  }

  /// Envía cambios de una tabla (todos upserts o todos borrados) en grupos de 100.
  Future<void> _send(SyncTable table, List<Change> changes) async {
    for (var i = 0; i < changes.length; i += 100) {
      final chunk = changes.sublist(i, math.min(i + 100, changes.length));
      try {
        await _write(table, chunk);
      } on PostgrestException catch (e) {
        if (!_isRejected(e)) rethrow;
        // Algún cambio no es válido: se envían de a uno y se descartan los rechazados
        // para que no bloqueen la cola para siempre.
        for (final c in chunk) {
          try {
            await _write(table, [c]);
          } on PostgrestException catch (e) {
            if (!_isRejected(e)) rethrow;
            debugPrint('Temple sync: descartado ${table.table}/${c.key}: ${e.message}');
            _discarded++;
          }
          _outbox.remove([c]);
        }
        _notify();
        continue;
      }
      _outbox.remove(chunk);
      _notify();
    }
  }

  Future<void> _write(SyncTable table, List<Change> changes) => changes.first.isDelete
      ? _remote.delete(table, [for (final c in changes) c.key])
      : _remote.upsert(table, [for (final c in changes) c.row!]);

  /// Errores de datos o de permisos: reintentar no los arregla.
  static bool _isRejected(PostgrestException e) {
    final code = e.code ?? '';
    return code.startsWith('22') || code.startsWith('23') || code == '42501';
  }

  static String _describe(Object e) => switch (e) {
        PostgrestException(:final message) => message,
        AuthException(:final message) => message,
        _ => '$e',
      };

  void _setStatus(SyncStatus s) {
    _status = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
