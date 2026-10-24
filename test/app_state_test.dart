import 'package:flutter_test/flutter_test.dart';
import 'package:temple/data/storage.dart';
import 'package:temple/logic/progress.dart';
import 'package:temple/models/models.dart';
import 'package:temple/state/app_state.dart';

import 'fixtures.dart';

/// Viernes 23 de octubre de 2026, 18:00.
final fixedNow = DateTime(2026, 10, 23, 18);
final today = DateTime(2026, 10, 23);
final monday = DateTime(2026, 10, 19);

AppState newState([MemoryStorage? storage]) => AppState(
  storage: storage ?? MemoryStorage(),
  clock: () => fixedNow,
  routines: starterRoutines,
);

void main() {
  test('arranca con las 5 rutinas y la biblioteca base', () {
    final app = newState();
    expect(app.routines.map((r) => r.name), contains('Pecho y tríceps'));
    expect(app.routines, hasLength(5));
    expect(app.exercise('press-banca')!.name, 'Press de banca');
    expect(app.selectedDay, today);
  });

  test('no se puede elegir un día futuro', () {
    final app = newState();
    app.selectDay(DateTime(2026, 10, 24));
    expect(app.selectedDay, today);
    app.selectDay(monday);
    expect(app.selectedDay, monday);
    expect(app.dayWord(monday), 'el lunes');
  });

  test('cargar rutina, nombre de sesión y quitar ejercicios', () {
    final app = newState();
    app.loadRoutine('r1', today);
    expect(app.sessionExercises(today), [
      'press-banca',
      'flexiones',
      'aperturas',
      'fondos',
    ]);
    expect(app.sessionName(today), 'Pecho y tríceps');

    app.loadRoutine('r4', today);
    expect(app.sessionName(today), 'Pecho y tríceps + Hombros');
    expect(app.sessionExercises(today), hasLength(7));

    for (final id in app.sessionExercises(today)) {
      app.removeExerciseFromDay(today, id);
    }
    expect(app.sessionExercises(today), isEmpty);
    expect(app.sessionName(today), 'Entrenamiento');
  });

  test('las series registradas fuera del plan aparecen en la sesión', () {
    final app = newState();
    app.addSet(today, 'curl', const SetEntry(reps: 12, kg: 25));
    expect(app.sessionExercises(today), ['curl']);
    expect(app.trainedOn(today), isTrue);
    app.removeSet(today, 'curl', 0);
    expect(app.sessionExercises(today), isEmpty);
    expect(app.trainedOn(today), isFalse);
  });

  test('editar una serie conserva su hora', () {
    final app = newState();
    final t = DateTime(2026, 10, 23, 17, 30);
    app.addSet(today, 'press-banca', SetEntry(reps: 8, kg: 60, time: t));
    app.replaceSet(today, 'press-banca', 0, const SetEntry(reps: 9, kg: 60));
    final s = app.setsOn(today, 'press-banca').single;
    expect(s.reps, 9);
    expect(s.time, t);
  });

  test('sesión anterior, récords e historial', () {
    final app = newState();
    final ex = app.exercise('press-banca')!;
    app.addSet(DateTime(2026, 10, 5), ex.id, const SetEntry(reps: 8, kg: 55));
    app.addSet(monday, ex.id, const SetEntry(reps: 8, kg: 60));
    app.addSet(today, ex.id, const SetEntry(reps: 8, kg: 62.5));

    expect(app.history(ex.id).map((s) => s.date), [
      DateTime(2026, 10, 5),
      monday,
      today,
    ]);
    expect(app.previousSession(ex.id, today)!.date, monday);
    expect(app.previousSession(ex.id, DateTime(2026, 10, 5)), isNull);
    expect(app.isRecordOn(ex, today), isTrue);
    expect(
      app.isRecordOn(ex, DateTime(2026, 10, 5)),
      isFalse,
      reason: 'la primera sesión nunca es récord',
    );
    expect(app.trainedDays.first, today);
    expect(app.analyze(ex).trend, Trend.up);
  });

  test('duración de la sesión desde la primera serie', () {
    final app = newState();
    app.addSet(
      today,
      'sentadilla',
      SetEntry(reps: 8, kg: 80, time: DateTime(2026, 10, 23, 17, 20)),
    );
    app.addSet(
      today,
      'sentadilla',
      SetEntry(reps: 8, kg: 80, time: DateTime(2026, 10, 23, 17, 50)),
    );
    // La última serie fue hace 10 minutos: sigue entrenando, cuenta hasta ahora.
    expect(app.sessionMinutes(today), 40);
    app.addSet(
      monday,
      'sentadilla',
      SetEntry(reps: 8, kg: 80, time: DateTime(2026, 10, 19, 18)),
    );
    expect(app.sessionMinutes(monday), 1);
  });

  test('crear, editar y borrar rutinas; orden por uso reciente', () {
    final app = newState();
    final id = app.saveRoutine(
      name: '  Brazos express ',
      items: const [RoutineItem(exerciseId: 'curl')],
    );
    expect(app.routine(id)!.name, 'Brazos express');

    app.saveRoutine(
      id: id,
      name: 'Brazos',
      items: const [
        RoutineItem(exerciseId: 'curl'),
        RoutineItem(exerciseId: 'press-frances'),
      ],
    );
    expect(app.routine(id)!.items, hasLength(2));
    expect(app.routines, hasLength(6));

    app.loadRoutine('r3', monday);
    app.loadRoutine(id, today);
    final order = app.routinesByRecentUse().map((r) => r.id).toList();
    expect(order.take(2), [id, 'r3']);
    expect(app.routinesByRecentUse(pinFirst: 'r5').first.id, 'r5');

    app.deleteRoutine(id);
    expect(app.routine(id), isNull);
    expect(
      app.sessionName(today),
      'Entrenamiento',
      reason: 'una rutina borrada no da nombre a la sesión',
    );
  });

  test('repetir en hoy copia ejercicios y rutinas', () {
    final app = newState();
    app.loadRoutine('r2', monday);
    app.repeatInToday(
      app.sessionExercises(monday),
      app.plan(monday).routineIds,
    );
    expect(app.sessionExercises(today), app.sessionExercises(monday));
    expect(app.sessionName(today), 'Espalda y bíceps');
    expect(app.selectedDay, today);
  });

  test('ejercicios propios: nombre único sin importar acentos', () {
    final app = newState();
    expect(app.exerciseNameExists('jalon al pecho'), isTrue);
    final ex = app.createExercise(
      name: 'Hip thrust',
      group: 'piernas',
      kind: ExerciseKind.weight,
    );
    expect(app.exercises.first.id, ex.id);
    expect(app.exerciseNameExists('HIP THRUST'), isTrue);
  });

  test('todo se guarda y se vuelve a cargar', () async {
    final storage = MemoryStorage();
    final app = newState(storage);
    final ex = app.createExercise(
      name: 'Hip thrust',
      group: 'piernas',
      kind: ExerciseKind.seconds,
    );
    app.loadRoutine('r1', today);
    app.addSet(today, 'press-banca', const SetEntry(reps: 8, kg: 62.5));
    app.addSet(today, ex.id, const SetEntry(reps: 30));
    final rid = app.saveRoutine(
      name: 'Glúteos',
      items: [RoutineItem(exerciseId: ex.id, sets: 4, reps: 30)],
    );

    final reloaded = newState(storage);
    await reloaded.load();
    expect(reloaded.exercise(ex.id)!.kind, ExerciseKind.seconds);
    expect(reloaded.exercise(ex.id)!.custom, isTrue);
    expect(reloaded.sessionName(today), 'Pecho y tríceps');
    expect(reloaded.setsOn(today, 'press-banca').single.kg, 62.5);
    expect(reloaded.setsOn(today, ex.id).single.kg, isNull);
    expect(reloaded.setsOn(today, ex.id).single.time, fixedNow);
    expect(reloaded.routine(rid)!.items.single.sets, 4);
  });
}
