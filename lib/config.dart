import 'dart:convert';

/// Conexión a Supabase, pasada al compilar desde el `.env`:
///
///   flutter run --dart-define-from-file=.env
///
/// Solo se usan la URL y la clave pública (publishable o anon). Esa clave puede ir
/// dentro de la app porque las políticas RLS limitan cada cuenta a sus propios datos.
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get key => _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// Qué falta o está mal en la configuración; null si se puede conectar.
  static String? get problem {
    if (url.isEmpty || key.isEmpty) {
      return 'Faltan SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY (o SUPABASE_ANON_KEY). '
          'Ejecuta la app con: flutter run --dart-define-from-file=.env';
    }
    if (_isSecret(key)) {
      return 'La clave es secreta (service_role). Usa la clave pública: '
          'nunca pongas la secreta dentro de la app.';
    }
    return null;
  }

  static bool _isSecret(String key) {
    if (key.startsWith('sb_secret_')) return true;
    // Claves antiguas: un JWT cuyo rol dice si es pública (anon) o secreta.
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return (jsonDecode(payload) as Map<String, dynamic>)['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
