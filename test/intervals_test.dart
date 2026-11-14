import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:temple/data/storage.dart';
import 'package:temple/logic/intervals.dart';
import 'package:temple/models/intervals.dart';
import 'package:temple/models/models.dart';
import 'package:temple/state/app_state.dart';
import 'package:temple/sync/rows.dart';

const heel = IntervalProtocol(
  id: 'p1',
  name: 'Isométrico de talón',
  workSeconds: 45,
  restSeconds: 60,
  rounds: 3,
);

const wrist = IntervalProtocol(
  id: 'p2',
  name: 'Muñeca contra la pared',
  workSeconds: 30,
  restSeconds: 60,
  rounds: 2,
  sided: true,
  switchSeconds: 10,
);

/// Reloj que avanza a mano.
class FakeClock {
  DateTime t = DateTime(2026, 11, 12, 18);
  DateTime call() => t;
  void advance(int ms) => t = t.add(Duration(milliseconds: ms));
}

void main() {
  group('tramos', () {
    test('ambos lados: preparación, trabajo y descanso entre rondas', () {
      final steps = intervalTimeline(heel);
      expect(
        [for (final s in steps) (s.phase, s.seconds, s.round)],
        [
          (IntervalPhase.prepare, 5, 1),
          (IntervalPhase.work, 45, 1),
          (IntervalPhase.rest, 60, 2),
          (IntervalPhase.work, 45, 2),
          (IntervalPhase.rest, 60, 3),
          (IntervalPhase.work, 45, 3),
        ],
      );
      expect(intervalTotalSeconds(heel), 3 * 45 + 2 * 60);
    });

    test('por lado: izquierdo, cambio y derecho en cada ronda', () {
      final steps = intervalTimeline(wrist);
      expect(
        [for (final s in steps) (s.phase, s.side, s.round)],
        [
          (IntervalPhase.prepare, IntervalSide.left, 1),
          (IntervalPhase.work, IntervalSide.left, 1),
          (IntervalPhase.change, IntervalSide.right, 1),
          (IntervalPhase.work, IntervalSide.right, 1),
          (IntervalPhase.rest, IntervalSide.left, 2),
          (IntervalPhase.work, IntervalSide.left, 2),
          (IntervalPhase.change, IntervalSide.right, 2),
          (IntervalPhase.work, IntervalSide.right, 2),
        ],
      );
    });

    test('sin descanso ni cambio de lado', () {
      const sprint = IntervalProtocol(
        id: 'x',
        name: 'Sprints',
        workSeconds: 30,
        restSeconds: 0,
        rounds: 2,
        sided: true,
        switchSeconds: 0,
      );
      expect(intervalTimeline(sprint, prepare: 0).map((s) => s.phase), [
        IntervalPhase.work,
        IntervalPhase.work,
        IntervalPhase.work,
        IntervalPhase.work,
      ]);
    });
  });

  group('sesión en curso', () {
    test('avanza con el reloj, se pausa y termina sola', () {
      final clock = FakeClock();
      final run = IntervalRun(intervalTimeline(heel), clock.call);
      expect(run.started, isFalse);
      run.start();
      expect(run.current!.phase, IntervalPhase.prepare);
      expect(run.remainingSeconds, 5);

      clock.advance(5000);
      expect(run.current!.phase, IntervalPhase.work);
      expect(run.remainingSeconds, 45);
      clock.advance(1500);
      expect(run.remainingSeconds, 44, reason: 'redondea hacia arriba');

      run.pause();
      clock.advance(60000);
      expect(run.paused, isTrue);
      expect(run.remainingSeconds, 44, reason: 'en pausa no corre');
      run.resume();
      clock.advance(43500);
      expect(run.current!.phase, IntervalPhase.rest);
      expect(run.next!.phase, IntervalPhase.work);

      clock.advance(10 * 60 * 1000);
      expect(run.isDone, isTrue);
      expect(run.current, isNull);
      expect(run.rounds.map((r) => (r.round, r.seconds)), [
        (1, 45),
        (2, 45),
        (3, 45),
      ]);
    });

    test(
      'saltar un trabajo cuenta lo hecho; terminar cuenta el tramo actual',
      () {
        final clock = FakeClock();
        final run = IntervalRun(intervalTimeline(heel), clock.call)..start();
        run.skip(); // salta la preparación
        expect(run.current!.phase, IntervalPhase.work);
        clock.advance(20000);
        run.skip(); // corta la ronda 1 a los 20 s
        expect(run.current!.phase, IntervalPhase.rest);
        run.skip();
        clock.advance(30400);
        run.finish(); // ronda 2 a los 30 s
        expect(run.isDone, isTrue);
        expect(run.rounds.map((r) => r.seconds), [20, 30]);
        clock.advance(60000);
        expect(run.rounds.map((r) => r.seconds), [
          20,
          30,
        ], reason: 'ya no corre');
      },
    );

    test('por lado: una ronda está completa solo con los dos lados', () {
      final clock = FakeClock();
      final run = IntervalRun(intervalTimeline(wrist), clock.call)..start();
      clock.advance((5 + 30 + 10 + 30 + 60 + 30) * 1000);
      run.finish();
      final done = run.rounds;
      expect(done.map((r) => (r.round, r.side)), [
        (1, IntervalSide.left),
        (1, IntervalSide.right),
        (2, IntervalSide.left),
      ]);
      expect(roundsCompleted(done, sided: true), 1);
    });
  });

  group('textos y pasos', () {
    test('resumen de plantilla y de sesión', () {
      expect(intervalSummary(heel), '3 × 45 seg · descanso 1 min');
      expect(intervalSummary(wrist), '2 × 30 seg · descanso 1 min · por lado');
      expect(clockText(45), '0:45');
      expect(clockText(90), '1:30');

      IntervalSession session(List<int> secs) => IntervalSession(
        id: 's',
        protocolId: 'p1',
        name: 'Talón',
        day: DateTime(2026, 11, 12),
        startedAt: DateTime(2026, 11, 12, 18),
        workSeconds: 45,
        restSeconds: 60,
        rounds: 5,
        sided: false,
        done: [
          for (final (i, s) in secs.indexed)
            IntervalRound(i + 1, IntervalSide.both, s),
        ],
      );
      expect(
        intervalSessionText(session([45, 45, 45, 45, 45])),
        '5/5 rondas · 45 seg',
      );
      expect(
        intervalSessionText(session([45, 45, 30])),
        '3/5 rondas · 45, 45, 30 seg',
      );
    });

    test('los botones +/− de tiempo caen en pasos redondos', () {
      expect(timeStepUp(0), 5);
      expect(timeStepUp(45), 50);
      expect(timeStepUp(60), 75);
      expect(timeStepUp(300), 360);
      expect(timeStepDown(60), 55);
      expect(timeStepDown(75), 60);
      expect(timeStepDown(360), 300);
      expect(timeStepDown(5), 0);
      expect(timeStepDown(0), 0);
    });
  });

  group('estado', () {
    test(
      'plantillas y sesiones se guardan, se recargan y se cuentan por semana',
      () async {
        final storage = MemoryStorage();
        final clock = FakeClock();
        final app = AppState(storage: storage, clock: clock.call);
        final p = app.saveIntervalProtocol(
          name: '  Paseo del granjero ',
          workSeconds: 40,
          restSeconds: 90,
          rounds: 4,
          sided: false,
          switchSeconds: 10,
          weighted: true,
        );
        expect(p.name, 'Paseo del granjero');
        expect(app.intervalNameExists('paseo DEL granjero'), isTrue);
        expect(
          app.intervalNameExists('paseo del granjero', except: p.id),
          isFalse,
        );

        // Jueves 12 y lunes 9 de la misma semana; el domingo 8 es de la anterior.
        for (final d in [12, 9, 8]) {
          app.addIntervalSession(
            protocol: p,
            startedAt: DateTime(2026, 11, d, 18),
            done: const [IntervalRound(1, IntervalSide.both, 40)],
            kg: WeightUnit.lb.toKg(50),
            unit: WeightUnit.lb,
            notes: d == 12 ? '  Sin dolor  ' : '',
          );
        }
        expect(app.intervalDaysInWeek(clock.t), {'2026-11-09', '2026-11-12'});
        expect(app.intervalSessions.first.notes, 'Sin dolor');
        expect(app.intervalSessions.last.notes, isNull);
        expect(app.lastIntervalSession(p.id)!.day, DateTime(2026, 11, 12));

        final reloaded = AppState(storage: MemoryStorage(storage.data));
        await reloaded.load();
        expect(reloaded.intervalProtocol(p.id)!.weighted, isTrue);
        final s = reloaded.intervalSessions.first;
        expect(s.name, 'Paseo del granjero');
        expect(s.unit, WeightUnit.lb);
        expect(s.unit.fromKg(s.kg!), closeTo(50, 0.01));
        expect(s.done.single.seconds, 40);

        // Borrar la plantilla conserva el registro.
        app.deleteIntervalProtocol(p.id);
        expect(app.intervalProtocols, isEmpty);
        expect(app.intervalSessions, hasLength(3));

        app.updateIntervalNotes(s.id, 'Ajusté el agarre');
        expect(app.intervalSession(s.id)!.notes, 'Ajusté el agarre');
        app.deleteIntervalSession(s.id);
        expect(app.intervalSession(s.id), isNull);
      },
    );

    test('sin peso no guarda kg aunque se pase', () {
      final app = AppState(storage: MemoryStorage());
      app.addIntervalSession(
        protocol: heel,
        startedAt: DateTime(2026, 11, 12, 18),
        done: const [IntervalRound(1, IntervalSide.both, 45)],
        kg: 20,
      );
      expect(app.intervalSessions.single.kg, isNull);
    });

    test('las filas para Supabase ida y vuelta', () {
      final s = IntervalSession(
        id: 's1',
        protocolId: 'p2',
        name: 'Muñeca',
        day: DateTime(2026, 11, 12),
        startedAt: DateTime(2026, 11, 12, 18, 30),
        workSeconds: 30,
        restSeconds: 60,
        rounds: 2,
        sided: true,
        done: const [
          IntervalRound(1, IntervalSide.left, 30),
          IntervalRound(1, IntervalSide.right, 25),
        ],
        notes: 'Bien',
      );
      final row = jsonDecode(jsonEncode(intervalSessionRow(s)));
      expect(row['day'], '2026-11-12');
      expect(row['done'], [
        {'r': 1, 'side': 'left', 's': 30},
        {'r': 1, 'side': 'right', 's': 25},
      ]);
      final back = intervalSessionFromRow(row as Map<String, dynamic>);
      expect(back.startedAt, s.startedAt);
      expect(back.done.map((r) => (r.round, r.side, r.seconds)), [
        (1, IntervalSide.left, 30),
        (1, IntervalSide.right, 25),
      ]);
      expect(back.roundsDone, 1);
      expect(back.kg, isNull);
      expect(back.notes, 'Bien');

      final p = intervalProtocolFromRow(
        jsonDecode(jsonEncode(intervalProtocolRow(wrist)))
            as Map<String, dynamic>,
      );
      expect(
        (
          p.name,
          p.workSeconds,
          p.restSeconds,
          p.rounds,
          p.sided,
          p.switchSeconds,
        ),
        ('Muñeca contra la pared', 30, 60, 2, true, 10),
      );
    });
  });
}
