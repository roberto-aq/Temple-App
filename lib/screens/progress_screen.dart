import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../logic/format.dart';
import '../logic/progress.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'exercise_progress_screen.dart';
import 'home_shell.dart';

/// Ícono y color de cada tendencia.
(AppIcons, Color) trendStyle(Trend t) => switch (t) {
  Trend.up => (AppIcons.arrowUp, AppColors.accent),
  Trend.flat => (AppIcons.minus, AppColors.textMuted),
  Trend.down => (AppIcons.arrowDown, AppColors.alert),
  Trend.fresh => (AppIcons.info, AppColors.textSecondary),
};

/// 7 · Progreso: resumen de sobrecarga progresiva.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  Trend? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final today = app.today;
    final analyses = [
      for (final ex in app.exercises) app.analyze(ex),
    ].where((a) => a.sessions.isNotEmpty).toList();
    final count = {
      for (final t in Trend.values)
        t: analyses.where((a) => a.trend == t).length,
    };
    final records = analyses.fold(0, (s, a) => s + a.records30);

    final rows =
        analyses.where((a) => _filter == null || a.trend == _filter).toList()
          ..sort((a, b) {
            final c = b.sessions.last.date.compareTo(a.sessions.last.date);
            return c != 0 ? c : a.exercise.name.compareTo(b.exercise.name);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SOBRECARGA PROGRESIVA',
                style: AppText.label(size: 13, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              const ScreenTitle('Progreso'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 20),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _StatCard(
                              value: '${count[Trend.up]}',
                              label: 'Mejorando',
                              accent: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              value: '${count[Trend.flat]}',
                              label: 'Estancados',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatCard(
                              value: '$records',
                              label: 'Récords · 30 días',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MuscleGroupsCard(analyses: analyses, today: today),
                    const SizedBox(height: 18),
                    const SectionLabel('Por ejercicio'),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              ChipRow(
                semanticLabel: 'Filtrar por tendencia',
                children: [
                  for (final (t, label) in [
                    (null, 'Todos'),
                    (Trend.up, 'Mejorando'),
                    (Trend.flat, 'Estancados'),
                    (Trend.down, 'Bajando'),
                  ])
                    FilterChipButton(
                      label:
                          '$label · ${t == null ? analyses.length : count[t]}',
                      selected: _filter == t,
                      fontSize: 14,
                      onTap: () => setState(() => _filter = t),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    if (rows.isEmpty)
                      EmptyBox(
                        radius: 16,
                        child: EmptyText(
                          analyses.isEmpty
                              ? 'Aún no hay registros. Cuando anotes tus series, aquí verás cómo progresa cada ejercicio.'
                              : 'No hay ejercicios en esta categoría.',
                        ),
                      ),
                    for (final a in rows) ...[
                      _ExerciseRow(analysis: a),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.accent = false,
  });
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppText.display(
              44,
              height: 0.95,
              color: accent ? AppColors.accent : AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.body(
              12,
              weight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleGroupsCard extends StatelessWidget {
  const _MuscleGroupsCard({required this.analyses, required this.today});
  final List<ExerciseAnalysis> analyses;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final rows =
        [
          for (final g in muscleGroups)
            () {
              DateTime? last;
              final dates = <String>{};
              for (final a in analyses.where((a) => a.exercise.group == g.id)) {
                for (final s in a.sessions) {
                  final age = daysBetween(s.date, today);
                  if (age < 0) continue;
                  if (last == null || s.date.isAfter(last)) last = s.date;
                  if (age <= 30) dates.add(dayKey(s.date));
                }
              }
              return (label: g.label, last: last, times30: dates.length);
            }(),
        ]..sort((a, b) {
          final da = a.last == null ? 9999 : daysBetween(a.last!, today);
          final db = b.last == null ? 9999 : daysBetween(b.last!, today);
          return db.compareTo(da);
        });

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Grupos musculares'),
          const SizedBox(height: 4),
          Text(
            'Hace cuánto entrenaste cada uno. El punto marca los de los últimos 3 días.',
            style: AppText.body(13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: i == rows.length - 1
                        ? Colors.transparent
                        : AppColors.border,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          rows[i].last != null &&
                              daysBetween(rows[i].last!, today) <= 3
                          ? AppColors.accent
                          : AppColors.handle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: AppText.body(16, weight: FontWeight.w600),
                    ),
                  ),
                  if (rows[i].times30 > 0)
                    Text(
                      '${rows[i].times30} ${plural(rows[i].times30, 'vez', 'veces')} en 30 días',
                      style: AppText.body(12, color: AppColors.textSecondary),
                    ),
                  const SizedBox(width: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 96),
                    child: Text(
                      rows[i].last == null
                          ? 'Sin registros'
                          : capitalize(agoText(rows[i].last!, today)),
                      textAlign: TextAlign.right,
                      style: AppText.display(21, weight: FontWeight.w700),
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

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.analysis});
  final ExerciseAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final (icon, color) = trendStyle(a.trend);
    return Pressable(
      onTap: () => pushScreen(
        context,
        ExerciseProgressScreen(exerciseId: a.exercise.id),
      ),
      radius: 18,
      borderColor: AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      semanticLabel:
          '${a.exercise.name}: ${a.trend.label}, ${a.detail}. Ver detalle',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.exercise.name,
                    style: AppText.body(
                      16,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      AppIcon(icon, size: 16, color: color, strokeWidth: 2.8),
                      const SizedBox(width: 5),
                      Text(
                        a.trend.label,
                        style: AppText.body(
                          13,
                          weight: FontWeight.w700,
                          color: AppColors.textSoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.detail,
                    style: AppText.body(12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 64,
              height: 28,
              child: CustomPaint(painter: SparklinePainter(a.mains, color)),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 58),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(fmtVal(a.last), style: AppText.display(28, height: 1)),
                  Text(
                    a.mainMetric.label,
                    style: AppText.body(
                      11,
                      weight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
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

/// Línea de tendencia mínima.
class SparklinePainter extends CustomPainter {
  SparklinePainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final mn = values.reduce(math.min), mx = values.reduce(math.max);
    final range = (mx - mn) == 0 ? 1 : mx - mn;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = 2 + i * (size.width - 4) / (values.length - 1);
      final y = size.height - 3 - (values[i] - mn) / range * (size.height - 6);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter old) =>
      old.values != values || old.color != color;
}
