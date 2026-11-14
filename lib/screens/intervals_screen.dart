import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/intervals.dart';
import '../models/intervals.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/interval_controls.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'interval_editor_screen.dart';
import 'interval_timer_screen.dart';

/// Pestaña Intervalos: ejercicios por tiempo con trabajo, descanso y rondas
/// (isométricos, paseo del granjero, sprints…), aparte de la parte principal.
class IntervalsScreen extends StatelessWidget {
  const IntervalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final protocols = app.intervalProtocols;
    final sessions = app.intervalSessions;
    final toast = app.toastFor(ToastTarget.intervals);

    // El registro, agrupado por día (del más reciente al más antiguo).
    final byDay = <DateTime, List<IntervalSession>>{};
    for (final s in sessions) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: ScreenTitle('Intervalos')),
              const SizedBox(width: 12),
              HeaderActionPill(
                label: 'Nueva',
                filled: true,
                onTap: () => pushScreen(context, const IntervalEditorScreen()),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              if (toast != null) ...[
                ToastBanner(toast),
                const SizedBox(height: 12),
              ],
              const _WeekCard(),
              const SizedBox(height: 20),
              SectionLabel(
                '${protocols.length} ${plural(protocols.length, 'plantilla', 'plantillas')}',
              ),
              const SizedBox(height: 10),
              if (protocols.isEmpty)
                const EmptyBox(
                  child: EmptyText(
                    'Crea una plantilla con el tiempo de trabajo, el descanso '
                    'y las rondas. Sirve para isométricos, paseo del granjero, '
                    'sprints y cualquier ejercicio por tiempo.',
                    align: TextAlign.start,
                  ),
                ),
              for (final p in protocols) ...[
                _ProtocolCard(
                  protocol: p,
                  highlighted: app.highlightId == p.id,
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              const SectionLabel('Registro'),
              const SizedBox(height: 10),
              if (sessions.isEmpty)
                const EmptyBox(
                  child: EmptyText(
                    'Aquí aparecen las sesiones que termines, por día.',
                    align: TextAlign.start,
                  ),
                ),
              for (final MapEntry(key: day, value: list) in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    '${longDate(day)} · ${agoText(day, app.today)}',
                    style: AppText.body(
                      14,
                      weight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                for (final s in list) ...[
                  _SessionRow(session: s),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// «Esta semana: 4 días», con los días de lunes a domingo marcados.
class _WeekCard extends StatelessWidget {
  const _WeekCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final today = app.today;
    final monday = weekStart(today);
    final days = app.intervalDaysInWeek(today);
    final n = days.length;

    return SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Esta semana'),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$n',
                style: AppText.display(40, color: AppColors.accent, height: 1),
              ),
              const SizedBox(width: 6),
              Text(
                '${plural(n, 'día', 'días')} con intervalos',
                style: AppText.body(16, weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: _DayDot(
                    date: DateTime(monday.year, monday.month, monday.day + i),
                    done: days.contains(
                      dayKey(
                        DateTime(monday.year, monday.month, monday.day + i),
                      ),
                    ),
                    isToday: i == today.weekday - 1,
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

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.date,
    required this.done,
    required this.isToday,
  });
  final DateTime date;
  final bool done;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final label =
        '${weekdaysLong[date.weekday - 1]} ${date.day}${isToday ? ', hoy' : ''}${done ? ', hiciste intervalos' : ''}';
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.accent : AppColors.control,
            border: Border.all(
              color: isToday ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              weekdaysLetter[date.weekday - 1],
              style: AppText.body(
                14,
                weight: FontWeight.w700,
                color: done ? AppColors.background : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProtocolCard extends StatelessWidget {
  const _ProtocolCard({required this.protocol, required this.highlighted});
  final IntervalProtocol protocol;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = protocol;
    final last = app.lastIntervalSession(p.id);
    final meta = [
      'dura ${durationText(intervalTotalSeconds(p))}',
      last == null
          ? 'aún no la haces'
          : 'última vez ${agoText(last.day, app.today)}',
    ].join(' · ');

    return SurfaceCard(
      radius: 20,
      borderWidth: 1.5,
      borderColor: highlighted ? AppColors.accent : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            p.name,
            style: AppText.display(27, weight: FontWeight.w700, height: 1.05),
          ),
          const SizedBox(height: 4),
          Text(
            intervalSummary(p),
            style: AppText.body(15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(meta, style: AppText.body(13, color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Empezar',
                  icon: AppIcons.play,
                  height: 44,
                  fontSize: 15,
                  radius: 12,
                  color: AppColors.control,
                  onTap: () =>
                      pushScreen(context, IntervalTimerScreen(protocol: p)),
                ),
              ),
              const SizedBox(width: 8),
              CircleIconButton(
                icon: AppIcons.edit,
                iconSize: 18,
                radius: 12,
                color: AppColors.control,
                semanticLabel: 'Editar ${p.name}',
                onTap: () =>
                    pushScreen(context, IntervalEditorScreen(protocol: p)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Una sesión del registro; al tocarla se ve el detalle.
class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});
  final IntervalSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final weight = s.kg == null
        ? null
        : '${fmtNum(s.unit.fromKg(s.kg!))} ${s.unit.symbol}';
    return Pressable(
      onTap: () => showIntervalSessionSheet(context, s.id),
      radius: 16,
      borderColor: AppColors.border,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      semanticLabel:
          '${s.name}, ${intervalSessionText(s)}${weight == null ? '' : ', $weight'}${s.notes == null ? '' : ', con observaciones'}',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: AppText.body(17, weight: FontWeight.w600, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  [intervalSessionText(s), ?weight].join(' · '),
                  style: AppText.body(14, color: AppColors.textSecondary),
                ),
                if (s.notes != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(
                      14,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const AppIcon(
            AppIcons.chevronRight,
            size: 18,
            color: AppColors.textFaint,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hoja de una sesión: detalle, observaciones y eliminar
// ---------------------------------------------------------------------------

Future<void> showIntervalSessionSheet(BuildContext context, String id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    builder: (_) => _SessionSheet(id: id),
  );
}

class _SessionSheet extends StatefulWidget {
  const _SessionSheet({required this.id});
  final String id;

  @override
  State<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends State<_SessionSheet> {
  late final TextEditingController _notes;
  bool _confirmDelete = false;

  @override
  void initState() {
    super.initState();
    _notes = TextEditingController(
      text: AppScope.read(context).intervalSession(widget.id)?.notes ?? '',
    );
    // Muestra «Guardar observaciones» en cuanto cambian.
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.intervalSession(widget.id);
    if (s == null) return const SizedBox.shrink();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final time =
        '${s.startedAt.hour.toString().padLeft(2, '0')}:${s.startedAt.minute.toString().padLeft(2, '0')}';
    final changed = _notes.text.trim() != (s.notes ?? '');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
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
                        s.name.toUpperCase(),
                        style: AppText.display(30, height: 1),
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
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Text(
                    '${longDate(s.day)} · $time',
                    style: AppText.body(14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      intervalSessionText(s),
                      if (s.kg != null)
                        '${fmtNum(s.unit.fromKg(s.kg!))} ${s.unit.symbol}',
                      'descanso ${durationText(s.restSeconds)}',
                    ].join(' · '),
                    style: AppText.body(15, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  for (final r in s.done)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 86,
                            child: Text(
                              'Ronda ${r.round}',
                              style: AppText.body(
                                15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s.sided ? r.side.label : '',
                              style: AppText.body(15),
                            ),
                          ),
                          Text(
                            durationText(r.seconds),
                            style: AppText.display(
                              20,
                              weight: FontWeight.w700,
                              color: r.seconds < s.workSeconds
                                  ? AppColors.alert
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  const SectionLabel('Observaciones'),
                  const SizedBox(height: 8),
                  NotesField(controller: _notes),
                  if (changed) ...[
                    const SizedBox(height: 8),
                    PrimaryButton(
                      label: 'Guardar observaciones',
                      height: 50,
                      fontSize: 16,
                      radius: 14,
                      onTap: () {
                        app.updateIntervalNotes(s.id, _notes.text);
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (!_confirmDelete)
                    SecondaryButton(
                      label: 'Eliminar sesión',
                      icon: AppIcons.trash,
                      iconColor: AppColors.alert,
                      height: 48,
                      fontSize: 15,
                      onTap: () => setState(() => _confirmDelete = true),
                    )
                  else
                    DangerConfirm(
                      title: '¿Eliminar esta sesión?',
                      message: 'Se quita del registro. No se puede deshacer.',
                      onCancel: () => setState(() => _confirmDelete = false),
                      onConfirm: () {
                        app.deleteIntervalSession(s.id);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
