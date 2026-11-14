import '../logic/format.dart';
import '../models/intervals.dart';
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
  'unit': s.unit.name,
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
    unit: WeightUnit.fromName(r['unit'] as String?),
    time: DateTime.parse(r['logged_at'] as String).toLocal(),
  ),
);

Map<String, dynamic> intervalProtocolRow(IntervalProtocol p) => {
  'id': p.id,
  'name': p.name,
  'work_seconds': p.workSeconds,
  'rest_seconds': p.restSeconds,
  'rounds': p.rounds,
  'sided': p.sided,
  'switch_seconds': p.switchSeconds,
  'weighted': p.weighted,
};

IntervalProtocol intervalProtocolFromRow(Map<String, dynamic> r) =>
    IntervalProtocol(
      id: r['id'] as String,
      name: r['name'] as String,
      workSeconds: (r['work_seconds'] as num).toInt(),
      restSeconds: (r['rest_seconds'] as num).toInt(),
      rounds: (r['rounds'] as num).toInt(),
      sided: r['sided'] as bool? ?? false,
      switchSeconds: (r['switch_seconds'] as num?)?.toInt() ?? 10,
      weighted: r['weighted'] as bool? ?? false,
    );

Map<String, dynamic> intervalSessionRow(IntervalSession s) => {
  'id': s.id,
  'protocol_id': s.protocolId,
  'day': dayKey(s.day),
  'started_at': s.startedAt.toUtc().toIso8601String(),
  'name': s.name,
  'work_seconds': s.workSeconds,
  'rest_seconds': s.restSeconds,
  'rounds': s.rounds,
  'sided': s.sided,
  'kg': s.kg,
  'unit': s.unit.name,
  'done': [
    for (final r in s.done) {'r': r.round, 'side': r.side.name, 's': r.seconds},
  ],
  'notes': s.notes,
};

IntervalSession intervalSessionFromRow(Map<String, dynamic> r) =>
    IntervalSession(
      id: r['id'] as String,
      protocolId: r['protocol_id'] as String?,
      name: r['name'] as String,
      day: parseDayKey(r['day'] as String),
      startedAt: DateTime.parse(r['started_at'] as String).toLocal(),
      workSeconds: (r['work_seconds'] as num).toInt(),
      restSeconds: (r['rest_seconds'] as num).toInt(),
      rounds: (r['rounds'] as num).toInt(),
      sided: r['sided'] as bool? ?? false,
      done: [
        for (final (i, d) in (r['done'] as List? ?? const []).indexed)
          IntervalRound(
            ((d as Map<String, dynamic>)['r'] as num?)?.toInt() ?? i + 1,
            IntervalSide.fromName(d['side'] as String?),
            (d['s'] as num).toInt(),
          ),
      ],
      kg: (r['kg'] as num?)?.toDouble(),
      unit: WeightUnit.fromName(r['unit'] as String?),
      notes: r['notes'] as String?,
    );
