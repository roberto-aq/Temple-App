import 'package:flutter_test/flutter_test.dart';
import 'package:temple/logic/format.dart';
import 'package:temple/logic/progress.dart';
import 'package:temple/models/models.dart';

const bench = Exercise(
  id: 'press-banca',
  name: 'Press de banca',
  group: 'pecho',
  kind: ExerciseKind.weight,
);
const pullups = Exercise(
  id: 'dominadas',
  name: 'Dominadas',
  group: 'espalda',
  kind: ExerciseKind.reps,
);
const plank = Exercise(
  id: 'plancha',
  name: 'Plancha',
  group: 'core',
  kind: ExerciseKind.seconds,
);

List<SetEntry> kgSets(double kg, List<int> reps) => [
  for (final r in reps) SetEntry(reps: r, kg: kg),
];
List<SetEntry> repSets(List<int> reps) => [
  for (final r in reps) SetEntry(reps: r),
];

void main() {
  group('formato', () {
    test('números con coma decimal y miles con punto', () {
      expect(fmtNum(62.5), '62,5');
      expect(fmtNum(60), '60');
      expect(fmtNum(60.04), '60');
      expect(thousands(12500), '12.500');
      expect(thousands(999), '999');
      expect(fmtVal(1250.4), '1.250');
      expect(fmtVal(-3.5), '-3,5');
    });

    test('hace cuánto', () {
      final today = DateTime(2026, 10, 23);
      expect(agoText(DateTime(2026, 10, 23), today), 'hoy');
      expect(agoText(DateTime(2026, 10, 22), today), 'ayer');
      expect(agoText(DateTime(2026, 10, 19), today), 'hace 4 días');
    });

    test('fechas', () {
      expect(longDate(DateTime(2026, 10, 23)), 'Viernes 23 oct');
      expect(dayKey(DateTime(2026, 3, 5)), '2026-03-05');
      expect(parseDayKey('2026-03-05'), DateTime(2026, 3, 5));
      expect(weekStart(DateTime(2026, 10, 25)), DateTime(2026, 10, 19));
    });

    test('búsqueda sin acentos', () {
      expect(normalize('  Jalón al PECHO '), 'jalon al pecho');
    });

    test('resumen de series', () {
      expect(setsText(bench, kgSets(60, [8, 8, 7])), '60 kg × 8, 8, 7');
      expect(
        setsText(bench, [
          const SetEntry(reps: 8, kg: 60),
          const SetEntry(reps: 6, kg: 65),
        ]),
        '8 × 60 kg · 6 × 65 kg',
      );
      expect(setsText(pullups, repSets([8, 7])), '8, 7 reps');
      expect(setsText(plank, repSets([45, 40])), '45, 40 seg');
    });
  });

  group('superar la última vez', () {
    final prev = ExerciseSession(
      DateTime(2026, 10, 19),
      kgSets(60, [8, 8, 7, 6]),
    );

    test('sin series hoy propone una repetición más o subir peso', () {
      final b = beatInfo(bench, prev, const [], 0)!;
      expect(b.state, BeatState.target);
      expect(b.text, '60 kg × 9  o  62,5 kg × 8');
    });

    test('por debajo de 30 kg el salto de peso es 1 kg', () {
      final light = ExerciseSession(DateTime(2026, 10, 19), kgSets(14, [12]));
      expect(
        beatInfo(bench, light, const [], 0)!.text,
        '14 kg × 13  o  15 kg × 12',
      );
    });

    test('supera la última vez pero no el récord de siempre', () {
      final b = beatInfo(bench, prev, kgSets(62.5, [8]), 200)!;
      expect(b.state, BeatState.beaten);
      expect(b.text, '62,5 kg × 8 (antes 60 kg × 8)');
    });

    test('nuevo récord personal', () {
      final best = bestScore(bench, prev.sets);
      final b = beatInfo(bench, prev, kgSets(62.5, [8]), best)!;
      expect(b.state, BeatState.record);
      expect(b.label, '¡Nuevo récord personal!');
    });

    test('sin peso y por tiempo', () {
      expect(
        beatInfo(
          pullups,
          ExerciseSession(DateTime(2026), repSets([8, 7])),
          const [],
          0,
        )!.text,
        '9 reps en una serie',
      );
      expect(
        beatInfo(
          plank,
          ExerciseSession(DateTime(2026), repSets([45])),
          const [],
          0,
        )!.text,
        '50 seg en una serie',
      );
    });

    test('sin sesión anterior no hay tarjeta', () {
      expect(beatInfo(bench, null, const [], 0), isNull);
    });

    test('comparación serie a serie', () {
      expect(
        compareSet(
          bench,
          const SetEntry(reps: 9, kg: 60),
          const SetEntry(reps: 8, kg: 60),
        ),
        SetCompare.up,
      );
      expect(
        compareSet(
          bench,
          const SetEntry(reps: 8, kg: 60),
          const SetEntry(reps: 8, kg: 60),
        ),
        SetCompare.equal,
      );
      expect(
        compareSet(
          bench,
          const SetEntry(reps: 6, kg: 60),
          const SetEntry(reps: 8, kg: 60),
        ),
        SetCompare.down,
      );
    });
  });

  group('análisis de tendencia', () {
    final today = DateTime(2026, 10, 23);
    List<ExerciseSession> weekly(List<double> kgs) => [
      for (var i = 0; i < kgs.length; i++)
        ExerciseSession(
          today.subtract(Duration(days: 7 * (kgs.length - 1 - i))),
          kgSets(kgs[i], [8, 8]),
        ),
    ];

    test('mejorando', () {
      final a = ExerciseAnalysis(bench, weekly([50, 52.5, 55, 57.5]), today);
      expect(a.trend, Trend.up);
      expect(a.since, 0);
      expect(a.weeks, 3);
      expect(a.records30, 3);
      expect(a.detail, startsWith('+'));
      expect(a.statusText, contains('Superaste tu récord'));
    });

    test('estancado tras 3 sesiones sin récord', () {
      final a = ExerciseAnalysis(bench, weekly([60, 60, 60, 60]), today);
      expect(a.trend, Trend.flat);
      expect(a.detail, '3 sesiones sin superar tu récord');
    });

    test('bajando si la última queda 3 % por debajo del récord', () {
      final a = ExerciseAnalysis(bench, weekly([60, 50]), today);
      expect(a.trend, Trend.down);
      expect(a.detail, '17 % por debajo de tu récord');
    });

    test('una sola sesión: pocos datos', () {
      final a = ExerciseAnalysis(bench, weekly([60]), today);
      expect(a.trend, Trend.fresh);
      expect(a.detail, '1 sesión registrada');
    });

    test('sugerencia para la próxima sesión', () {
      expect(
        ExerciseAnalysis(bench, weekly([60]), today).suggestion,
        'Hiciste todas las series a 8 reps con 60 kg. Prueba con 62,5 kg, aunque bajen un poco las repeticiones.',
      );
      final mixed = [
        ExerciseSession(today, kgSets(60, [8, 6])),
      ];
      expect(
        ExerciseAnalysis(bench, mixed, today).suggestion,
        contains('Mantén 60 kg e intenta llegar a 8 reps'),
      );
      expect(
        ExerciseAnalysis(plank, [
          ExerciseSession(today, repSets([40, 40])),
        ], today).suggestion,
        'Intenta aguantar 45 segundos por serie.',
      );
    });

    test('métricas', () {
      final sets = [
        const SetEntry(reps: 10, kg: 60),
        const SetEntry(reps: 8, kg: 65),
      ];
      expect(metricValue(bench, sets, MetricId.weight), 65);
      expect(metricValue(bench, sets, MetricId.volume), 1120);
      expect(metricValue(bench, sets, MetricId.main), 82.3);
      expect(metricValue(pullups, repSets([8, 7]), MetricId.volume), 15);
      expect(recordFlags([5, 6, 6, 7]), [false, true, false, true]);
    });
  });
}
