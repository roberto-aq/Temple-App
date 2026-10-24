import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../data/storage.dart';
import '../state/account.dart';
import '../state/app_state.dart';
import '../sync/remote.dart';
import '../sync/sync_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';

/// Muestra el inicio de sesión o la app, según haya una cuenta abierta.
///
/// La sesión se guarda en el teléfono: si la app se abre sin conexión, sigue
/// abierta aunque el token haya vencido, y se renueva cuando vuelve la red.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = Supabase.instance.client.auth;
  late User? _user = _auth.currentUser;
  late final StreamSubscription<AuthState> _sub;

  @override
  void initState() {
    super.initState();
    _sub = _auth.onAuthStateChange.listen(
      (s) {
        // Algunos eventos llegan sin sesión aunque siga abierta; manda la sesión actual.
        final user = s.session?.user ?? _auth.currentUser;
        if (user?.id != _user?.id) setState(() => _user = user);
      },
      // Fallos de red al renovar el token: la sesión sigue, se reintenta sola.
      onError: (Object e) => debugPrint('Temple auth: $e'),
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) return templeMaterialApp(home: const AuthScreen());
    return _AccountView(
      key: ValueKey(user.id),
      user: user,
      prefs: widget.prefs,
    );
  }
}

/// Estado y sincronización de una cuenta, mientras está abierta.
class _AccountView extends StatefulWidget {
  const _AccountView({super.key, required this.user, required this.prefs});

  final User user;
  final SharedPreferences prefs;

  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  late final SyncService _sync;
  late final AppState _state;
  late final Account _account;
  late final Future<void> _ready;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final id = widget.user.id;
    _sync = SyncService(
      backend: SupabaseBackend(Supabase.instance.client, id),
      storage: PrefsStorage.outbox(widget.prefs, id),
    );
    _state = AppState(
      storage: PrefsStorage.cache(widget.prefs, id),
      sync: _sync,
    );
    _account = Account(
      email: widget.user.email ?? '',
      sync: _sync,
      signOut: _signOut,
    );
    _ready = _open();
    _lifecycle = AppLifecycleListener(
      onResume: () => _sync.refresh(),
      onHide: () => _sync.flush(),
    );
  }

  /// Abre con la copia local (al instante, sin red) y luego trae lo del servidor.
  Future<void> _open() async {
    try {
      await _sync.load();
      await _state.load();
    } catch (e) {
      // Una copia local dañada no debe impedir entrar: se reemplaza al descargar.
      debugPrint('Temple: copia local ilegible: $e');
    }
    unawaited(_sync.refresh());
  }

  Future<void> _signOut() async {
    final id = widget.user.id;
    await PrefsStorage.cache(widget.prefs, id).clear();
    await PrefsStorage.outbox(widget.prefs, id).clear();
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      // Sin red la sesión local ya quedó cerrada; solo falla el aviso al servidor.
      debugPrint('Temple auth: $e');
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _state.dispose();
    _sync.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snap) => snap.connectionState == ConnectionState.done
          ? TempleApp(state: _state, account: _account)
          : const ColoredBox(color: AppColors.background),
    );
  }
}
