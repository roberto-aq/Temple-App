import 'package:supabase_flutter/supabase_flutter.dart';

import 'outbox.dart';

/// Lo que la sincronización necesita del servidor. En tests se reemplaza por uno en memoria.
abstract class RemoteBackend {
  /// Todas las filas de la cuenta en esa tabla, en el orden en que la app las muestra.
  Future<List<Map<String, dynamic>>> fetch(SyncTable table);
  Future<void> upsert(SyncTable table, List<Map<String, dynamic>> rows);
  Future<void> delete(SyncTable table, List<String> keys);
}

class SupabaseBackend implements RemoteBackend {
  SupabaseBackend(this._db, this._userId);

  final SupabaseClient _db;
  final String _userId;

  static const _pageSize = 1000;

  static const _columns = {
    SyncTable.exercises: 'id, name, muscle_group, kind',
    SyncTable.routines: 'id, name, items',
    SyncTable.dayPlans: 'day, routine_ids, exercise_ids',
    SyncTable.sets: 'id, day, exercise_id, reps, kg, unit, logged_at',
    SyncTable.intervalProtocols:
        'id, name, work_seconds, rest_seconds, rounds, sided, switch_seconds, weighted',
    SyncTable.intervalSessions:
        'id, protocol_id, day, started_at, name, work_seconds, rest_seconds, rounds, sided, kg, unit, done, notes',
  };

  @override
  Future<List<Map<String, dynamic>>> fetch(SyncTable table) async {
    final out = <Map<String, dynamic>>[];
    // Por páginas: la API devuelve como mucho `max_rows` filas por consulta.
    while (true) {
      final query = _db
          .from(table.table)
          .select(_columns[table]!)
          .eq('user_id', _userId);
      final ordered = switch (table) {
        SyncTable.exercises =>
          query.order('created_at').order('id', ascending: true),
        SyncTable.routines =>
          query
              .order('created_at', ascending: true)
              .order('id', ascending: true),
        SyncTable.dayPlans => query.order('day', ascending: true),
        SyncTable.sets =>
          query
              .order('day', ascending: true)
              .order('logged_at', ascending: true)
              .order('id', ascending: true),
        SyncTable.intervalProtocols =>
          query
              .order('created_at', ascending: true)
              .order('id', ascending: true),
        SyncTable.intervalSessions =>
          query
              .order('started_at', ascending: true)
              .order('id', ascending: true),
      };
      final page = await ordered.range(out.length, out.length + _pageSize - 1);
      if (page.isEmpty) return out;
      out.addAll(page);
    }
  }

  @override
  Future<void> upsert(SyncTable table, List<Map<String, dynamic>> rows) =>
      _db.from(table.table).upsert([
        for (final r in rows) {...r, 'user_id': _userId},
      ], onConflict: table == SyncTable.dayPlans ? 'user_id,day' : 'id');

  @override
  Future<void> delete(SyncTable table, List<String> keys) => _db
      .from(table.table)
      .delete()
      .eq('user_id', _userId)
      .inFilter(table.keyColumn, keys);
}
