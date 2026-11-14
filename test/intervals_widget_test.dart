import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple/app.dart';
import 'package:temple/data/storage.dart';
import 'package:temple/device/interval_cues.dart';
import 'package:temple/models/intervals.dart';
import 'package:temple/models/models.dart';
import 'package:temple/state/app_state.dart';
import 'package:temple/widgets/ui.dart';

/// Avisos que no suenan: anotan qué se habría oído.
class FakeCues implements IntervalCues {
  final calls = <String>[];
  bool awake = false;

  int count(String name) => calls.where((c) => c == name).length;

  @override
  Future<void> prepare() async {}
  @override
  void tick() => calls.add('tick');
  @override
  void work() => calls.add('work');
  @override
  void rest() => calls.add('rest');
  @override
  void done() => calls.add('done');
  @override
  Future<void> keepAwake(bool on) async => awake = on;
}

late DateTime now;
late FakeCues cues;

Future<AppState> pumpApp(
  WidgetTester tester, {
  void Function(AppState app)? seed,
}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = AppState(storage: MemoryStorage(), clock: () => now);
  seed?.call(app);
  await tester.pumpWidget(TempleApp(state: app));
  await tester.pumpAndSettle();
  return app;
}

/// Avanza el reloj de la app y el del test, de a décimas como el temporizador.
Future<void> advance(WidgetTester tester, double seconds) async {
  for (var i = 0; i < (seconds * 10).round(); i++) {
    now = now.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).hitTestable());
  await tester.pumpAndSettle();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  await tester.tap(
    find.byWidgetPredicate(
      (w) => w is CircleIconButton && w.semanticLabel == label,
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    now = DateTime(2026, 11, 12, 18);
    cues = FakeCues();
    IntervalCues.instance = cues;
  });

  testWidgets('crear una plantilla, hacerla con pausa y salto, y guardarla', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await tapText(tester, 'Intervalos');
    expect(find.text('INTERVALOS').hitTestable(), findsOneWidget);
    expect(find.text('días con intervalos'), findsOneWidget);

    // Nueva plantilla: 2 rondas de 45 s con 1 min de descanso.
    await tapText(tester, 'Nueva');
    await tester.enterText(find.byType(TextField), 'Isométrico de talón');
    for (var i = 0; i < 3; i++) {
      await tapButton(tester, 'Restar una ronda');
      await tapButton(tester, 'Sumar a trabajo');
    }
    await tester.pump();
    expect(
      find.text('Dura 2 min 30 seg · 2 × 45 seg · descanso 1 min'),
      findsOneWidget,
    );
    await tapText(tester, 'Crear plantilla');
    expect(find.text('«Isométrico de talón» creada.'), findsOneWidget);
    expect(find.text('2 × 45 seg · descanso 1 min'), findsOneWidget);

    // Preparar y empezar.
    await tapText(tester, 'Empezar');
    expect(find.text('ISOMÉTRICO DE TALÓN'), findsOneWidget);
    await tester.tap(find.text('Empezar').hitTestable());
    await tester.pump();
    expect(cues.awake, isTrue, reason: 'pantalla encendida');
    expect(find.text('PREPÁRATE'), findsOneWidget);
    expect(find.text('0:05'), findsOneWidget);

    await advance(tester, 5);
    expect(find.text('TRABAJO'), findsOneWidget);
    expect(find.text('RONDA 1 DE 2'), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    expect(cues.count('tick'), 3, reason: '3, 2, 1 antes de empezar');
    expect(cues.calls.last, 'work');

    // En pausa no corre.
    await tester.tap(find.text('Pausa'));
    await advance(tester, 10);
    expect(find.text('EN PAUSA'), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    await tester.tap(find.text('Seguir'));
    await advance(tester, 45);
    expect(find.text('DESCANSO'), findsOneWidget);
    expect(find.text('SIGUE: RONDA 2 DE 2'), findsOneWidget);
    expect(cues.calls.last, 'rest');

    // Saltar el descanso y terminar la ronda 2 a los 20 s.
    await tapButton(tester, 'Saltar al siguiente tramo');
    expect(find.text('RONDA 2 DE 2'), findsOneWidget);
    expect(cues.calls.last, 'work');
    await advance(tester, 20);
    await tapButton(tester, 'Terminar');
    await tester.pumpAndSettle();
    expect(find.text('TERMINADO'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('20 seg'), findsOneWidget);
    expect(cues.awake, isFalse);

    await tester.enterText(find.byType(TextField), 'Sin dolor');
    await tapText(tester, 'Guardar sesión');
    expect(
      find.text('Sesión de «Isométrico de talón» guardada.'),
      findsOneWidget,
    );
    expect(find.text('2/2 rondas · 45, 20 seg'), findsOneWidget);
    expect(find.text('Sin dolor'), findsOneWidget);
    final s = app.intervalSessions.single;
    expect(s.day, DateTime(2026, 11, 12));
    expect(s.done.map((r) => r.seconds), [45, 20]);
    expect(app.intervalDaysInWeek(now), {'2026-11-12'});

    // Detalle: cambiar las observaciones y eliminar.
    await tapText(tester, '2/2 rondas · 45, 20 seg');
    await tester.enterText(find.byType(TextField).last, 'Sin dolor, mejor');
    await tester.pump();
    await tapText(tester, 'Guardar observaciones');
    expect(app.intervalSessions.single.notes, 'Sin dolor, mejor');
    await tapText(tester, 'Eliminar sesión');
    await tapText(tester, 'Eliminar');
    expect(app.intervalSessions, isEmpty);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('con peso y por lado: usa el peso de la última vez y bloquea', (
    tester,
  ) async {
    late IntervalProtocol p;
    final app = await pumpApp(
      tester,
      seed: (app) {
        p = app.saveIntervalProtocol(
          name: 'Paseo del granjero',
          workSeconds: 30,
          restSeconds: 60,
          rounds: 3,
          sided: true,
          switchSeconds: 10,
          weighted: true,
        );
        app.addIntervalSession(
          protocol: p,
          startedAt: DateTime(2026, 11, 10, 18),
          done: const [IntervalRound(1, IntervalSide.left, 30)],
          kg: WeightUnit.lb.toKg(50),
          unit: WeightUnit.lb,
        );
      },
    );
    await tapText(tester, 'Intervalos');
    await tapText(tester, 'Empezar');
    expect(find.text('50'), findsOneWidget);
    expect(find.text('lb'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is CircleIconButton && w.semanticLabel == 'Sumar 5 lb',
      ),
    );
    await tester.pump();
    expect(find.text('55'), findsOneWidget);

    await tester.tap(find.text('Empezar').hitTestable());
    await advance(tester, 5);
    expect(find.text('IZQUIERDO'), findsOneWidget);

    // Bloqueado, los botones no están; se desbloquea manteniendo presionado.
    await tapButton(tester, 'Bloquear la pantalla');
    expect(find.text('Pausa'), findsNothing);
    await tester.longPress(find.text('Mantén presionado para desbloquear'));
    await tester.pump();
    expect(find.text('Pausa'), findsOneWidget);

    await advance(tester, 30);
    expect(find.text('CAMBIA DE LADO'), findsOneWidget);
    expect(find.text('DERECHO'), findsOneWidget);
    await advance(tester, 10);
    expect(find.text('TRABAJO'), findsOneWidget);
    await advance(tester, 30);
    await tapButton(tester, 'Terminar');
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('55 lb'), findsOneWidget);
    await tapText(tester, 'Guardar sesión');

    final s = app.lastIntervalSession(p.id)!;
    expect(s.unit, WeightUnit.lb);
    expect(s.unit.fromKg(s.kg!), closeTo(55, 0.01));
    expect(s.roundsDone, 1);
    expect(s.done.map((r) => (r.round, r.side)), [
      (1, IntervalSide.left),
      (1, IntervalSide.right),
    ]);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('terminar antes de la primera ronda no guarda nada', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      seed: (app) => app.saveIntervalProtocol(
        name: 'Sprints',
        workSeconds: 30,
        restSeconds: 90,
        rounds: 8,
        sided: false,
        switchSeconds: 10,
        weighted: false,
      ),
    );
    await tapText(tester, 'Intervalos');
    await tapText(tester, 'Empezar');
    await tester.tap(find.text('Empezar').hitTestable());
    await advance(tester, 2);
    await tapButton(tester, 'Terminar');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No alcanzaste a hacer ninguna ronda, así que no hay nada que guardar.',
      ),
      findsOneWidget,
    );
    await tapText(tester, 'Salir');
    expect(app.intervalSessions, isEmpty);
    expect(find.text('Sprints'), findsOneWidget);
  });
}
