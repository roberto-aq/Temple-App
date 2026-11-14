import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../logic/format.dart';
import '../logic/progress.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'log_exercise_screen.dart';
import 'progress_screen.dart';

/// 8 · Progreso por ejercicio.
class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({
    super.key,
    required this.exerciseId,
    this.backLabel = 'Progreso',
  });

  final String exerciseId;
  final String backLabel;

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  MetricId _metric = MetricId.main;
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ex = app.exercise(widget.exerciseId)!;
    final analysis = app.analyze(ex);
    final metrics = metricsFor(ex, analysis.unit);
    final metric = metrics.firstWhere(
      (m) => m.id == _metric,
      orElse: () => metrics.first,
    );
    final sessions = analysis.sessions;
    final values = [
      for (final s in sessions) metricValue(ex, s.sets, metric.id),
    ];
    final records = recordFlags(values);
    final n = values.length;
    final sel = _selected != null && _selected! < n ? _selected! : n - 1;
    final today = app.today;
    String dateText(DateTime d) =>
        daysBetween(d, today) == 0 ? 'Hoy' : shortDate(d);

    final delta = n >= 2
        ? ((values.last - values.first) * 10).round() / 10
        : 0.0;
    final deltaTrend = delta > 0
        ? Trend.up
        : (delta < 0 ? Trend.down : Trend.flat);
    final (deltaIcon, deltaColor) = trendStyle(deltaTrend);
    final (statusIcon, statusColor) = trendStyle(analysis.trend);
    final suggestion = analysis.suggestion;
    final day = app.selectedDay;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackPill(
                        label: widget.backLabel,
                        onTap: () => Navigator.pop(context),
                      ),
                      GroupTag(groupLabel(ex.group)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ScreenTitle(ex.name, size: 36),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                children: [
                  _MetricSwitch(
                    metrics: metrics,
                    selected: metric.id,
                    onSelect: (id) => setState(() {
                      _metric = id;
                      _selected = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  if (n >= 2) ...[
                    SurfaceCard(
                      padding: const EdgeInsets.only(top: 16, bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              metric.parts(values[sel]).$1,
                                              style: AppText.display(
                                                52,
                                                height: 0.95,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              metric.parts(values[sel]).$2,
                                              style: AppText.body(
                                                16,
                                                weight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${dateText(sessions[sel].date)} · ${setsText(ex, sessions[sel].sets)}',
                                          style: AppText.body(
                                            13,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (records[sel])
                                  const RecordBadge(height: 28, fontSize: 12),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ProgressChart(
                            values: values,
                            records: records,
                            selected: sel,
                            labels: [
                              for (final s in sessions) dateText(s.date),
                            ],
                            metric: metric,
                            onSelect: (i) => setState(() => _selected = i),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                            child: Wrap(
                              spacing: 14,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _Legend(filled: true, label: 'Récord'),
                                _Legend(filled: false, label: 'Sesión'),
                                Text(
                                  'Toca un punto para ver la sesión',
                                  style: AppText.body(
                                    12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        AppIcon(deltaIcon, color: deltaColor, strokeWidth: 2.6),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${metric.formatDelta(delta)} de ${metric.long} en ${analysis.weeks} '
                            '${plural(analysis.weeks, 'semana', 'semanas')}',
                            style: AppText.body(15, weight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const EmptyBox(
                      padding: EdgeInsets.all(20),
                      child: EmptyText(
                        'Registra este ejercicio en al menos dos sesiones para ver tu gráfica de progreso.',
                      ),
                    ),
                  const SizedBox(height: 14),
                  SurfaceCard(
                    radius: 20,
                    borderWidth: 1.5,
                    borderColor: analysis.trend == Trend.up
                        ? AppColors.accentSoft(0.45)
                        : AppColors.border,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppIcon(
                              statusIcon,
                              size: 18,
                              color: statusColor,
                              strokeWidth: 2.8,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              analysis.trend.label.toUpperCase(),
                              style: AppText.label(
                                size: 13,
                                tracking: 0.1,
                                weight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          analysis.statusText,
                          style: AppText.body(
                            15,
                            color: AppColors.textSoft,
                            height: 1.45,
                          ),
                        ),
                        if (suggestion != null) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          const SectionLabel('Para la próxima sesión'),
                          const SizedBox(height: 6),
                          Text(
                            suggestion,
                            style: AppText.body(
                              15,
                              color: AppColors.textSoft,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (sessions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const SectionLabel('Historial'),
                    const SizedBox(height: 6),
                    for (var i = n - 1; i >= 0; i--)
                      _HistoryRow(
                        date: dateText(sessions[i].date),
                        isToday: daysBetween(sessions[i].date, today) == 0,
                        summary: setsText(ex, sessions[i].sets),
                        value: metric.format(values[i]),
                        record: records[i],
                      ),
                  ],
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Registrar ${app.dayWord(day)}',
                    height: 58,
                    radius: 18,
                    onTap: () {
                      app.addExerciseToDay(day, ex.id);
                      pushScreen(
                        context,
                        LogExerciseScreen(exerciseId: ex.id, day: day),
                      );
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

class _MetricSwitch extends StatelessWidget {
  const _MetricSwitch({
    required this.metrics,
    required this.selected,
    required this.onSelect,
  });
  final List<Metric> metrics;
  final MetricId selected;
  final ValueChanged<MetricId> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Pressable(
                onTap: () => onSelect(metrics[i].id),
                selected: metrics[i].id == selected,
                color: metrics[i].id == selected
                    ? AppColors.accent
                    : Colors.transparent,
                radius: 10,
                height: 44,
                child: Center(
                  child: Text(
                    metrics[i].label,
                    style: AppText.body(
                      14,
                      weight: FontWeight.w700,
                      color: metrics[i].id == selected
                          ? AppColors.background
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.filled, required this.label});
  final bool filled;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.accent : null,
            border: filled
                ? null
                : Border.all(color: AppColors.accent, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.body(12, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.date,
    required this.isToday,
    required this.summary,
    required this.value,
    required this.record,
  });
  final String date;
  final bool isToday;
  final String summary;
  final String value;
  final bool record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: AppText.body(
                    14,
                    weight: FontWeight.w700,
                    color: isToday ? AppColors.accent : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: AppText.body(13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (record) ...[
            const RecordBadge(label: 'PR', outlined: true),
            const SizedBox(width: 12),
          ],
          Text(value, style: AppText.display(22, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Gráfica de línea con área, rejilla de 3 líneas y puntos tocables.
class _ProgressChart extends StatelessWidget {
  const _ProgressChart({
    required this.values,
    required this.records,
    required this.selected,
    required this.labels,
    required this.metric,
    required this.onSelect,
  });

  final List<double> values;
  final List<bool> records;
  final int selected;
  final List<String> labels;
  final Metric metric;
  final ValueChanged<int> onSelect;

  static const _height = 196.0, _x0 = 40.0, _y0 = 18.0, _y1 = 158.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final geo = _ChartGeometry(values, width - 18);
        final n = values.length;
        final xIdx = {0, (n - 1) ~/ 2, n - 1}.toList();

        return SizedBox(
          height: _height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: CustomPaint(painter: _ChartPainter(geo))),
              for (final t in const [0.0, 0.5, 1.0])
                Positioned(
                  left: 0,
                  width: 34,
                  top: geo.y(geo.lo + t * (geo.hi - geo.lo)) - 8,
                  child: Text(
                    geo.tick(geo.lo + t * (geo.hi - geo.lo), metric.isTime),
                    textAlign: TextAlign.right,
                    style: AppText.body(
                      11,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (final i in xIdx)
                Positioned(
                  top: 172,
                  left: (geo.x(i) - 30).clamp(10, width - 70),
                  width: 60,
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppText.body(
                      11,
                      weight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              for (var i = 0; i < n; i++)
                Positioned(
                  left: geo.x(i) - 16,
                  top: geo.y(values[i]) - 16,
                  width: 32,
                  height: 32,
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label:
                        '${labels[i]}: ${metric.format(values[i])}${records[i] ? ', récord' : ''}',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onSelect(i),
                      child: Center(
                        child: Container(
                          width: i == selected ? 16 : 10,
                          height: i == selected ? 16 : 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == selected || records[i]
                                ? AppColors.accent
                                : AppColors.surface,
                            border: Border.all(
                              color: i == selected
                                  ? AppColors.text
                                  : AppColors.accent,
                              width: 2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.surface,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ChartGeometry {
  _ChartGeometry(this.values, this.x1) {
    final mn = values.reduce(math.min), mx = values.reduce(math.max);
    final range = (mx - mn) == 0 ? math.max(1.0, mx * 0.1) : mx - mn;
    lo = math.max(0, mn - range * 0.25);
    hi = mx + range * 0.25;
  }

  final List<double> values;
  final double x1;
  late final double lo, hi;

  double x(int i) => values.length < 2
      ? (_ProgressChart._x0 + x1) / 2
      : _ProgressChart._x0 +
            i * (x1 - _ProgressChart._x0) / (values.length - 1);

  double y(double v) {
    const y0 = _ProgressChart._y0, y1 = _ProgressChart._y1;
    final span = (hi - lo) == 0 ? 1 : hi - lo;
    return y1 - (v - lo) / span * (y1 - y0);
  }

  /// Etiqueta del eje: «62,5», «1.200» o, por tiempo, «45s» y «20:30».
  String tick(double v, bool time) {
    if (time) {
      final s = v.round();
      if (s < 60) return '${s}s';
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }
    return v >= 1000 ? thousands(v) : (v >= 20 ? '${v.round()}' : fmtNum(v));
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.geo);
  final _ChartGeometry geo;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final t in const [0.0, 0.5, 1.0]) {
      final y = geo.y(geo.lo + t * (geo.hi - geo.lo)).roundToDouble();
      canvas.drawLine(
        Offset(_ProgressChart._x0, y),
        Offset(size.width - 10, y),
        grid,
      );
    }
    final pts = [
      for (var i = 0; i < geo.values.length; i++)
        Offset(geo.x(i), geo.y(geo.values[i])),
    ];
    final line = Path()..addPolygon(pts, false);
    final area = Path()
      ..addPolygon([
        ...pts,
        Offset(pts.last.dx, _ProgressChart._y1),
        Offset(pts.first.dx, _ProgressChart._y1),
      ], true);
    canvas.drawPath(area, Paint()..color = AppColors.accentSoft(0.1));
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
