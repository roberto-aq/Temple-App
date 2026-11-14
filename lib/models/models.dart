/// Qué se registra en cada serie de un ejercicio.
enum ExerciseKind {
  /// Repeticiones y peso (press, sentadilla, curl).
  weight,

  /// Solo repeticiones (dominadas, flexiones).
  reps,

  /// Tiempo en segundos (plancha).
  seconds;

  static ExerciseKind fromName(String? name) => ExerciseKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => ExerciseKind.weight,
  );
}

class MuscleGroup {
  const MuscleGroup(this.id, this.label);
  final String id;
  final String label;
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.group,
    required this.kind,
    this.custom = false,
  });

  final String id;
  final String name;
  final String group;
  final ExerciseKind kind;

  /// Creado por el usuario (no viene en la biblioteca base).
  final bool custom;

  bool get weighted => kind == ExerciseKind.weight;
  bool get timed => kind == ExerciseKind.seconds;

  /// Paso de los botones +/− de repeticiones o segundos.
  int get step => timed ? 5 : 1;

  /// Máximo por serie: 300 repeticiones o 3 horas (en segundos).
  int get maxReps => timed ? 3 * 3600 : 300;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'group': group,
    'kind': kind.name,
  };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String,
    name: j['name'] as String,
    group: j['group'] as String,
    kind: ExerciseKind.fromName(j['kind'] as String?),
    custom: true,
  );
}

/// Unidad en que se anota el peso. Se guarda siempre en kg; la unidad solo
/// dice cómo mostrarlo.
enum WeightUnit {
  kg('kg', 'kilos'),
  lb('lb', 'libras');

  const WeightUnit(this.symbol, this.word);
  final String symbol;
  final String word;

  static const _kgPerLb = 0.45359237;

  /// De kg a esta unidad.
  double fromKg(double v) => this == lb ? v / _kgPerLb : v;

  /// De esta unidad a kg, con 2 decimales como en Supabase.
  double toKg(double v) => this == lb ? (v * _kgPerLb * 100).round() / 100 : v;

  static WeightUnit fromName(String? name) =>
      name == WeightUnit.lb.name ? WeightUnit.lb : WeightUnit.kg;
}

/// Una serie registrada. `reps` son segundos en ejercicios de tiempo; `kg` es null si no lleva peso.
/// `unit` es la unidad en que se anotó el peso. `id` lo asigna [AppState] al registrarla.
class SetEntry {
  const SetEntry({
    this.id,
    required this.reps,
    this.kg,
    this.unit = WeightUnit.kg,
    this.time,
  });

  final String? id;
  final int reps;
  final double? kg;
  final WeightUnit unit;
  final DateTime? time;

  SetEntry copyWith({
    String? id,
    int? reps,
    double? kg,
    WeightUnit? unit,
    DateTime? time,
  }) => SetEntry(
    id: id ?? this.id,
    reps: reps ?? this.reps,
    kg: kg ?? this.kg,
    unit: unit ?? this.unit,
    time: time ?? this.time,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'reps': reps,
    if (kg != null) 'kg': kg,
    if (unit != WeightUnit.kg) 'u': unit.name,
    if (time != null) 't': time!.millisecondsSinceEpoch,
  };

  factory SetEntry.fromJson(Map<String, dynamic> j) => SetEntry(
    id: j['id'] as String?,
    reps: (j['reps'] as num).toInt(),
    kg: (j['kg'] as num?)?.toDouble(),
    unit: WeightUnit.fromName(j['u'] as String?),
    time: j['t'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
  );
}

class RoutineItem {
  const RoutineItem({required this.exerciseId, this.sets = 3, this.reps = 10});

  final String exerciseId;
  final int sets;
  final int reps;

  Map<String, dynamic> toJson() => {
    'ex': exerciseId,
    'sets': sets,
    'reps': reps,
  };

  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
    exerciseId: j['ex'] as String,
    sets: (j['sets'] as num?)?.toInt() ?? 3,
    reps: (j['reps'] as num?)?.toInt() ?? 10,
  );
}

class Routine {
  const Routine({required this.id, required this.name, required this.items});

  final String id;
  final String name;
  final List<RoutineItem> items;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
    id: j['id'] as String,
    name: j['name'] as String,
    items: (j['items'] as List)
        .map((i) => RoutineItem.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
}

/// Lo que se planeó entrenar un día: rutinas cargadas y ejercicios en orden.
class DayPlan {
  DayPlan({List<String>? routineIds, List<String>? exerciseIds})
    : routineIds = routineIds ?? [],
      exerciseIds = exerciseIds ?? [];

  final List<String> routineIds;
  final List<String> exerciseIds;

  Map<String, dynamic> toJson() => {
    'routines': routineIds,
    'items': exerciseIds,
  };

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
    routineIds: List<String>.from(j['routines'] as List? ?? const []),
    exerciseIds: List<String>.from(j['items'] as List? ?? const []),
  );
}

/// Todas las series de un ejercicio en un día.
class ExerciseSession {
  const ExerciseSession(this.date, this.sets);
  final DateTime date;
  final List<SetEntry> sets;
}
