import '../models/models.dart';

/// Grupos musculares, en el orden de los filtros de la biblioteca.
const muscleGroups = <MuscleGroup>[
  MuscleGroup('pecho', 'Pecho'),
  MuscleGroup('espalda', 'Espalda'),
  MuscleGroup('hombros', 'Hombros'),
  MuscleGroup('biceps', 'Bíceps'),
  MuscleGroup('triceps', 'Tríceps'),
  MuscleGroup('antebrazo', 'Antebrazo'),
  MuscleGroup('piernas', 'Piernas'),
  MuscleGroup('pantorrillas', 'Pantorrillas'),
  MuscleGroup('core', 'Core'),
  MuscleGroup('cardio', 'Cardio'),
];

String groupLabel(String id) {
  for (final g in muscleGroups) {
    if (g.id == id) return g.label;
  }
  return id;
}

Exercise _e(
  String id,
  String name,
  String group, [
  ExerciseKind kind = ExerciseKind.weight,
]) => Exercise(id: id, name: name, group: group, kind: kind);

/// Biblioteca base de ejercicios.
final baseExercises = <Exercise>[
  _e('press-banca', 'Press de banca', 'pecho'),
  _e('flexiones', 'Flexiones', 'pecho', ExerciseKind.reps),
  _e('aperturas', 'Aperturas con mancuernas', 'pecho'),
  _e('press-inclinado', 'Press inclinado con mancuernas', 'pecho'),
  _e('cruce-poleas', 'Cruce en poleas', 'pecho'),
  _e('dominadas', 'Dominadas', 'espalda', ExerciseKind.reps),
  _e('remo-barra', 'Remo con barra', 'espalda'),
  _e('jalon', 'Jalón al pecho', 'espalda'),
  _e('peso-muerto', 'Peso muerto', 'espalda'),
  _e('remo-mancuerna', 'Remo con mancuerna', 'espalda'),
  _e('sentadilla', 'Sentadilla', 'piernas'),
  _e('prensa', 'Prensa de piernas', 'piernas'),
  _e('zancadas', 'Zancadas', 'piernas'),
  _e('pantorrillas', 'Elevación de pantorrillas', 'pantorrillas'),
  _e('pantorrillas-sentado', 'Pantorrillas sentado', 'pantorrillas'),
  _e('curl-femoral', 'Curl femoral', 'piernas'),
  _e('press-militar', 'Press militar', 'hombros'),
  _e('elevaciones-laterales', 'Elevaciones laterales', 'hombros'),
  _e('pajaros', 'Pájaros', 'hombros'),
  _e('face-pull', 'Face pull', 'hombros'),
  _e('curl', 'Curl de bíceps', 'biceps'),
  _e('curl-martillo', 'Curl martillo', 'biceps'),
  _e('curl-predicador', 'Curl predicador', 'biceps'),
  _e('fondos', 'Fondos en paralelas', 'triceps', ExerciseKind.reps),
  _e('extension-triceps', 'Extensión de tríceps en polea', 'triceps'),
  _e('press-frances', 'Press francés', 'triceps'),
  _e('curl-muneca', 'Curl de muñeca', 'antebrazo'),
  _e('curl-muneca-inverso', 'Curl de muñeca inverso', 'antebrazo'),
  _e('plancha', 'Plancha', 'core', ExerciseKind.seconds),
  _e('abdominales', 'Abdominales', 'core', ExerciseKind.reps),
  _e(
    'elevacion-piernas',
    'Elevación de piernas colgado',
    'core',
    ExerciseKind.reps,
  ),
  _e('rueda', 'Rueda abdominal', 'core', ExerciseKind.reps),
];
