import 'dart:math' as math;

import '../models/intervals.dart';
import 'format.dart';

/// Fases del temporizador de intervalos.
enum IntervalPhase {
  prepare('Prepárate'),
  work('Trabajo'),
  change('Cambia de lado'),
  rest('Descanso'),
  done('Terminado');

  const IntervalPhase(this.label);
  final String label;
}

/// Un tramo del temporizador. En trabajo, [round] y [side] son los de ese
/// tramo; en preparación, cambio y descanso, los del trabajo que sigue.
class IntervalStep {
  const IntervalStep(
    this.phase,
    this.seconds, {
    this.round = 1,
    this.side = IntervalSide.both,
  });

  final IntervalPhase phase;
  final int seconds;
  final int round;
  final IntervalSide side;
}

/// Segundos de preparación antes de la primera ronda.
const intervalPrepareSeconds = 5;

/// Los tramos de una plantilla, en orden: preparación, y por cada ronda el
/// trabajo (izquierdo, cambio, derecho si es por lado) y el descanso. Tras la
/// última ronda no hay descanso.
List<IntervalStep> intervalTimeline(
  IntervalProtocol p, {
  int prepare = intervalPrepareSeconds,
}) {
  final first = p.sided ? IntervalSide.left : IntervalSide.both;
  final out = <IntervalStep>[
    if (prepare > 0) IntervalStep(IntervalPhase.prepare, prepare, side: first),
  ];
  for (var r = 1; r <= p.rounds; r++) {
    if (p.sided) {
      out.add(
        IntervalStep(
          IntervalPhase.work,
          p.workSeconds,
          round: r,
          side: IntervalSide.left,
        ),
      );
      if (p.switchSeconds > 0) {
        out.add(
          IntervalStep(
            IntervalPhase.change,
            p.switchSeconds,
            round: r,
            side: IntervalSide.right,
          ),
        );
      }
      out.add(
        IntervalStep(
          IntervalPhase.work,
          p.workSeconds,
          round: r,
          side: IntervalSide.right,
        ),
      );
    } else {
      out.add(IntervalStep(IntervalPhase.work, p.workSeconds, round: r));
    }
    if (r < p.rounds && p.restSeconds > 0) {
      out.add(
        IntervalStep(
          IntervalPhase.rest,
          p.restSeconds,
          round: r + 1,
          side: first,
        ),
      );
    }
  }
  return out;
}

/// Duración total de una plantilla (sin la preparación).
int intervalTotalSeconds(IntervalProtocol p) =>
    intervalTimeline(p, prepare: 0).fold(0, (s, t) => s + t.seconds);

/// El avance de una sesión en curso. Se calcula con la hora real ([now]):
/// si el teléfono se bloquea o la app pasa a segundo plano, al volver sigue
/// donde corresponde.
class IntervalRun {
  IntervalRun(this.steps, this.now) {
    var t = 0;
    for (final s in steps) {
      _starts.add(t);
      t += s.seconds * 1000;
    }
    _totalMs = t;
  }

  final List<IntervalStep> steps;
  final DateTime Function() now;

  final _starts = <int>[];
  late final int _totalMs;

  /// Milisegundos acumulados hasta la última pausa o salto.
  int _baseMs = 0;

  /// Desde cuándo corre (null si está en pausa o sin empezar).
  DateTime? _since;
  bool _started = false;
  bool _finished = false;

  /// Trabajos saltados antes de tiempo: índice del tramo → ms hechos.
  final _cut = <int, int>{};

  bool get started => _started;
  bool get running => _since != null;
  bool get paused => _started && !running && !isDone;
  bool get isDone => _finished || elapsedMs >= _totalMs;

  int get elapsedMs {
    final since = _since;
    final e =
        _baseMs + (since == null ? 0 : now().difference(since).inMilliseconds);
    return math.min(e, _totalMs);
  }

  /// Índice del tramo actual; `steps.length` al terminar.
  int get index {
    if (isDone) return steps.length;
    final e = elapsedMs;
    var i = 0;
    while (i + 1 < steps.length && _starts[i + 1] <= e) {
      i++;
    }
    return i;
  }

  IntervalStep? get current {
    final i = index;
    return i < steps.length ? steps[i] : null;
  }

  /// El tramo que sigue al actual, si hay.
  IntervalStep? get next {
    final i = index + 1;
    return i < steps.length ? steps[i] : null;
  }

  /// Segundos que faltan del tramo actual, redondeados hacia arriba.
  int get remainingSeconds {
    final i = index;
    if (i >= steps.length) return 0;
    final end = _starts[i] + steps[i].seconds * 1000;
    return ((end - elapsedMs) / 1000).ceil();
  }

  /// Avance del tramo actual, de 0 a 1.
  double get stepProgress {
    final i = index;
    if (i >= steps.length) return 1;
    final ms = steps[i].seconds * 1000;
    return ms == 0 ? 1 : (elapsedMs - _starts[i]) / ms;
  }

  void start() {
    if (_started) return;
    _started = true;
    _since = now();
  }

  void pause() {
    if (!running) return;
    _baseMs = elapsedMs;
    _since = null;
  }

  void resume() {
    if (!_started || running || isDone) return;
    _since = now();
  }

  /// Pasa al tramo siguiente. Un trabajo saltado cuenta lo que se alcanzó a hacer.
  void skip() {
    final i = index;
    if (!_started || i >= steps.length) return;
    final e = elapsedMs;
    if (steps[i].phase == IntervalPhase.work) _cut[i] = e - _starts[i];
    _baseMs = i + 1 < steps.length ? _starts[i + 1] : _totalMs;
    if (running) _since = now();
  }

  /// Termina antes de tiempo; el trabajo en curso cuenta lo hecho.
  void finish() {
    pause();
    _finished = true;
  }

  /// Las rondas hechas hasta ahora, con sus segundos reales (al menos 1).
  List<IntervalRound> get rounds {
    final e = elapsedMs;
    final out = <IntervalRound>[];
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i];
      if (s.phase != IntervalPhase.work || _starts[i] >= e) continue;
      final ms = _cut[i] ?? math.min(s.seconds * 1000, e - _starts[i]);
      final seconds = (ms / 1000).round();
      if (seconds >= 1) out.add(IntervalRound(s.round, s.side, seconds));
    }
    return out;
  }
}

/// Cuenta regresiva: «0:45», «1:30», «12:00».
String clockText(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Resumen de una plantilla: «5 × 45 seg · descanso 1 min · por lado».
String intervalSummary(IntervalProtocol p) => [
  '${p.rounds} × ${durationText(p.workSeconds)}',
  p.restSeconds == 0
      ? 'sin descanso'
      : 'descanso ${durationText(p.restSeconds)}',
  if (p.sided) 'por lado',
  if (p.weighted) 'con peso',
].join(' · ');

/// Lo hecho en una sesión: «5/5 rondas · 45 seg» o, si cambiaron los tiempos,
/// «4/5 rondas · 45, 45, 45, 30 seg».
String intervalSessionText(IntervalSession s) {
  final secs = s.done.map((r) => r.seconds).toList();
  final same = secs.every((x) => x == s.workSeconds);
  final rounds =
      '${s.roundsDone}/${s.rounds} ${plural(s.rounds, 'ronda', 'rondas')}';
  if (secs.isEmpty) return rounds;
  if (same) {
    return '$rounds · ${durationText(s.workSeconds)}${s.sided ? ' por lado' : ''}';
  }
  return '$rounds · ${secs.join(', ')} seg';
}

/// Paso de los botones +/− de un tiempo: de 5 s hasta 1 min, de 15 s hasta
/// 5 min y luego de 1 min. Siempre cae en un múltiplo del paso.
int timeStepUp(int seconds) {
  final step = _timeStep(seconds);
  return (seconds ~/ step + 1) * step;
}

int timeStepDown(int seconds) {
  if (seconds <= 0) return 0;
  final t = seconds - 1;
  return (t ~/ _timeStep(t)) * _timeStep(t);
}

int _timeStep(int seconds) => seconds < 60 ? 5 : (seconds < 300 ? 15 : 60);
