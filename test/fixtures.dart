import 'package:temple/models/models.dart';

Routine _r(String id, String name, List<(String, int, int)> items) => Routine(
  id: id,
  name: name,
  items: [
    for (final (ex, sets, reps) in items)
      RoutineItem(exerciseId: ex, sets: sets, reps: reps),
  ],
);

/// Las rutinas con las que arranca cada cuenta (las crea la base de datos al registrarse;
/// ver supabase/migrations). Aquí con ids fijos para los tests.
final starterRoutines = <Routine>[
  _r('r1', 'Pecho y tríceps', [
    ('press-banca', 4, 8),
    ('flexiones', 3, 15),
    ('aperturas', 3, 12),
    ('fondos', 3, 10),
  ]),
  _r('r2', 'Espalda y bíceps', [
    ('dominadas', 4, 8),
    ('remo-barra', 4, 10),
    ('jalon', 3, 12),
    ('curl', 3, 12),
  ]),
  _r('r3', 'Piernas', [
    ('sentadilla', 4, 8),
    ('prensa', 4, 12),
    ('zancadas', 3, 10),
    ('pantorrillas', 4, 15),
  ]),
  _r('r4', 'Hombros', [
    ('press-militar', 4, 8),
    ('elevaciones-laterales', 3, 15),
    ('pajaros', 3, 15),
  ]),
  _r('r5', 'Full body y core', [
    ('peso-muerto', 4, 6),
    ('plancha', 3, 45),
    ('abdominales', 3, 20),
  ]),
];
