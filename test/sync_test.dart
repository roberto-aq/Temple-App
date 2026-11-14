import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:temple/data/storage.dart';
import 'package:temple/models/intervals.dart';
import 'package:temple/models/models.dart';
import 'package:temple/state/app_state.dart';
import 'package:temple/sync/outbox.dart';
import 'package:temple/sync/remote.dart';
import 'package:temple/sync/sync_service.dart';

final fixedNow = DateTime(2026, 10, 23, 18);
final today = DateTime(2026, 10, 23);

/// Servidor en memoria: filas por tabla y clave, como las guarda Supabase.
class FakeBackend implements RemoteBackend {
  final tables = {
    for (final t in SyncTable.values) t: <String, Map<String, dynamic>>{},
  };
  bool online = true;

  /// Si existe, las descargas esperan a que se complete.
  Completer<void>? gate;

  /// Filas que el servidor rechaza como inválidas.
  bool Function(Map<String, dynamic> row) reject = (_) => false;

  void _check() {
    if (!online) throw Exception('Failed host lookup');
  }

  @override
  Future<List<Map<String, dynamic>>> fetch(SyncTable table) async {
    _check();
    await gate?.future;
    return [for (final r in tables[table]!.values) Map.of(r)];
  }

  @override
  Future<void> upsert(SyncTable table, List<Map<String, dynamic>> rows) async {
    _check();
    if (rows.any(reject)) {
      throw const PostgrestException(
        message: 'violates check constraint',
        code: '23514',
      );
    }
    for (final r in rows) {
      tables[table]![r[table.keyColumn] as String] = Map.of(r);
    }
  }

  @override
  Future<void> delete(SyncTable table, List<String> keys) async {
    _check();
    keys.forEach(tables[table]!.remove);
  }
}

void main() {
  late FakeBackend server;
  late MemoryStorage outboxStorage;
  late MemoryStorage cache;
  late SyncService sync;
  late AppState app;

  SyncService newSync() => SyncService(
    backend: server,
    storage: outboxStorage,
    clock: () => fixedNow,
  );

  setUp(() {
    server = FakeBackend();
    outboxStorage = MemoryStorage();
    cache = MemoryStorage();
    sync = newSync();
    app = AppState(storage: cache, clock: () => fixedNow, sync: sync);
  });

  tearDown(() => sync.dispose());

  test('cada cambio llega al servidor con sus columnas', () async {
    final ex = app.createExercise(
      name: 'Hip thrust',
      group: 'piernas',
      kind: ExerciseKind.weight,
    );
    final rid = app.saveRoutine(
      name: 'Glúteos',
      items: [RoutineItem(exerciseId: ex.id, sets: 4, reps: 10)],
    );
    app.loadRoutine(rid, today);
    app.addSet(today, ex.id, const SetEntry(reps: 10, kg: 80));
    expect(sync.pending, 4);

    await sync.flush();
    expect(sync.pending, 0);
    expect(sync.status, SyncStatus.synced);
    expect(server.tables[SyncTable.exercises]![ex.id], {
      'id': ex.id,
      'name': 'Hip thrust',
      'muscle_group': 'piernas',
      'kind': 'weight',
    });
    expect(server.tables[SyncTable.routines]![rid]!['items'], [
      {'ex': ex.id, 'sets': 4, 'reps': 10},
    ]);
    expect(server.tables[SyncTable.dayPlans]!['2026-10-23'], {
      'day': '2026-10-23',
      'routine_ids': [rid],
      'exercise_ids': [ex.id],
    });
    final set = server.tables[SyncTable.sets]!.values.single;
    expect(set['day'], '2026-10-23');
    expect(set['exercise_id'], ex.id);
    expect(set['reps'], 10);
    expect(set['kg'], 80.0);
    expect(set['unit'], 'kg');
    expect(
      DateTime.parse(set['logged_at'] as String).isAtSameMomentAs(fixedNow),
      isTrue,
      reason: 'se guarda en UTC',
    );
  });

  test('editar y borrar series y rutinas', () async {
    app.addSet(today, 'curl', const SetEntry(reps: 12, kg: 15));
    app.addSet(today, 'curl', const SetEntry(reps: 10, kg: 15));
    final rid = app.saveRoutine(
      name: 'Brazos',
      items: const [RoutineItem(exerciseId: 'curl')],
    );
    await sync.flush();

    app.replaceSet(today, 'curl', 0, const SetEntry(reps: 12, kg: 17.5));
    app.removeSet(today, 'curl', 1);
    app.deleteRoutine(rid);
    await sync.flush();

    expect(server.tables[SyncTable.sets]!.values.single['kg'], 17.5);
    expect(server.tables[SyncTable.routines], isEmpty);
    expect(app.setsOn(today, 'curl').single.kg, 17.5);
  });

  test('editar y borrar un ejercicio propio llega al servidor', () async {
    final ex = app.createExercise(
      name: 'Bicicleta',
      group: 'piernas',
      kind: ExerciseKind.seconds,
    );
    final rid = app.saveRoutine(
      name: 'Cardio',
      items: [
        RoutineItem(exerciseId: ex.id),
        const RoutineItem(exerciseId: 'plancha'),
      ],
    );
    app.addSet(today, ex.id, const SetEntry(reps: 1200));
    await sync.flush();

    app.updateExercise(ex.id, name: 'Bicicleta estática', group: 'cardio');
    await sync.flush();
    expect(
      server.tables[SyncTable.exercises]![ex.id]!['muscle_group'],
      'cardio',
    );
    expect(server.tables[SyncTable.exercises]![ex.id]!['kind'], 'seconds');

    app.deleteExercise(ex.id);
    await sync.flush();
    expect(server.tables[SyncTable.exercises], isEmpty);
    expect(server.tables[SyncTable.sets], isEmpty);
    expect(server.tables[SyncTable.routines]![rid]!['items'], [
      {'ex': 'plancha', 'sets': 3, 'reps': 10},
    ]);
    expect(server.tables[SyncTable.dayPlans], isEmpty);
  });

  test('sin conexión todo sigue funcionando y se sube al volver', () async {
    server.online = false;
    app.addSet(today, 'press-banca', const SetEntry(reps: 8, kg: 60));
    app.addSet(today, 'press-banca', const SetEntry(reps: 8, kg: 60));
    app.replaceSet(today, 'press-banca', 1, const SetEntry(reps: 7, kg: 60));
    await sync.flush();

    expect(sync.status, SyncStatus.offline);
    expect(
      sync.pending,
      2,
      reason: 'dos series; la editada cuenta una sola vez',
    );
    expect(app.setsOn(today, 'press-banca').map((s) => s.reps), [8, 7]);

    server.online = true;
    await sync.refresh();
    expect(sync.status, SyncStatus.synced);
    expect(sync.pending, 0);
    expect(server.tables[SyncTable.sets], hasLength(2));
    expect(app.setsOn(today, 'press-banca').map((s) => s.reps), [8, 7]);
  });

  test(
    'al descargar se combinan los datos del servidor con lo pendiente',
    () async {
      // Lo que otro teléfono ya subió.
      server.tables[SyncTable.routines]!['r-otro'] = {
        'id': 'r-otro',
        'name': 'Piernas',
        'items': [
          {'ex': 'sentadilla', 'sets': 4, 'reps': 8},
        ],
      };
      server.tables[SyncTable.sets]!['s-otro'] = {
        'id': 's-otro',
        'day': '2026-10-19',
        'exercise_id': 'sentadilla',
        'reps': 8,
        'kg': 100,
        'logged_at': '2026-10-19T23:00:00Z',
      };
      await sync.refresh();
      expect(app.routine('r-otro')!.name, 'Piernas');
      expect(app.setsOn(DateTime(2026, 10, 19), 'sentadilla').single.kg, 100.0);

      // Una serie registrada mientras se descarga no la borra la descarga.
      server.gate = Completer<void>();
      final downloading = sync.refresh();
      app.addSet(today, 'sentadilla', const SetEntry(reps: 8, kg: 102.5));
      server.gate!.complete();
      await downloading;
      expect(app.setsOn(today, 'sentadilla').single.kg, 102.5);
      expect(app.setsOn(DateTime(2026, 10, 19), 'sentadilla'), hasLength(1));

      await sync.flush();
      expect(server.tables[SyncTable.sets], hasLength(2));
    },
  );

  test('un cambio rechazado por el servidor no bloquea la cola', () async {
    server.reject = (r) => r['reps'] == 999;
    app.addSet(today, 'curl', const SetEntry(reps: 999, kg: 10));
    app.addSet(today, 'curl', const SetEntry(reps: 10, kg: 10));
    await sync.flush();

    expect(sync.pending, 0);
    expect(sync.discarded, 1);
    expect(server.tables[SyncTable.sets]!.values.single['reps'], 10);
  });

  test('la cola y la copia local sobreviven a cerrar la app', () async {
    server.online = false;
    final ex = app.createExercise(
      name: 'Remo invertido',
      group: 'espalda',
      kind: ExerciseKind.reps,
    );
    app.addSet(today, ex.id, const SetEntry(reps: 12));
    sync.dispose();

    // «Reabrir»: nuevas instancias con lo guardado en el teléfono.
    sync = newSync();
    app = AppState(storage: cache, clock: () => fixedNow, sync: sync);
    await sync.load();
    await app.load();
    expect(app.exercise(ex.id)!.name, 'Remo invertido');
    expect(sync.pending, 2, reason: 'el ejercicio y la serie');

    server.online = true;
    await sync.refresh();
    expect(sync.pending, 0);
    expect(app.setsOn(today, ex.id).single.reps, 12);
    expect(server.tables[SyncTable.exercises]!.keys, [ex.id]);
  });

  test(
    'un cambio nuevo de la misma fila no se pierde si llega durante el envío',
    () {
      final outbox = Outbox(MemoryStorage());
      outbox.add(const Change(SyncTable.sets, 'a', {'reps': 8}));
      final sending = outbox.changes;
      outbox.add(const Change(SyncTable.sets, 'a', {'reps': 9}));
      outbox.remove(sending);
      expect(outbox.changes.single.row, {'reps': 9});
    },
  );

  test(
    'intervalos: plantillas y sesiones llegan al servidor y a otro teléfono',
    () async {
      final p = app.saveIntervalProtocol(
        name: 'Isométrico de talón',
        workSeconds: 45,
        restSeconds: 60,
        rounds: 5,
        sided: true,
        switchSeconds: 10,
        weighted: false,
      );
      final id = app.addIntervalSession(
        protocol: p,
        startedAt: fixedNow,
        done: const [
          IntervalRound(1, IntervalSide.left, 45),
          IntervalRound(1, IntervalSide.right, 40),
        ],
        notes: 'Molestia leve al final',
      );
      await sync.flush();
      expect(sync.pending, 0);
      expect(server.tables[SyncTable.intervalProtocols]![p.id], {
        'id': p.id,
        'name': 'Isométrico de talón',
        'work_seconds': 45,
        'rest_seconds': 60,
        'rounds': 5,
        'sided': true,
        'switch_seconds': 10,
        'weighted': false,
      });
      final row = server.tables[SyncTable.intervalSessions]![id]!;
      expect(row['protocol_id'], p.id);
      expect(row['day'], '2026-10-23');
      expect(row['kg'], isNull);
      expect(row['done'], [
        {'r': 1, 'side': 'left', 's': 45},
        {'r': 1, 'side': 'right', 's': 40},
      ]);

      // Otro teléfono de la misma cuenta descarga todo.
      final sync2 = SyncService(backend: server, storage: MemoryStorage());
      addTearDown(sync2.dispose);
      final phone2 = AppState(storage: MemoryStorage(), sync: sync2);
      await sync2.refresh();
      expect(phone2.intervalProtocol(p.id)!.sided, isTrue);
      expect(phone2.intervalSession(id)!.notes, 'Molestia leve al final');
      expect(phone2.intervalSession(id)!.roundsDone, 1);

      // Borrar la plantilla en uno conserva la sesión en el servidor.
      app.deleteIntervalProtocol(p.id);
      await sync.flush();
      expect(server.tables[SyncTable.intervalProtocols], isEmpty);
      expect(server.tables[SyncTable.intervalSessions]!.keys, [id]);
    },
  );
}
