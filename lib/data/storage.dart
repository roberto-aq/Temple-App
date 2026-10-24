import 'package:shared_preferences/shared_preferences.dart';

/// Un documento JSON guardado en el teléfono.
abstract class AppStorage {
  Future<String?> load();
  Future<void> save(String json);
  Future<void> clear();
}

class PrefsStorage implements AppStorage {
  PrefsStorage(this._prefs, this._key);

  final SharedPreferences _prefs;
  final String _key;

  /// Copia local de los datos de una cuenta, para abrir la app sin conexión.
  factory PrefsStorage.cache(SharedPreferences prefs, String userId) => PrefsStorage(prefs, 'temple.cache.$userId');

  /// Cambios de una cuenta que aún no llegan a Supabase.
  factory PrefsStorage.outbox(SharedPreferences prefs, String userId) => PrefsStorage(prefs, 'temple.outbox.$userId');

  @override
  Future<String?> load() async => _prefs.getString(_key);

  @override
  Future<void> save(String json) => _prefs.setString(_key, json);

  @override
  Future<void> clear() => _prefs.remove(_key);
}

/// Para tests: guarda en memoria.
class MemoryStorage implements AppStorage {
  MemoryStorage([this.data]);
  String? data;

  @override
  Future<String?> load() async => data;

  @override
  Future<void> save(String json) async => data = json;

  @override
  Future<void> clear() async => data = null;
}
