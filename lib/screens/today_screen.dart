import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models/models.dart';
import '../state/account.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'account_sheet.dart';
import 'history_screen.dart';
import 'home_shell.dart';
import 'library_screen.dart';
import 'log_exercise_screen.dart';
import 'routine_editor_screen.dart';

/// 1 · Hoy: la sesión del día elegido en la semana.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final day = app.selectedDay;
    final isToday = app.isToday(day);
    final session = app.sessionExercises(day);

    return Column(
      children: [
        _Header(day: day),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: session.isEmpty
                ? [_EmptySession(day: day, isToday: isToday)]
                : _sessionContent(context, app, day, session),
          ),
        ),
      ],
    );
  }

  List<Widget> _sessionContent(
    BuildContext context,
    AppState app,
    DateTime day,
    List<String> session,
  ) {
    final isToday = app.isToday(day);
    var setsDone = 0, exDone = 0;
    String? nextId;
    for (final id in session) {
      final n = app.setsOn(day, id).length;
      setsDone += n;
      if (n > 0) {
        exDone++;
      } else {
        nextId ??= id;
      }
    }
    final next = nextId == null ? null : app.exercise(nextId);
    final weekday = weekdaysLong[day.weekday - 1].toLowerCase();

    return [
      SurfaceCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(isToday ? 'Sesión de hoy' : 'Sesión del $weekday'),
            const SizedBox(height: 4),
            Text(
              app.sessionName(day),
              style: AppText.display(32, weight: FontWeight.w700, height: 1.05),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    value: '$setsDone',
                    label: 'Series',
                    accent: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(value: '$exDone', label: 'Ejercicios'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Stat(
                    value: '${app.sessionMinutes(day)}',
                    label: 'Minutos',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final id in session) ...[
        _SessionItem(day: day, exerciseId: id),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 2),
      DashedAddButton(
        label: 'Agregar ejercicio',
        onTap: () => _openPicker(context),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Guardar como rutina',
              icon: AppIcons.bookmark,
              height: 46,
              fontSize: 14,
              radius: 14,
              onTap: () => pushScreen(
                context,
                RoutineEditorScreen(
                  initialItems: [
                    for (final id in session) RoutineItem(exerciseId: id),
                  ],
                  returnToRoutines: true,
                ),
              ),
            ),
          ),
          if (!isToday) ...[
            const SizedBox(width: 8),
            Expanded(
              child: SecondaryButton(
                label: 'Repetir hoy',
                icon: AppIcons.repeat,
                height: 46,
                fontSize: 14,
                radius: 14,
                onTap: () =>
                    app.repeatInToday(session, app.plan(day).routineIds),
              ),
            ),
          ],
        ],
      ),
      if (next != null && setsDone > 0) ...[
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Siguiente: ${next.name}',
          trailingIcon: AppIcons.arrowRight,
          height: 60,
          radius: 18,
          onTap: () => pushScreen(
            context,
            LogExerciseScreen(exerciseId: next.id, day: day),
          ),
        ),
      ],
    ];
  }
}

void _openPicker(BuildContext context) =>
    pushScreen(context, const LibraryScreen(mode: LibraryMode.session));

class _Header extends StatelessWidget {
  const _Header({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final today = app.today;
    final monday = weekStart(today);
    final isToday = app.isToday(day);
    final account = AccountScope.maybeOf(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, account == null ? 18 : 10, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TempleLogo(size: 26),
              const SizedBox(width: 8),
              Text(
                'TEMPLE',
                style: AppText.display(21, letterSpacing: 21 * 0.14),
              ),
              if (account != null) ...[
                const Spacer(),
                AccountButton(account: account),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      longDate(today).toUpperCase(),
                      style: AppText.label(size: 13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    ScreenTitle(
                      isToday
                          ? 'Hoy'
                          : '${weekdaysLong[day.weekday - 1]} ${day.day}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: () => pushScreen(context, const HistoryScreen()),
                radius: 99,
                height: 44,
                borderColor: AppColors.borderStrong,
                padding: const EdgeInsets.only(left: 12, right: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      AppIcons.calendar,
                      size: 18,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Historial',
                      style: AppText.body(14, weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _DayChip(
                    date: monday.add(Duration(days: i)),
                    selected:
                        daysBetween(monday.add(Duration(days: i)), day) == 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.selected});
  final DateTime date;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isToday = app.isToday(date);
    final future = date.isAfter(app.today);
    final trained = app.trainedOn(date);
    final fg = selected ? AppColors.background : AppColors.text;
    final label =
        '${weekdaysLong[date.weekday - 1]} ${date.day}${isToday ? ', hoy' : ''}${trained ? ', entrenaste' : ''}';

    return Opacity(
      opacity: future ? 0.35 : 1,
      child: Pressable(
        onTap: future ? null : () => app.selectDay(date),
        height: 66,
        radius: 14,
        borderWidth: 1.5,
        color: selected ? AppColors.accent : AppColors.surface,
        borderColor: selected || isToday ? AppColors.accent : AppColors.border,
        semanticLabel: label,
        selected: selected,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdaysShort[date.weekday - 1],
              style: AppText.body(
                11,
                weight: FontWeight.w700,
                color: fg,
                letterSpacing: 0.66,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${date.day}',
              style: AppText.display(
                24,
                weight: FontWeight.w700,
                color: fg,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: trained
                    ? (selected ? AppColors.background : AppColors.accent)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySession extends StatelessWidget {
  const _EmptySession({required this.day, required this.isToday});
  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (isToday ? 'Empieza a registrar' : 'Sin registros este día')
                .toUpperCase(),
            style: AppText.display(32, height: 1.05),
          ),
          const SizedBox(height: 12),
          Text(
            isToday
                ? 'Agrega los ejercicios a medida que los hagas, o carga una de tus rutinas para empezar con sus ejercicios.'
                : 'Si entrenaste y se te olvidó anotarlo, puedes registrarlo ahora.',
            style: AppText.body(
              15,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Agregar ejercicio',
            icon: AppIcons.plus,
            onTap: () => _openPicker(context),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Cargar una rutina',
            icon: AppIcons.routine,
            height: 58,
            fontSize: 17,
            weight: FontWeight.w700,
            color: AppColors.surfaceRaised,
            onTap: () => showLoadRoutineSheet(context, day),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.accent = false});
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppText.display(
            56,
            height: 0.9,
            color: accent ? AppColors.accent : AppColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: AppText.label(tracking: 0.1)),
      ],
    );
  }
}

class _SessionItem extends StatelessWidget {
  const _SessionItem({required this.day, required this.exerciseId});
  final DateTime day;
  final String exerciseId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ex = app.exercise(exerciseId)!;
    final sets = app.setsOn(day, ex.id);
    final done = sets.length;
    final prev = app.previousSession(ex.id, day);
    final target = prev == null
        ? 'Primera vez'
        : '${capitalize(agoText(prev.date, app.today))}: ${setsText(ex, prev.sets)}';
    final isRecord = app.isRecordOn(ex, day);
    final doneWord = plural(done, 'serie', 'series');

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: done > 0 ? AppColors.accentSoft(0.45) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Pressable(
                onTap: () => pushScreen(
                  context,
                  LogExerciseScreen(exerciseId: ex.id, day: day),
                ),
                color: Colors.transparent,
                radius: 18,
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
                semanticLabel:
                    '${ex.name}, $done ${plural(done, 'serie registrada', 'series registradas')}',
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                ex.name,
                                style: AppText.body(
                                  17,
                                  weight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              if (isRecord) const RecordBadge(),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            target,
                            style: AppText.body(
                              14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (done > 0) ...[
                            const SizedBox(height: 10),
                            SetPills(count: done),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 52,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$done',
                            style: AppText.display(
                              38,
                              height: 1,
                              color: done > 0
                                  ? AppColors.accent
                                  : AppColors.textDisabled,
                            ),
                          ),
                          Text(
                            doneWord.toUpperCase(),
                            style: AppText.label(size: 11, tracking: 0.1),
                          ),
                        ],
                      ),
                    ),
                    if (done > 0) ...[
                      const SizedBox(width: 12),
                      const AppIcon(
                        AppIcons.chevronRight,
                        size: 18,
                        color: AppColors.textFaint,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (done == 0)
              Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: AppColors.border)),
                ),
                child: Pressable(
                  onTap: () => app.removeExerciseFromDay(day, ex.id),
                  color: Colors.transparent,
                  radius: 0,
                  width: 48,
                  semanticLabel: 'Quitar ${ex.name} de la sesión',
                  child: const Center(
                    child: AppIcon(
                      AppIcons.close,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoja «Cargar rutina»
// ---------------------------------------------------------------------------

Future<void> showLoadRoutineSheet(BuildContext context, DateTime day) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => _LoadRoutineSheet(day: day),
  );
}

class _LoadRoutineSheet extends StatelessWidget {
  const _LoadRoutineSheet({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final loadedIds = app.plan(day).routineIds;
    final routines = app.routinesByRecentUse(pinFirst: app.highlightId);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.sheet,
        border: Border(top: BorderSide(color: AppColors.borderStrong)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.handle,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      'CARGAR RUTINA',
                      style: AppText.display(32, height: 1),
                    ),
                  ),
                ),
                CircleIconButton(
                  icon: AppIcons.close,
                  semanticLabel: 'Cerrar',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              'Sus ejercicios se suman a tu sesión de ${app.dayWord(day)}. Después puedes agregar o quitar los que quieras.',
              style: AppText.body(
                14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                for (final r in routines) ...[
                  _LoadCard(
                    routine: r,
                    loaded: loadedIds.contains(r.id),
                    onLoad: () {
                      app.loadRoutine(r.id, day);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                Pressable(
                  onTap: () {
                    ShellScope.read(context).value = AppTab.rutinas;
                    Navigator.pop(context);
                  },
                  color: Colors.transparent,
                  borderColor: AppColors.borderStrong,
                  radius: 14,
                  height: 50,
                  child: Center(
                    child: Text(
                      'Crear o editar rutinas',
                      style: AppText.body(15, weight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadCard extends StatelessWidget {
  const _LoadCard({
    required this.routine,
    required this.loaded,
    required this.onLoad,
  });
  final Routine routine;
  final bool loaded;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final last = app.routineLastUsed(routine);
    final exList = [
      for (final it in routine.items)
        app.exercise(it.exerciseId)?.name ?? it.exerciseId,
    ].join(' · ');

    return Pressable(
      onTap: loaded ? null : onLoad,
      radius: 18,
      borderWidth: 1.5,
      borderColor: loaded ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      semanticLabel: loaded
          ? '${routine.name}, ya está en tu sesión'
          : 'Cargar ${routine.name}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine.name,
                  style: AppText.display(
                    24,
                    weight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exList,
                  style: AppText.body(
                    13,
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  last == null
                      ? 'Aún no la has hecho'
                      : 'Última vez: ${agoText(last, app.today)}',
                  style: AppText.body(
                    12,
                    weight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: loaded ? AppColors.accent : Colors.transparent,
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: Center(
              child: AppIcon(
                loaded ? AppIcons.check : AppIcons.plus,
                color: loaded ? AppColors.background : AppColors.accent,
                strokeWidth: loaded ? 2.8 : 2.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
