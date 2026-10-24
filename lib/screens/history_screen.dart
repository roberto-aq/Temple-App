import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../logic/format.dart';
import '../logic/progress.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';

/// 9 · Historial: calendario de días entrenados.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

typedef _DayEntry = ({Exercise exercise, List<SetEntry> sets, bool record});

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _month;
  DateTime? _selected;

  /// Lo entrenado cada día (hasta hoy), con récords marcados por ejercicio.
  Map<String, List<_DayEntry>> _byDay(AppState app) {
    final out = <String, List<_DayEntry>>{};
    for (final ex in app.exercises) {
      var best = 0.0;
      for (final s in app.history(ex.id)) {
        final score = bestScore(ex, s.sets);
        final record = best > 0 && score > best + 1e-9;
        if (score > best) best = score;
        if (s.date.isAfter(app.today)) continue;
        out.putIfAbsent(dayKey(s.date), () => []).add((exercise: ex, sets: s.sets, record: record));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final today = app.today;
    final byDay = _byDay(app);
    final month = _month ?? DateTime(today.year, today.month);
    final isCurrentMonth = month.year == today.year && month.month == today.month;
    final trained = byDay.keys.map(parseDayKey).toList()..sort((a, b) => b.compareTo(a));
    final selected = _selected ?? (trained.isEmpty ? null : trained.first);
    final selItems = selected == null ? null : byDay[dayKey(selected)];

    final lead = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final monthCount = [for (var d = 1; d <= daysInMonth; d++) byDay.containsKey(dayKey(DateTime(month.year, month.month, d)))]
        .where((x) => x)
        .length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BackPill(label: 'Hoy', onTap: () => Navigator.pop(context)),
                  const SizedBox(height: 14),
                  const ScreenTitle('Historial', size: 40),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  SurfaceCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleIconButton(
                              icon: AppIcons.chevronLeft,
                              semanticLabel: 'Mes anterior',
                              color: Colors.transparent,
                              onTap: () => setState(() => _month = DateTime(month.year, month.month - 1)),
                            ),
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Column(
                                  children: [
                                    Text('${monthsLong[month.month - 1]} ${month.year}',
                                        style: AppText.display(26, weight: FontWeight.w700, height: 1.1)),
                                    Text('$monthCount ${plural(monthCount, 'día entrenado', 'días entrenados')}',
                                        style: AppText.body(12, weight: FontWeight.w600, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                            CircleIconButton(
                              icon: AppIcons.chevronRight,
                              semanticLabel: 'Mes siguiente',
                              color: Colors.transparent,
                              onTap: isCurrentMonth ? null : () => setState(() => _month = DateTime(month.year, month.month + 1)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ExcludeSemantics(
                          child: Row(
                            children: [
                              for (final l in weekdaysLetter)
                                Expanded(
                                  child: Text(l,
                                      textAlign: TextAlign.center,
                                      style: AppText.body(11, weight: FontWeight.w700, color: AppColors.textFaint)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.05,
                          children: [
                            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                            for (var d = 1; d <= daysInMonth; d++)
                              _DayCell(
                                date: DateTime(month.year, month.month, d),
                                trained: byDay.containsKey(dayKey(DateTime(month.year, month.month, d))),
                                selected: selected != null && daysBetween(selected, DateTime(month.year, month.month, d)) == 0,
                                today: today,
                                onTap: () => setState(() => _selected = DateTime(month.year, month.month, d)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (selItems == null)
                    const EmptyBox(child: EmptyText('Toca un día marcado para ver qué entrenaste.'))
                  else
                    _DayDetail(date: selected!, items: selItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.trained, required this.selected, required this.today, required this.onTap});

  final DateTime date;
  final bool trained;
  final bool selected;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = daysBetween(date, today) == 0;
    final future = date.isAfter(today);
    return Opacity(
      opacity: future ? 0.3 : 1,
      child: Pressable(
        onTap: future ? null : onTap,
        radius: 12,
        borderWidth: 1.5,
        selected: selected,
        color: selected ? AppColors.accent : (trained ? AppColors.accentSoft(0.16) : Colors.transparent),
        borderColor: isToday && !selected ? AppColors.accent : Colors.transparent,
        semanticLabel: '${date.day} de ${monthsLong[date.month - 1].toLowerCase()}${trained ? ', entrenaste' : ''}',
        child: Center(
          child: Text(
            '${date.day}',
            style: AppText.display(
              19,
              weight: trained || selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.background : (trained ? AppColors.accent : AppColors.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.date, required this.items});
  final DateTime date;
  final List<_DayEntry> items;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final groups = <String>[];
    for (final it in items) {
      final g = groupLabel(it.exercise.group);
      if (!groups.contains(g)) groups.add(g);
    }
    final totalSets = items.fold(0, (s, it) => s + it.sets.length);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel('${longDate(date)} · ${agoText(date, app.today)}'),
          const SizedBox(height: 4),
          Text(groups.join(' · '), style: AppText.display(28, weight: FontWeight.w700, height: 1.1)),
          const SizedBox(height: 2),
          Text('${items.length} ${plural(items.length, 'ejercicio', 'ejercicios')} · $totalSets series',
              style: AppText.body(13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: i == items.length - 1 ? Colors.transparent : AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].exercise.name, style: AppText.body(15, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(setsText(items[i].exercise, items[i].sets), style: AppText.body(13, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  if (items[i].record) ...[const SizedBox(width: 10), const RecordBadge()],
                ],
              ),
            ),
          if (!app.isToday(date)) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Repetir esta sesión hoy',
              icon: AppIcons.repeat,
              height: 52,
              fontSize: 16,
              onTap: () {
                app.repeatInToday([for (final it in items) it.exercise.id], app.plan(date).routineIds);
                goToTab(context, AppTab.hoy);
              },
            ),
          ],
        ],
      ),
    );
  }
}
