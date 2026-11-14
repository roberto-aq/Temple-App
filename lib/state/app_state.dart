import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../data/catalog.dart';
import '../data/storage.dart';
import '../logic/format.dart';
import '../logic/progress.dart';
import '../models/models.dart';
import '../sync/outbox.dart';
import '../sync/rows.dart';
import '../sync/sync_service.dart';

enum ToastTarget { routines, library }

const _uuid = Uuid();

/// Estado de la app: biblioteca propia, rutinas y lo entrenado cada día.
///
/// Todo cambio se aplica al instante en memoria y en la copia local ([AppStorage]),
/// y se envía a Supabase a través de [SyncService] cuando hay conexión.
class AppState extends ChangeNotifier {
  AppState({
    required AppStorage storage,
    DateTime Function()? clock,
    SyncService? sync,
    List<Routine> routines = const [],
  }) : _storage = storage,
       _clock = clock ?? DateTime.now,
       _sync = sync,
       _routines = List.of(routines) {
    sync?.onSnapshot = applyRemote;
  }

  final AppStorage _storage;
  final DateTime Function() _clock;
  final SyncService? _sync;

  List<Exercise> _custom = [];
  List<Routine> _routines;
  Map<String, DayPlan> _plans = {};
  Map<String, Map<String, List<SetEntry>>> _logs = {};
  DateTime? _selectedDay;

  // ---------------------------------------------------------------------------
  // Copia local, cambios y sincronización
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    final raw = await _storage.load();
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    _custom = [
      for (final e in j['customExercises'] as List? ?? const [])
        Exercise.fromJson(e as Map<String, dynamic>),
    ];
    _routines = [
      for (final r in j['routines'] as List? ?? const [])
        Routine.fromJson(r as Map<String, dynamic>),
    ];
    _plans = {
      for (final MapEntry(:key, :value)
          in (j['plans'] as Map<String, dynamic>? ?? const {}).entries)
        key: DayPlan.fromJson(value as Map<String, dynamic>),
    };
    _logs = {
      for (final MapEntry(key: day, value: byEx)
          in (j['logs'] as Map<String, dynamic>? ?? const {}).entries)
        day: {
          for (final MapEntry(key: ex, value: sets)
              in (byEx as Map<String, dynamic>).entries)
            ex: [
              for (final s in sets as List)
                () {
                  final e = SetEntry.fromJson(s as Map<String, dynamic>);
                  return e.id == null ? e.copyWith(id: _uuid.v4()) : e;
                }(),
            ],
        },
    };
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'v': 2,
    'customExercises': _custom.map((e) => e.toJson()).toList(),
    'routines': _routines.map((r) => r.toJson()).toList(),
    'plans': _plans.map((k, v) => MapEntry(k, v.toJson())),
    'logs': _logs.map(
      (k, v) => MapEntry(
        k,
        v.map((ex, sets) => MapEntry(ex, sets.map((s) => s.toJson()).toList())),
      ),
    ),
  };

  void _commit() {
    notifyListeners();
    _storage.save(jsonEncode(toJson()));
  }

  /// Aplica un cambio en memoria y lo deja en cola para Supabase. Quien llama hace [_commit].
  void _write(Change change) {
    _apply(change);
    _sync?.enqueue(change);
  }

  /// Reemplaza todo con lo descargado del servidor y vuelve a aplicar lo que aún no se sube.
  void applyRemote(Snapshot rows, List<Change> pending) {
    _custom = [
      for (final r
          in rows[SyncTable.exercises] ?? const <Map<String, dynamic>>[])
        exerciseFromRow(r),
    ];
    _routines = [
      for (final r
          in rows[SyncTable.routines] ?? const <Map<String, dynamic>>[])
        routineFromRow(r),
    ];
    _plans = {
      for (final r
          in rows[SyncTable.dayPlans] ?? const <Map<String, dynamic>>[])
        dayKey(parseDayKey(r['day'] as String)): dayPlanFromRow(r),
    };
    _logs = {};
    for (final r in rows[SyncTable.sets] ?? const <Map<String, dynamic>>[]) {
      final s = setFromRow(r);
      _insertSet(s.day, s.exerciseId, s.entry);
    }
    for (final c in pending) {
      _apply(c);
    }
    _commit();
  }

  void _apply(Change c) {
    final row = c.row;
    switch (c.table) {
      case SyncTable.exercises:
        final i = _custom.indexWhere((e) => e.id == c.key);
        if (row == null) {
          if (i >= 0) _custom = [..._custom]..removeAt(i);
        } else {
          final ex = exerciseFromRow(row);
          _custom = i >= 0 ? ([..._custom]..[i] = ex) : [ex, ..._custom];
        }
      case SyncTable.routines:
        final i = _routines.indexWhere((r) => r.id == c.key);
        if (row == null) {
          if (i >= 0) _routines = [..._routines]..removeAt(i);
        } else {
          final r = routineFromRow(row);
          _routines = i >= 0 ? ([..._routines]..[i] = r) : [..._routines, r];
        }
      case SyncTable.dayPlans:
        if (row == null) {
          _plans.remove(c.key);
        } else {
          _plans[c.key] = dayPlanFromRow(row);
        }
      case SyncTable.sets:
        if (row == null) {
          _removeSet(c.key);
          return;
        }
        final s = setFromRow(row);
        // Editada en el mismo día y ejercicio: conserva su lugar.
        final same = _logs[s.day]?[s.exerciseId];
        final i = same?.indexWhere((e) => e.id == c.key) ?? -1;
        if (i >= 0) {
          same![i] = s.entry;
        } else {
          _removeSet(c.key);
          _insertSet(s.day, s.exerciseId, s.entry);
        }
    }
  }

  /// Inserta la serie en su lugar según la hora en que se registró.
  void _insertSet(String day, String exId, SetEntry s) {
    final list = _logs.putIfAbsent(day, () => {}).putIfAbsent(exId, () => []);
    var i = list.length;
    while (i > 0 &&
        s.time != null &&
        list[i - 1].time != null &&
        list[i - 1].time!.isAfter(s.time!)) {
      i--;
    }
    list.insert(i, s);
  }

  void _removeSet(String id) {
    for (final day in _logs.keys.toList()) {
      final byEx = _logs[day]!;
      for (final ex in byEx.keys.toList()) {
        final sets = byEx[ex]!;
        final before = sets.length;
        sets.removeWhere((s) => s.id == id);
        if (sets.length == before) continue;
        if (sets.isEmpty) byEx.remove(ex);
        if (byEx.isEmpty) _logs.remove(day);
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Aviso temporal («Rutina guardada…») y elemento recién creado a resaltar
  // ---------------------------------------------------------------------------

  String? _toast;
  ToastTarget? _toastTarget;
  String? _highlightId;
  Timer? _toastTimer;

  /// El aviso vigente, si va dirigido a esa pantalla.
  String? toastFor(ToastTarget target) =>
      _toastTarget == target ? _toast : null;
  String? get highlightId => _highlightId;

  void flash(String message, ToastTarget target, {String? highlightId}) {
    _toastTimer?.cancel();
    _toast = message;
    _toastTarget = target;
    _highlightId = highlightId;
    _toastTimer = Timer(const Duration(milliseconds: 3500), () {
      _toast = null;
      _toastTarget = null;
      _highlightId = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Fechas
  // ---------------------------------------------------------------------------

  DateTime get now => _clock();
  DateTime get today => dateOnly(now);

  /// Día que se está viendo en Hoy (puede ser un día anterior de la semana).
  DateTime get selectedDay {
    final d = _selectedDay;
    return d == null || d.isAfter(today) ? today : d;
  }

  bool isToday(DateTime d) => daysBetween(d, today) == 0;

  /// «hoy» o «el martes».
  String dayWord(DateTime d) =>
      isToday(d) ? 'hoy' : 'el ${weekdaysLong[d.weekday - 1].toLowerCase()}';

  void selectDay(DateTime d) {
    if (dateOnly(d).isAfter(today)) return;
    _selectedDay = dateOnly(d);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Ejercicios y rutinas
  // ---------------------------------------------------------------------------

  /// Los creados por el usuario primero, luego la biblioteca base.
  List<Exercise> get exercises => [..._custom, ...baseExercises];

  Exercise? exercise(String id) {
    for (final e in _custom) {
      if (e.id == id) return e;
    }
    for (final e in baseExercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// ¿Hay otro ejercicio (distinto de [except]) con ese nombre?
  bool exerciseNameExists(String name, {String? except}) {
    final n = normalize(name);
    return exercises.any((e) => e.id != except && normalize(e.name) == n);
  }

  Exercise createExercise({
    required String name,
    required String group,
    required ExerciseKind kind,
  }) {
    final ex = Exercise(
      id: _uuid.v4(),
      name: name.trim(),
      group: group,
      kind: kind,
      custom: true,
    );
    _write(Change(SyncTable.exercises, ex.id, exerciseRow(ex)));
    _commit();
    return ex;
  }

  /// Cambia nombre y grupo de un ejercicio propio. El tipo no cambia nunca:
  /// las series ya registradas se leen según él.
  Exercise? updateExercise(
    String id, {
    required String name,
    required String group,
  }) {
    final old = exercise(id);
    if (old == null || !old.custom) return null;
    final ex = Exercise(
      id: id,
      name: name.trim(),
      group: group,
      kind: old.kind,
      custom: true,
    );
    _write(Change(SyncTable.exercises, id, exerciseRow(ex)));
    _commit();
    return ex;
  }

  /// Series registradas del ejercicio, contando todos los días.
  int setCount(String exId) =>
      _logs.values.fold(0, (n, byEx) => n + (byEx[exId]?.length ?? 0));

  /// Rutinas que incluyen el ejercicio.
  List<Routine> routinesWith(String exId) => [
    for (final r in _routines)
      if (r.items.any((it) => it.exerciseId == exId)) r,
  ];

  /// Borra un ejercicio propio con todas sus series y lo quita de rutinas y
  /// de los días en que estaba cargado.
  void deleteExercise(String id) {
    final ex = exercise(id);
    if (ex == null || !ex.custom) return;
    final setIds = [
      for (final byEx in _logs.values) ...?byEx[id]?.map((s) => s.id!),
    ];
    for (final setId in setIds) {
      _write(Change(SyncTable.sets, setId, null));
    }
    for (final r in routinesWith(id)) {
      final items = [
        for (final it in r.items)
          if (it.exerciseId != id) it,
      ];
      _write(
        Change(
          SyncTable.routines,
          r.id,
          routineRow(Routine(id: r.id, name: r.name, items: items)),
        ),
      );
    }
    final days = [
      for (final MapEntry(:key, :value) in _plans.entries)
        if (value.exerciseIds.contains(id)) parseDayKey(key),
    ];
    for (final d in days) {
      _updatePlan(d, (p) {
        p.exerciseIds.remove(id);
        if (p.exerciseIds.isEmpty) p.routineIds.clear();
      });
    }
    _write(Change(SyncTable.exercises, id, null));
    _commit();
  }

  List<Routine> get routines => List.unmodifiable(_routines);

  Routine? routine(String id) {
    for (final r in _routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Crea o actualiza una rutina. Devuelve su id.
  String saveRoutine({
    String? id,
    required String name,
    required List<RoutineItem> items,
  }) {
    if (id == null || routine(id) == null) id = _uuid.v4();
    _write(
      Change(
        SyncTable.routines,
        id,
        routineRow(Routine(id: id, name: name.trim(), items: List.of(items))),
      ),
    );
    _commit();
    return id;
  }

  /// Borra la rutina; las series registradas se conservan.
  void deleteRoutine(String id) {
    _write(Change(SyncTable.routines, id, null));
    _commit();
  }

  /// Último día (hasta hoy) en que se cargó la rutina.
  DateTime? routineLastUsed(Routine r) {
    DateTime? best;
    for (final MapEntry(:key, :value) in _plans.entries) {
      if (!value.routineIds.contains(r.id)) continue;
      final d = parseDayKey(key);
      if (d.isAfter(today)) continue;
      if (best == null || d.isAfter(best)) best = d;
    }
    return best;
  }

  /// Rutinas por uso reciente; las nunca usadas, por nombre.
  List<Routine> routinesByRecentUse({String? pinFirst}) {
    final last = {for (final r in _routines) r.id: routineLastUsed(r)};
    final list = List.of(_routines);
    list.sort((a, b) {
      if (a.id == pinFirst) return -1;
      if (b.id == pinFirst) return 1;
      final la = last[a.id], lb = last[b.id];
      if (la != null && lb != null && la != lb) return lb.compareTo(la);
      if (la != null && lb == null) return -1;
      if (lb != null && la == null) return 1;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  // ---------------------------------------------------------------------------
  // Sesión de un día
  // ---------------------------------------------------------------------------

  DayPlan plan(DateTime d) => _plans[dayKey(d)] ?? DayPlan();

  Map<String, List<SetEntry>> logsOn(DateTime d) =>
      _logs[dayKey(d)] ?? const {};

  List<SetEntry> setsOn(DateTime d, String exId) =>
      List.unmodifiable(logsOn(d)[exId] ?? const <SetEntry>[]);

  /// Ejercicios de la sesión del día: los planeados en orden, luego los registrados fuera del plan.
  List<String> sessionExercises(DateTime d) {
    final out = <String>[];
    for (final id in plan(d).exerciseIds) {
      if (!out.contains(id) && exercise(id) != null) out.add(id);
    }
    for (final MapEntry(:key, :value) in logsOn(d).entries) {
      if (value.isNotEmpty && !out.contains(key) && exercise(key) != null) {
        out.add(key);
      }
    }
    return out;
  }

  bool trainedOn(DateTime d) => logsOn(d).values.any((s) => s.isNotEmpty);

  /// Días con al menos una serie, del más reciente al más antiguo.
  List<DateTime> get trainedDays {
    final days = [
      for (final MapEntry(:key, :value) in _logs.entries)
        if (value.values.any((s) => s.isNotEmpty)) parseDayKey(key),
    ];
    days.sort((a, b) => b.compareTo(a));
    return days;
  }

  /// Modifica una copia del plan del día y la guarda (o lo borra si queda vacío).
  void _updatePlan(DateTime d, void Function(DayPlan p) fn) {
    final key = dayKey(d);
    final old = _plans[key];
    final p = DayPlan(
      routineIds: List.of(old?.routineIds ?? const []),
      exerciseIds: List.of(old?.exerciseIds ?? const []),
    );
    fn(p);
    final empty = p.exerciseIds.isEmpty && p.routineIds.isEmpty;
    if (empty && old == null) return;
    _write(Change(SyncTable.dayPlans, key, empty ? null : dayPlanRow(key, p)));
  }

  void addExerciseToDay(DateTime d, String exId) {
    if (sessionExercises(d).contains(exId)) return;
    _updatePlan(d, (p) => p.exerciseIds.add(exId));
    _commit();
  }

  void removeExerciseFromDay(DateTime d, String exId) {
    _updatePlan(d, (p) {
      p.exerciseIds.remove(exId);
      if (p.exerciseIds.isEmpty) p.routineIds.clear();
    });
    _commit();
  }

  /// Suma los ejercicios de la rutina a la sesión del día.
  void loadRoutine(String routineId, DateTime d) {
    final r = routine(routineId);
    if (r == null) return;
    _updatePlan(d, (p) {
      for (final it in r.items) {
        if (!p.exerciseIds.contains(it.exerciseId)) {
          p.exerciseIds.add(it.exerciseId);
        }
      }
      if (!p.routineIds.contains(routineId)) p.routineIds.add(routineId);
    });
    _selectedDay = dateOnly(d);
    _commit();
  }

  /// «Repetir hoy»: copia ejercicios (y rutinas) de otro día a la sesión de hoy.
  void repeatInToday(List<String> exerciseIds, List<String> routineIds) {
    _updatePlan(today, (p) {
      for (final id in exerciseIds) {
        if (!p.exerciseIds.contains(id)) p.exerciseIds.add(id);
      }
      for (final id in routineIds) {
        if (!p.routineIds.contains(id) && routine(id) != null) {
          p.routineIds.add(id);
        }
      }
    });
    _selectedDay = today;
    _commit();
  }

  /// Nombre de la sesión: rutinas cargadas unidas con « + », o «Entrenamiento».
  String sessionName(DateTime d) {
    final names = [for (final id in plan(d).routineIds) ?routine(id)?.name];
    return names.isEmpty ? 'Entrenamiento' : names.join(' + ');
  }

  /// Minutos desde la primera a la última serie del día (o hasta ahora si sigues entrenando).
  int sessionMinutes(DateTime d) {
    final times = [
      for (final sets in logsOn(d).values)
        for (final s in sets) ?s.time,
    ];
    if (times.isEmpty) return 0;
    times.sort();
    final t0 = times.first, t1 = times.last;
    final n = now;
    final end = isToday(d) && n.difference(t1).inMinutes < 20 ? n : t1;
    final m = (end.difference(t0).inSeconds / 60).round();
    return m < 1 ? 1 : m;
  }

  // ---------------------------------------------------------------------------
  // Series
  // ---------------------------------------------------------------------------

  void addSet(DateTime d, String exId, SetEntry entry) {
    final s = SetEntry(
      id: _uuid.v4(),
      reps: entry.reps,
      kg: entry.kg,
      unit: entry.unit,
      time: entry.time ?? now,
    );
    _write(Change(SyncTable.sets, s.id!, setRow(dayKey(d), exId, s)));
    _commit();
  }

  /// Reemplaza una serie conservando la hora en que se registró.
  void replaceSet(DateTime d, String exId, int index, SetEntry entry) {
    final sets = _logs[dayKey(d)]?[exId];
    if (sets == null || index >= sets.length) return;
    final old = sets[index];
    final s = SetEntry(
      id: old.id,
      reps: entry.reps,
      kg: entry.kg,
      unit: entry.unit,
      time: old.time ?? now,
    );
    _write(Change(SyncTable.sets, s.id!, setRow(dayKey(d), exId, s)));
    _commit();
  }

  void removeSet(DateTime d, String exId, int index) {
    final sets = _logs[dayKey(d)]?[exId];
    if (sets == null || index >= sets.length) return;
    _write(Change(SyncTable.sets, sets[index].id!, null));
    _commit();
  }

  // ---------------------------------------------------------------------------
  // Historial y progreso
  // ---------------------------------------------------------------------------

  /// Sesiones de un ejercicio, de la más antigua a la más reciente.
  List<ExerciseSession> history(String exId) {
    final out = <ExerciseSession>[];
    for (final MapEntry(:key, :value) in _logs.entries) {
      final sets = value[exId];
      if (sets != null && sets.isNotEmpty) {
        out.add(ExerciseSession(parseDayKey(key), List.unmodifiable(sets)));
      }
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// La sesión más reciente del ejercicio antes de `d`.
  ExerciseSession? previousSession(String exId, DateTime d) {
    final past = history(exId).where((s) => s.date.isBefore(dateOnly(d)));
    return past.isEmpty ? null : past.last;
  }

  /// Mejor puntaje de siempre antes de `d`.
  double priorBest(Exercise ex, DateTime d) {
    var b = 0.0;
    for (final s in history(ex.id)) {
      if (s.date.isBefore(dateOnly(d))) b = math.max(b, bestScore(ex, s.sets));
    }
    return b;
  }

  /// ¿La mejor serie del día supera todo lo anterior?
  bool isRecordOn(Exercise ex, DateTime d) {
    final sets = setsOn(d, ex.id);
    if (sets.isEmpty) return false;
    final prior = priorBest(ex, d);
    return prior > 0 && bestScore(ex, sets) > prior + 1e-9;
  }

  ExerciseAnalysis analyze(Exercise ex) =>
      ExerciseAnalysis(ex, history(ex.id), today);
}

/// Da acceso al [AppState] y redibuja a quien lo lee cuando cambia.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Sin suscribirse: para callbacks.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
