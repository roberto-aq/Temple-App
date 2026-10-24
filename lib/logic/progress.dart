import 'dart:math' as math;

import '../models/models.dart';
import 'format.dart';

/// Puntaje de una serie para comparar «mejor o peor». Con peso usa el 1RM estimado (Epley).
double scoreSet(Exercise ex, SetEntry s) =>
    ex.weighted ? (s.kg ?? 0) * (1 + s.reps / 30) : s.reps.toDouble();

double bestScore(Exercise ex, Iterable<SetEntry> sets) =>
    sets.fold(0.0, (b, s) => math.max(b, scoreSet(ex, s)));

SetEntry? bestSet(Exercise ex, List<SetEntry> sets) {
  SetEntry? best;
  for (final s in sets) {
    if (best == null || scoreSet(ex, s) > scoreSet(ex, best)) best = s;
  }
  return best;
}

/// Incremento de peso sugerido: 2,5 kg desde 30 kg, 1 kg por debajo.
double weightStep(double kg) => kg >= 30 ? 2.5 : 1;

// ---------------------------------------------------------------------------
// Comparación serie a serie con la última vez
// ---------------------------------------------------------------------------

enum SetCompare { up, equal, down }

SetCompare compareSet(Exercise ex, SetEntry current, SetEntry previous) {
  final a = scoreSet(ex, current), b = scoreSet(ex, previous);
  if (a > b * 1.005) return SetCompare.up;
  if (a < b * 0.995) return SetCompare.down;
  return SetCompare.equal;
}

// ---------------------------------------------------------------------------
// Tarjeta «Para superar la última vez» en Registrar
// ---------------------------------------------------------------------------

enum BeatState { target, beaten, record }

class BeatInfo {
  const BeatInfo(this.state, this.text);
  final BeatState state;
  final String text;

  String get label => switch (state) {
    BeatState.record => '¡Nuevo récord personal!',
    BeatState.beaten => '¡Superaste la última vez!',
    BeatState.target => 'Para superar la última vez',
  };
}

/// `previous`: la última sesión antes del día; `logged`: las series de hoy;
/// `priorBest`: el mejor puntaje de siempre antes de ese día.
BeatInfo? beatInfo(
  Exercise ex,
  ExerciseSession? previous,
  List<SetEntry> logged,
  double priorBest,
) {
  final pBest = previous == null ? null : bestSet(ex, previous.sets);
  if (pBest == null) return null;
  final cBest = bestSet(ex, logged);
  if (cBest != null &&
      priorBest > 0 &&
      scoreSet(ex, cBest) > priorBest + 1e-9) {
    return BeatInfo(
      BeatState.record,
      'Tu mejor serie de siempre: ${setLabel(ex, cBest)}',
    );
  }
  if (cBest != null && scoreSet(ex, cBest) > scoreSet(ex, pBest) + 1e-9) {
    return BeatInfo(
      BeatState.beaten,
      '${setLabel(ex, cBest)} (antes ${setLabel(ex, pBest)})',
    );
  }
  if (ex.weighted) {
    final kg = pBest.kg ?? 0;
    return BeatInfo(
      BeatState.target,
      '${fmtNum(kg)} kg × ${pBest.reps + 1}  o  ${fmtNum(kg + weightStep(kg))} kg × ${pBest.reps}',
    );
  }
  if (ex.timed) {
    return BeatInfo(BeatState.target, '${pBest.reps + 5} seg en una serie');
  }
  return BeatInfo(BeatState.target, '${pBest.reps + 1} reps en una serie');
}

// ---------------------------------------------------------------------------
// Métricas y análisis de tendencia
// ---------------------------------------------------------------------------

enum MetricId { main, weight, volume }

class Metric {
  const Metric(this.id, this.label, this.long, this.unit);
  final MetricId id;
  final String label;
  final String long;
  final String unit;
}

List<Metric> metricsFor(Exercise ex) {
  if (ex.weighted) {
    return const [
      Metric(MetricId.main, '1RM est.', '1RM estimado', 'kg'),
      Metric(MetricId.weight, 'Peso máx.', 'peso máximo', 'kg'),
      Metric(MetricId.volume, 'Volumen', 'volumen', 'kg'),
    ];
  }
  if (ex.timed) {
    return const [
      Metric(MetricId.main, 'Tiempo máx.', 'tiempo máximo', 'seg'),
      Metric(MetricId.volume, 'Tiempo total', 'tiempo total', 'seg'),
    ];
  }
  return const [
    Metric(MetricId.main, 'Reps máx.', 'repeticiones máximas', 'reps'),
    Metric(MetricId.volume, 'Reps totales', 'repeticiones totales', 'reps'),
  ];
}

double metricValue(Exercise ex, List<SetEntry> sets, MetricId id) {
  var v = 0.0;
  for (final s in sets) {
    final kg = s.kg ?? 0;
    switch (id) {
      case MetricId.main:
        v = math.max(
          v,
          ex.weighted ? kg * (1 + s.reps / 30) : s.reps.toDouble(),
        );
      case MetricId.weight:
        v = math.max(v, kg);
      case MetricId.volume:
        v += ex.weighted ? kg * s.reps : s.reps;
    }
  }
  return (v * 10).round() / 10;
}

enum Trend {
  up('Mejorando'),
  flat('Estancado'),
  down('Bajando'),
  fresh('Pocos datos');

  const Trend(this.label);
  final String label;
}

/// Marca qué valores son récord (superan a todos los anteriores; el primero nunca lo es).
List<bool> recordFlags(List<double> values) {
  var best = -1.0;
  final flags = <bool>[];
  for (var i = 0; i < values.length; i++) {
    flags.add(i > 0 && values[i] > best);
    if (values[i] > best) best = values[i];
  }
  return flags;
}

class ExerciseAnalysis {
  ExerciseAnalysis._(
    this.exercise,
    this.sessions,
    this.mains,
    this.trend,
    this.since,
    this.best,
    this.weeks,
    this.records30,
  );

  final Exercise exercise;
  final List<ExerciseSession> sessions;

  /// Métrica principal por sesión (1RM estimado, reps o segundos máximos).
  final List<double> mains;
  final Trend trend;

  /// Sesiones desde el último récord.
  final int since;
  final double best;
  final int weeks;

  /// Récords en los últimos 30 días.
  final int records30;

  double get first => mains.isEmpty ? 0 : mains.first;
  double get last => mains.isEmpty ? 0 : mains.last;
  Metric get mainMetric => metricsFor(exercise).first;

  factory ExerciseAnalysis(
    Exercise ex,
    List<ExerciseSession> sessions,
    DateTime today,
  ) {
    final mains = [
      for (final s in sessions) metricValue(ex, s.sets, MetricId.main),
    ];
    final flags = recordFlags(mains);
    var best = -1.0, bestIdx = -1;
    for (var i = 0; i < mains.length; i++) {
      if (mains[i] > best) {
        best = mains[i];
        bestIdx = i;
      }
    }
    final n = sessions.length;
    final since = n == 0 ? 0 : n - 1 - bestIdx;
    var trend = Trend.fresh;
    if (n >= 2) {
      if (mains.last < best * 0.97) {
        trend = Trend.down;
      } else if (since >= 3) {
        trend = Trend.flat;
      } else {
        trend = Trend.up;
      }
    }
    var records30 = 0;
    for (var i = 0; i < n; i++) {
      final age = daysBetween(sessions[i].date, today);
      if (flags[i] && age >= 0 && age <= 30) records30++;
    }
    final weeks = n >= 2
        ? math.max(
            1,
            (daysBetween(sessions.first.date, sessions.last.date) / 7).round(),
          )
        : 0;
    return ExerciseAnalysis._(
      ex,
      sessions,
      mains,
      trend,
      since,
      best < 0 ? 0 : best,
      weeks,
      records30,
    );
  }

  /// Línea corta de la lista de Progreso.
  String get detail {
    final unit = mainMetric.unit;
    switch (trend) {
      case Trend.up:
        final d = last - first;
        return '${d >= 0 ? '+' : ''}${fmtVal(d)} $unit en $weeks ${plural(weeks, 'semana', 'semanas')}';
      case Trend.flat:
        return '$since sesiones sin superar tu récord';
      case Trend.down:
        return '${((1 - last / best) * 100).round()} % por debajo de tu récord';
      case Trend.fresh:
        return '1 sesión registrada';
    }
  }

  /// Explicación del estado en el detalle por ejercicio.
  String get statusText {
    final m = mainMetric;
    switch (trend) {
      case Trend.up:
        return since == 0
            ? 'Superaste tu récord en la última sesión (${fmtVal(best)} ${m.unit} de ${m.long}). '
                  'Así funciona la sobrecarga progresiva: un poco más cada vez.'
            : 'Tu último récord fue hace $since ${plural(since, 'sesión', 'sesiones')}. Vas por buen camino.';
      case Trend.flat:
        return 'Llevas $since sesiones sin superar tu récord de ${fmtVal(best)} ${m.unit} (${m.long}). '
            'Cambia una variable: más peso, una repetición más o una serie extra.';
      case Trend.down:
        return 'Tu última sesión quedó un ${((1 - last / best) * 100).round()} % por debajo de tu récord de '
            '${fmtVal(best)} ${m.unit}. Puede ser cansancio: revisa descanso, sueño y técnica.';
      case Trend.fresh:
        return 'Registra este ejercicio en al menos dos sesiones para saber si estás progresando.';
    }
  }

  /// «Para la próxima sesión», a partir de la última sesión.
  String? get suggestion {
    if (sessions.isEmpty || sessions.last.sets.isEmpty) return null;
    final sets = sessions.last.sets;
    final reps = sets.map((s) => s.reps);
    final mx = reps.reduce(math.max), mn = reps.reduce(math.min);
    final ex = exercise;
    if (ex.weighted) {
      final w = sets.map((s) => s.kg ?? 0).reduce(math.max);
      final next = fmtNum(w + weightStep(w));
      return mn == mx
          ? 'Hiciste todas las series a $mx reps con ${fmtNum(w)} kg. Prueba con $next kg, aunque bajen un poco las repeticiones.'
          : 'Mantén ${fmtNum(w)} kg e intenta llegar a $mx reps en todas las series. Cuando lo logres, sube a $next kg.';
    }
    if (ex.timed) {
      return mn == mx
          ? 'Intenta aguantar ${mx + 5} segundos por serie.'
          : 'Intenta llegar a $mx segundos en todas las series.';
    }
    return mn == mx
        ? 'Intenta ${mx + 1} reps por serie, o agrega peso si ya te resulta fácil.'
        : 'Busca hacer $mx reps en todas las series.';
  }
}
