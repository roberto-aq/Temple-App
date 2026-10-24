import '../logic/format.dart';
import '../models/models.dart';

// Conversión entre el modelo de la app y las filas de Supabase.
// Las columnas son las de supabase/migrations; user_id lo agrega SupabaseBackend.

Map<String, dynamic> exerciseRow(Exercise e) => {
  'id': e.id,
  'name': e.name,
  'muscle_group': e.group,
  'kind': e.kind.name,
};

Exercise exerciseFromRow(Map<String, dynamic> r) => Exercise(
  id: r['id'] as String,
  name: r['name'] as String,
  group: r['muscle_group'] as String,
  kind: ExerciseKind.fromName(r['kind'] as String?),
  custom: true,
);

Map<String, dynamic> routineRow(Routine r) => {
  'id': r.id,
  'name': r.name,
  'items': [for (final i in r.items) i.toJson()],
};

Routine routineFromRow(Map<String, dynamic> r) => Routine.fromJson(r);

Map<String, dynamic> dayPlanRow(String day, DayPlan p) => {
  'day': day,
  'routine_ids': List.of(p.routineIds),
  'exercise_ids': List.of(p.exerciseIds),
};

DayPlan dayPlanFromRow(Map<String, dynamic> r) => DayPlan(
  routineIds: List<String>.from(r['routine_ids'] as List? ?? const []),
  exerciseIds: List<String>.from(r['exercise_ids'] as List? ?? const []),
);

/// La serie siempre lleva `id` y hora (ver [AppState.addSet]).
Map<String, dynamic> setRow(String day, String exerciseId, SetEntry s) => {
  'id': s.id,
  'day': day,
  'exercise_id': exerciseId,
  'reps': s.reps,
  'kg': s.kg,
  'logged_at': s.time!.toUtc().toIso8601String(),
};

({String day, String exerciseId, SetEntry entry}) setFromRow(
  Map<String, dynamic> r,
) => (
  // `day` llega como «2026-10-23»; se normaliza por si acaso.
  day: dayKey(parseDayKey(r['day'] as String)),
  exerciseId: r['exercise_id'] as String,
  entry: SetEntry(
    id: r['id'] as String,
    reps: (r['reps'] as num).toInt(),
    kg: (r['kg'] as num?)?.toDouble(),
    time: DateTime.parse(r['logged_at'] as String).toLocal(),
  ),
);
