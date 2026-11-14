import 'models.dart';

// Intervalos: ejercicios por tiempo con trabajo, descanso y rondas
// (isométricos, paseo del granjero, sprints…). Viven aparte de los
// ejercicios y series de la parte principal.

/// Lado del cuerpo de una ronda: ambos a la vez, o izquierdo y derecho por
/// separado en las plantillas «por lado».
enum IntervalSide {
  both('Ambos lados'),
  left('Izquierdo'),
  right('Derecho');

  const IntervalSide(this.label);
  final String label;

  static IntervalSide fromName(String? name) => IntervalSide.values.firstWhere(
    (s) => s.name == name,
    orElse: () => IntervalSide.both,
  );
}

/// Límites de una plantilla en la app (la base admite un poco más).
class IntervalLimits {
  IntervalLimits._();

  static const maxWork = 3600;
  static const maxRest = 1800;
  static const maxRounds = 50;
  static const maxSwitch = 120;
  static const maxNotes = 1000;
}

/// Una plantilla: qué ejercicio y con qué tiempos se repite.
class IntervalProtocol {
  const IntervalProtocol({
    required this.id,
    required this.name,
    required this.workSeconds,
    required this.restSeconds,
    required this.rounds,
    this.sided = false,
    this.switchSeconds = 10,
    this.weighted = false,
  });

  final String id;
  final String name;
  final int workSeconds;

  /// Descanso entre rondas; 0 = sin descanso.
  final int restSeconds;
  final int rounds;

  /// Cada ronda hace el lado izquierdo y luego el derecho.
  final bool sided;

  /// Pausa para cambiar de lado dentro de una ronda (solo si [sided]).
  final int switchSeconds;

  /// Se anota el peso usado en cada sesión (p. ej. paseo del granjero).
  final bool weighted;
}

/// Una ronda hecha: el lado y los segundos que realmente duró.
class IntervalRound {
  const IntervalRound(this.round, this.side, this.seconds);

  /// Número de ronda, desde 1. En «por lado», izquierdo y derecho comparten número.
  final int round;
  final IntervalSide side;
  final int seconds;
}

/// Rondas con trabajo hecho; en «por lado», solo las que tienen los dos lados.
int roundsCompleted(List<IntervalRound> done, {required bool sided}) {
  if (!sided) return done.length;
  final left = {
    for (final r in done)
      if (r.side == IntervalSide.left) r.round,
  };
  return done
      .where((r) => r.side == IntervalSide.right && left.contains(r.round))
      .length;
}

/// Una vez que se hizo una plantilla. Guarda una copia del nombre y los
/// tiempos, para que el registro no cambie si después se edita o se borra.
class IntervalSession {
  const IntervalSession({
    required this.id,
    required this.protocolId,
    required this.name,
    required this.day,
    required this.startedAt,
    required this.workSeconds,
    required this.restSeconds,
    required this.rounds,
    required this.sided,
    required this.done,
    this.kg,
    this.unit = WeightUnit.kg,
    this.notes,
  });

  final String id;

  /// La plantilla de la que salió; puede ya no existir.
  final String? protocolId;
  final String name;
  final DateTime day;
  final DateTime startedAt;

  /// Lo planeado.
  final int workSeconds;
  final int restSeconds;
  final int rounds;
  final bool sided;

  /// Lo hecho, en orden.
  final List<IntervalRound> done;

  /// Peso en kg (null si la plantilla no lleva peso) y la unidad en que se anotó.
  final double? kg;
  final WeightUnit unit;
  final String? notes;

  /// Rondas completas: en «por lado», las que tienen los dos lados.
  int get roundsDone => roundsCompleted(done, sided: sided);

  int get totalSeconds => done.fold(0, (s, r) => s + r.seconds);

  /// La misma sesión con otras observaciones (null o vacío las quita).
  IntervalSession withNotes(String? notes) => IntervalSession(
    id: id,
    protocolId: protocolId,
    name: name,
    day: day,
    startedAt: startedAt,
    workSeconds: workSeconds,
    restSeconds: restSeconds,
    rounds: rounds,
    sided: sided,
    done: done,
    kg: kg,
    unit: unit,
    notes: notes == null || notes.trim().isEmpty ? null : notes.trim(),
  );
}
