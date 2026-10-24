import 'dart:convert';

import '../data/storage.dart';

/// Tablas de Supabase que sincroniza la app (ver supabase/migrations).
enum SyncTable {
  exercises('exercises', 'id'),
  routines('routines', 'id'),
  dayPlans('day_plans', 'day'),
  sets('sets', 'id');

  const SyncTable(this.table, this.keyColumn);

  final String table;

  /// Columna que identifica la fila dentro de la cuenta.
  final String keyColumn;

  static SyncTable byName(String table) =>
      values.firstWhere((t) => t.table == table);
}

/// Un cambio local: la fila completa tal como debe quedar, o `null` si se borró.
class Change {
  const Change(this.table, this.key, this.row, {this.seq = 0});

  final SyncTable table;
  final String key;
  final Map<String, dynamic>? row;

  /// Orden de llegada a la cola; distingue dos cambios de la misma fila.
  final int seq;

  bool get isDelete => row == null;

  Map<String, dynamic> toJson() => {
    'seq': seq,
    't': table.table,
    'k': key,
    'r': row,
  };

  factory Change.fromJson(Map<String, dynamic> j) => Change(
    SyncTable.byName(j['t'] as String),
    j['k'] as String,
    j['r'] as Map<String, dynamic>?,
    seq: (j['seq'] as num).toInt(),
  );
}

/// Cola de cambios pendientes de subir, guardada en el teléfono.
/// De cada fila solo se guarda el último cambio: es lo único que hace falta enviar.
class Outbox {
  Outbox(this._storage);

  final AppStorage _storage;
  final List<Change> _items = [];
  int _seq = 0;

  List<Change> get changes => List.unmodifiable(_items);
  int get length => _items.length;

  Future<void> load() async {
    final raw = await _storage.load();
    if (raw == null) return;
    _items
      ..clear()
      ..addAll([
        for (final c in jsonDecode(raw) as List)
          Change.fromJson(c as Map<String, dynamic>),
      ]);
    for (final c in _items) {
      if (c.seq > _seq) _seq = c.seq;
    }
  }

  void add(Change c) {
    _items
      ..removeWhere((o) => o.table == c.table && o.key == c.key)
      ..add(Change(c.table, c.key, c.row, seq: ++_seq));
    _save();
  }

  /// Quita los cambios ya enviados. Si una fila cambió otra vez mientras tanto, ese cambio nuevo se queda.
  void remove(Iterable<Change> sent) {
    final seqs = {for (final c in sent) c.seq};
    _items.removeWhere((c) => seqs.contains(c.seq));
    _save();
  }

  void _save() =>
      _storage.save(jsonEncode([for (final c in _items) c.toJson()]));
}
