// Prueba de punta a punta contra el proyecto real de Supabase:
//
//   flutter test tool/supabase_smoke_test.dart --dart-define-from-file=.env --dart-define=SMOKE_EMAIL=tu@gmail.com
//
// Crea dos cuentas de prueba con alias de un correo tuyo (SMOKE_EMAIL; Gmail admite
// «tu+alias@gmail.com»), sincroniza datos con la misma lógica
// de la app, comprueba que cada cuenta solo vea lo suyo y al final borra sus datos.
// Las cuentas quedan en Authentication → Users y se pueden borrar desde ahí.
// ignore_for_file: avoid_print
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:temple/config.dart';
import 'package:temple/data/storage.dart';
import 'package:temple/models/models.dart';
import 'package:temple/state/app_state.dart';
import 'package:temple/sync/outbox.dart';
import 'package:temple/sync/remote.dart';
import 'package:temple/sync/sync_service.dart';

final _stamp = DateTime.now().millisecondsSinceEpoch;
final _password = 'Prueba-${Random().nextInt(1 << 32)}-temple';
final today = DateTime(2026, 10, 23);
const _baseEmail = String.fromEnvironment('SMOKE_EMAIL');

SupabaseClient newClient() => SupabaseClient(
  SupabaseConfig.url,
  SupabaseConfig.key,
  authOptions: const AuthClientOptions(
    authFlowType: AuthFlowType.implicit,
    autoRefreshToken: false,
  ),
);

Future<(SupabaseClient, User)> signUp(String who) async {
  final client = newClient();
  final [name, domain] = _baseEmail.split('@');
  final res = await client.auth.signUp(
    email: '$name+temple-prueba-$who-$_stamp@$domain',
    password: _password,
  );
  if (res.session == null) {
    fail(
      'La cuenta se creó pero sin sesión: «Confirm email» sigue activado en Authentication.',
    );
  }
  return (client, res.user!);
}

Future<void> wipe(SupabaseClient client, String userId) async {
  for (final t in SyncTable.values.reversed) {
    await client.from(t.table).delete().eq('user_id', userId);
  }
}

void main() {
  test('Supabase de punta a punta', () async {
    expect(SupabaseConfig.problem, isNull, reason: SupabaseConfig.problem);
    expect(
      _baseEmail,
      contains('@'),
      reason: 'Falta --dart-define=SMOKE_EMAIL=tu@correo.com',
    );

    // --- Cuenta A: registro y rutinas de inicio ---------------------------------
    final (a, userA) = await signUp('a');
    final backendA = SupabaseBackend(a, userA.id);
    final starters = await backendA.fetch(SyncTable.routines);
    expect(
      starters.map((r) => r['name']),
      [
        'Pecho y tríceps',
        'Espalda y bíceps',
        'Piernas',
        'Hombros',
        'Full body y core',
      ],
      reason: 'el disparador crea las 5 rutinas de inicio',
    );
    print('✓ Registro con correo y contraseña; 5 rutinas de inicio creadas');

    // --- Usar la app en un «teléfono» ------------------------------------------
    final sync1 = SyncService(backend: backendA, storage: MemoryStorage());
    final phone1 = AppState(storage: MemoryStorage(), sync: sync1);
    await sync1.refresh();
    expect(phone1.routines, hasLength(5));

    final ex = phone1.createExercise(
      name: 'Hip thrust',
      group: 'piernas',
      kind: ExerciseKind.weight,
    );
    final rid = phone1.saveRoutine(
      name: 'Glúteos',
      items: [RoutineItem(exerciseId: ex.id, sets: 4, reps: 10)],
    );
    phone1.loadRoutine(rid, today);
    phone1.addSet(today, ex.id, const SetEntry(reps: 10, kg: 80));
    phone1.addSet(today, ex.id, const SetEntry(reps: 9, kg: 82.5));
    phone1.addSet(today, 'plancha', const SetEntry(reps: 45));
    phone1.replaceSet(today, ex.id, 1, const SetEntry(reps: 10, kg: 82.5));
    phone1.removeSet(today, 'plancha', 0);
    await sync1.flush();
    expect(sync1.status, SyncStatus.synced, reason: sync1.lastError);
    expect(sync1.pending, 0);
    print(
      '✓ Ejercicio, rutina, plan del día y series subidos (incluye editar y borrar)',
    );

    // --- Otro «teléfono» de la misma cuenta descarga todo ----------------------
    final sync2 = SyncService(backend: backendA, storage: MemoryStorage());
    final phone2 = AppState(storage: MemoryStorage(), sync: sync2);
    await sync2.refresh();
    expect(sync2.status, SyncStatus.synced, reason: sync2.lastError);
    expect(phone2.exercise(ex.id)!.name, 'Hip thrust');
    expect(phone2.routine(rid)!.items.single.sets, 4);
    expect(phone2.sessionName(today), 'Glúteos');
    expect(phone2.setsOn(today, ex.id).map((s) => (s.reps, s.kg)), [
      (10, 80.0),
      (10, 82.5),
    ]);
    expect(phone2.setsOn(today, 'plancha'), isEmpty);
    print('✓ Otro dispositivo de la misma cuenta ve exactamente lo mismo');

    // --- La base de datos rechaza datos inválidos -------------------------------
    await expectLater(
      a.from('sets').insert({
        'id':
            '00000000-0000-4000-8000-${_stamp.toString().padLeft(12, '0').substring(0, 12)}',
        'user_id': userA.id,
        'day': '2026-10-23',
        'exercise_id': 'curl',
        'reps': 20000,
      }),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '23514')),
    );
    print('✓ Valores fuera de rango rechazados (más de 3 horas)');

    // --- Cuenta B: no ve ni toca nada de A ---------------------------------------
    final (b, userB) = await signUp('b');
    final setsSeenByB = await b.from('sets').select('id');
    expect(setsSeenByB, isEmpty, reason: 'B no debe ver las series de A');
    final aRoutineSeenByB = await b.from('routines').select('id').eq('id', rid);
    expect(aRoutineSeenByB, isEmpty, reason: 'B no debe ver las rutinas de A');
    await b.from('routines').update({'name': 'Hackeada'}).eq('id', rid);
    await b.from('sets').delete().eq('user_id', userA.id);
    await expectLater(
      b.from('exercises').insert({
        'id':
            '11111111-1111-4111-8111-${_stamp.toString().padLeft(12, '0').substring(0, 12)}',
        'user_id': userA.id,
        'name': 'Intruso',
        'muscle_group': 'core',
        'kind': 'reps',
      }),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    final routineA = await a
        .from('routines')
        .select('name')
        .eq('id', rid)
        .single();
    expect(
      routineA['name'],
      'Glúteos',
      reason: 'B no pudo editar la rutina de A',
    );
    expect(
      await a.from('sets').select('id'),
      hasLength(2),
      reason: 'B no pudo borrar series de A',
    );
    print('✓ Otra cuenta no puede ver, crear, editar ni borrar datos ajenos');

    // --- Sin sesión no se ve nada ------------------------------------------------
    final anon = newClient();
    try {
      final rows = await anon.from('sets').select('id');
      expect(rows, isEmpty);
    } on PostgrestException catch (e) {
      expect(e.code, '42501');
    }
    print('✓ Sin iniciar sesión no se puede leer nada');

    // --- Limpieza ------------------------------------------------------------------
    sync1.dispose();
    sync2.dispose();
    await wipe(a, userA.id);
    await wipe(b, userB.id);
    print(
      '✓ Datos de prueba borrados. Cuentas creadas: ${userA.email}, ${userB.email}',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
