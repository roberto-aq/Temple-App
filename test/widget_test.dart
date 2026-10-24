import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple/app.dart';
import 'package:temple/data/storage.dart';
import 'package:temple/models/models.dart';
import 'package:temple/state/app_state.dart';

import 'fixtures.dart';

final fixedNow = DateTime(2026, 10, 23, 18);
final today = DateTime(2026, 10, 23);

Future<AppState> pumpApp(WidgetTester tester, {void Function(AppState app)? seed}) async {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final app = AppState(storage: MemoryStorage(), clock: () => fixedNow, routines: starterRoutines);
  seed?.call(app);
  await tester.pumpWidget(TempleApp(state: app));
  await tester.pumpAndSettle();
  return app;
}

/// Toca un texto visible (desplazando la lista si hace falta).
Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).hitTestable();
  if (f.evaluate().isEmpty) {
    final vertical = find.byWidgetPredicate((w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical);
    await tester.scrollUntilVisible(find.text(text), 200, scrollable: vertical.last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(text).hitTestable().first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Hoy vacío → elegir ejercicio → registrar series → volver', (tester) async {
    final app = await pumpApp(tester);
    expect(find.text('HOY'), findsOneWidget);
    expect(find.text('EMPIEZA A REGISTRAR'), findsOneWidget);
    expect(find.text('VIERNES 23 OCT'), findsOneWidget);

    await tapText(tester, 'Agregar ejercicio');
    expect(find.text('ELEGIR EJERCICIO'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'banca');
    await tester.pumpAndSettle();
    expect(find.text('1 ejercicio · toca uno para registrarlo hoy'), findsOneWidget);
    await tapText(tester, 'Press de banca');

    expect(find.text('PRESS DE BANCA'), findsOneWidget);
    expect(find.text('Es la primera vez que registras este ejercicio.'), findsOneWidget);
    await tapText(tester, 'Agregar serie');
    await tapText(tester, 'Agregar serie');
    expect(app.setsOn(today, 'press-banca'), hasLength(2));
    expect(app.setsOn(today, 'press-banca').first.kg, 20, reason: 'sin historial arranca en 10 reps × 20 kg');

    // Editar la serie 1 con los botones +.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Editar serie 1')));
    await tester.pumpAndSettle();
    expect(find.text('EDITANDO SERIE 1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Sumar 2,5 kg'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Guardar serie 1');
    expect(app.setsOn(today, 'press-banca').first.kg, 22.5);

    await tester.tap(find.bySemanticsLabel('Volver al entrenamiento'));
    await tester.pumpAndSettle();
    expect(find.text('SESIÓN DE HOY'), findsOneWidget);
    expect(find.text('Entrenamiento'), findsOneWidget);
  });

  testWidgets('cargar una rutina desde Hoy y pasar al siguiente ejercicio', (tester) async {
    final app = await pumpApp(tester);
    await tapText(tester, 'Cargar una rutina');
    expect(find.text('CARGAR RUTINA'), findsOneWidget);
    await tapText(tester, 'Piernas');

    expect(app.sessionName(today), 'Piernas');
    expect(find.text('Sentadilla'), findsOneWidget);
    await tapText(tester, 'Sentadilla');
    await tapText(tester, 'Agregar serie');
    expect(find.text('Siguiente: Prensa de piernas'), findsOneWidget);
    await tapText(tester, 'Siguiente: Prensa de piernas');
    expect(find.text('PRENSA DE PIERNAS'), findsOneWidget);
  });

  testWidgets('la tarjeta de sobrecarga compara con la última vez', (tester) async {
    await pumpApp(tester, seed: (app) {
      app.addSet(DateTime(2026, 10, 19), 'press-banca', const SetEntry(reps: 8, kg: 60));
      app.addExerciseToDay(today, 'press-banca');
    });
    await tapText(tester, 'Press de banca');
    expect(find.text('PARA SUPERAR LA ÚLTIMA VEZ'), findsOneWidget);
    expect(find.text('60 kg × 9  o  62,5 kg × 8'), findsOneWidget);
    expect(find.text('Hace 4 días · 19 oct'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Sumar 2,5 kg'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Agregar serie');
    expect(find.text('¡NUEVO RÉCORD PERSONAL!'), findsOneWidget);
  });

  testWidgets('crear una rutina eligiendo ejercicios de la biblioteca', (tester) async {
    final app = await pumpApp(tester);
    await tapText(tester, 'Rutinas');
    expect(find.text('MIS RUTINAS'), findsOneWidget);
    expect(find.text('5 RUTINAS · POR USO RECIENTE'), findsOneWidget);

    await tapText(tester, 'Nueva');
    await tapText(tester, 'Guardar rutina');
    expect(find.text('Ponle un nombre y agrega al menos un ejercicio.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Brazos express');
    await tapText(tester, 'Agregar ejercicios');
    expect(find.text('Agregando a «Brazos express»'), findsOneWidget);
    await tapText(tester, 'Bíceps');
    await tapText(tester, 'Curl martillo');
    await tapText(tester, 'Curl predicador');
    expect(find.text('Listo · 2'), findsOneWidget);
    await tapText(tester, 'Listo · 2');

    expect(find.text('EJERCICIOS · 2'), findsOneWidget);
    await tapText(tester, 'Guardar rutina');
    expect(find.text('«Brazos express» guardada. Cárgala cuando quieras desde Hoy.'), findsOneWidget);
    expect(app.routines.last.items.map((i) => i.exerciseId), ['curl-martillo', 'curl-predicador']);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.textContaining('guardada'), findsNothing, reason: 'el aviso desaparece solo');
  });

  testWidgets('crear un ejercicio propio desde la búsqueda', (tester) async {
    final app = await pumpApp(tester);
    await tapText(tester, 'Ejercicios');
    await tester.enterText(find.byType(TextField), 'Hip thrust');
    await tester.pumpAndSettle();
    expect(find.text('No está en tu biblioteca.'), findsOneWidget);
    await tapText(tester, 'Crear «Hip thrust»');

    expect(find.text('NUEVO EJERCICIO'), findsOneWidget);
    await tapText(tester, 'Guardar ejercicio');
    expect(find.text('Elige el grupo muscular.'), findsOneWidget);
    await tapText(tester, 'Piernas');
    await tapText(tester, 'Guardar ejercicio');

    expect(app.exercises.first.name, 'Hip thrust');
    expect(find.text('«Hip thrust» agregado a tu biblioteca.'), findsOneWidget);
    expect(find.text('Creado por ti · Sin registros todavía'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('progreso, detalle por ejercicio e historial con datos', (tester) async {
    await pumpApp(tester, seed: (app) {
      for (var w = 0; w < 4; w++) {
        final d = today.subtract(Duration(days: 7 * (3 - w)));
        for (final r in [8, 8, 7]) {
          app.addSet(d, 'press-banca', SetEntry(reps: r, kg: 55 + 2.5 * w));
        }
        app.addSet(d, 'dominadas', const SetEntry(reps: 8));
      }
    });

    await tapText(tester, 'Progreso');
    expect(find.text('PROGRESO'), findsOneWidget);
    expect(find.text('3'), findsOneWidget, reason: '3 récords en 30 días');
    await tester.dragUntilVisible(find.text('Mejorando · 1'), find.byType(ListView).first, const Offset(0, -200));
    expect(find.text('Estancados · 1'), findsOneWidget);
    expect(find.text('3 sesiones sin superar tu récord'), findsOneWidget);

    await tapText(tester, 'Press de banca');
    expect(find.text('PRESS DE BANCA'), findsOneWidget);
    expect(find.text('Para la próxima sesión'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('Hoy · 62,5 kg × 8, 8, 7'), findsWidgets);
    await tapText(tester, 'Volumen');
    expect(find.text('1.437,5'), findsNothing);
    expect(find.text('1.438'), findsWidgets);

    await tapText(tester, 'Progreso');
    expect(find.text('SOBRECARGA PROGRESIVA'), findsOneWidget);
    // «Hoy» también aparece en la tarjeta de grupos musculares; la pestaña es la de abajo.
    await tester.tap(find.text('Hoy').hitTestable().last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Historial');
    expect(find.text('Octubre 2026'), findsOneWidget);
    expect(find.text('4 días entrenados'), findsOneWidget);
    expect(find.text('Pecho · Espalda'), findsOneWidget);
    expect(find.text('Repetir esta sesión hoy'), findsNothing, reason: 'hoy no se puede repetir en hoy');
    await tester.tap(find.bySemanticsLabel('16 de octubre, entrenaste'));
    await tester.pumpAndSettle();
    expect(find.text('Repetir esta sesión hoy'), findsOneWidget);
  });
}
