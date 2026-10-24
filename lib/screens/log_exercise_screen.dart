import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalog.dart';
import '../logic/format.dart';
import '../logic/progress.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'exercise_progress_screen.dart';
import 'home_shell.dart';

/// 2 · Registrar ejercicio: anotar series y compararlas con la última vez.
class LogExerciseScreen extends StatefulWidget {
  const LogExerciseScreen({
    super.key,
    required this.exerciseId,
    required this.day,
  });

  final String exerciseId;
  final DateTime day;

  @override
  State<LogExerciseScreen> createState() => _LogExerciseScreenState();
}

class _LogExerciseScreenState extends State<LogExerciseScreen> {
  final _repsCtrl = TextEditingController();
  final _kgCtrl = TextEditingController();
  final _repsFocus = FocusNode();
  final _kgFocus = FocusNode();

  int _reps = 10;
  double _kg = 0;
  int? _editIdx;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _repsFocus.addListener(() => _onFocusChange(_repsFocus, _repsCtrl));
    _kgFocus.addListener(() => _onFocusChange(_kgFocus, _kgCtrl));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = AppScope.read(context);
    final ex = app.exercise(widget.exerciseId)!;
    final logged = app.setsOn(widget.day, ex.id);
    final prev = app.previousSession(ex.id, widget.day);
    if (logged.isNotEmpty) {
      _setDraft(logged.last.reps, logged.last.kg ?? 0);
    } else if (prev != null && prev.sets.isNotEmpty) {
      _setDraft(prev.sets.first.reps, prev.sets.first.kg ?? 0);
    } else {
      _setDraft(ex.timed ? 30 : 10, ex.weighted ? 20 : 0);
    }
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    _kgCtrl.dispose();
    _repsFocus.dispose();
    _kgFocus.dispose();
    super.dispose();
  }

  void _setDraft(int reps, double kg) {
    _reps = reps;
    _kg = kg;
    _repsCtrl.text = '$reps';
    _kgCtrl.text = fmtNum(kg);
  }

  void _onFocusChange(FocusNode node, TextEditingController ctrl) {
    if (!mounted) return;
    if (node.hasFocus) {
      ctrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: ctrl.text.length,
      );
    } else {
      // Al salir del campo se muestra el valor válido vigente.
      setState(() => _setDraft(_reps, _kg));
    }
  }

  void _onRepsChanged(String v) {
    final n = int.tryParse(v);
    if (n != null && n > 0) _reps = n > 300 ? 300 : n;
  }

  void _onKgChanged(String v) {
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n != null) _kg = n > 500 ? 500 : n;
  }

  void _bump({int reps = 0, double kg = 0, required int step}) {
    FocusScope.of(context).unfocus();
    setState(
      () => _setDraft(
        (_reps + reps).clamp(step, 300),
        (_kg + kg).clamp(0, 500).toDouble(),
      ),
    );
  }

  void _saveSet(AppState app, Exercise ex) {
    FocusScope.of(context).unfocus();
    final entry = SetEntry(reps: _reps, kg: ex.weighted ? _kg : null);
    final idx = _editIdx;
    if (idx != null && idx < app.setsOn(widget.day, ex.id).length) {
      app.replaceSet(widget.day, ex.id, idx, entry);
    } else {
      app.addSet(widget.day, ex.id, entry);
    }
    HapticFeedback.lightImpact();
    setState(() => _editIdx = null);
  }

  void _toggleEdit(int i, SetEntry s) {
    setState(() {
      if (_editIdx == i) {
        _editIdx = null;
      } else {
        _editIdx = i;
        _setDraft(s.reps, s.kg ?? 0);
      }
    });
  }

  void _removeSet(AppState app, Exercise ex, int i) {
    app.removeSet(widget.day, ex.id, i);
    setState(() {
      final ei = _editIdx;
      if (ei == null) return;
      _editIdx = ei == i ? null : (ei > i ? ei - 1 : ei);
    });
  }

  /// Siguiente ejercicio sin series en el orden de la sesión, dando la vuelta.
  String? _nextExercise(AppState app) {
    final session = app.sessionExercises(widget.day);
    final cur = session.indexOf(widget.exerciseId);
    final ordered = [
      ...session.sublist(cur + 1),
      ...session.sublist(0, cur < 0 ? 0 : cur),
    ];
    for (final id in ordered) {
      if (app.setsOn(widget.day, id).isEmpty) return id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ex = app.exercise(widget.exerciseId)!;
    final day = widget.day;
    final logged = app.setsOn(day, ex.id);
    final prev = app.previousSession(ex.id, day);
    final beat = beatInfo(ex, prev, logged, app.priorBest(ex, day));
    final editing = _editIdx != null && _editIdx! < logged.length;
    final nextId = logged.isNotEmpty ? _nextExercise(app) : null;
    final dayWord = app.dayWord(day);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackPill(
                        label: app.isToday(day)
                            ? 'Hoy'
                            : weekdaysLong[day.weekday - 1],
                        semanticLabel: 'Volver al entrenamiento',
                        onTap: () => goToTab(context, AppTab.hoy),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${logged.length}',
                        style: AppText.display(
                          52,
                          height: 1,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${plural(logged.length, 'serie', 'series')} $dayWord',
                          style: AppText.body(
                            16,
                            weight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SetPills(
                            count: logged.length,
                            alignment: WrapAlignment.end,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (beat != null) ...[
                    const SizedBox(height: 14),
                    _BeatCard(beat),
                  ],
                  const SizedBox(height: 14),
                  SectionLabel(
                    editing
                        ? 'Editando serie ${_editIdx! + 1}'
                        : 'Serie ${logged.length + 1}',
                    color: editing ? AppColors.accent : AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Counter(
                          label: ex.timed ? 'Segundos' : 'Repeticiones',
                          controller: _repsCtrl,
                          focusNode: _repsFocus,
                          highlighted: editing,
                          decimal: false,
                          onChanged: _onRepsChanged,
                          onMinus: () => _bump(reps: -ex.step, step: ex.step),
                          onPlus: () => _bump(reps: ex.step, step: ex.step),
                          minusLabel: 'Restar repeticiones',
                          plusLabel: 'Sumar repeticiones',
                        ),
                      ),
                      if (ex.weighted) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Counter(
                            label: 'Peso (kg)',
                            controller: _kgCtrl,
                            focusNode: _kgFocus,
                            highlighted: editing,
                            decimal: true,
                            onChanged: _onKgChanged,
                            onMinus: () => _bump(kg: -2.5, step: ex.step),
                            onPlus: () => _bump(kg: 2.5, step: ex.step),
                            minusLabel: 'Restar 2,5 kg',
                            plusLabel: 'Sumar 2,5 kg',
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!editing)
                    PrimaryButton(
                      label: 'Agregar serie',
                      icon: AppIcons.plus,
                      height: 62,
                      fontSize: 19,
                      radius: 18,
                      onTap: () => _saveSet(app, ex),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Cancelar',
                            height: 62,
                            fontSize: 17,
                            radius: 18,
                            weight: FontWeight.w700,
                            onTap: () => setState(() => _editIdx = null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Guardar serie ${_editIdx! + 1}',
                            height: 62,
                            radius: 18,
                            onTap: () => _saveSet(app, ex),
                          ),
                        ),
                      ],
                    ),
                  if (nextId != null) ...[
                    const SizedBox(height: 14),
                    SecondaryButton(
                      label: 'Siguiente: ${app.exercise(nextId)!.name}',
                      trailingIcon: AppIcons.arrowRight,
                      onTap: () => replaceScreen(
                        context,
                        LogExerciseScreen(exerciseId: nextId, day: day),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: SectionLabel('Series de $dayWord')),
                      if (logged.isNotEmpty)
                        Text(
                          'Toca una serie para editarla',
                          style: AppText.body(
                            13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (logged.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: EmptyText(
                        'Aún no registras series de este ejercicio.',
                        align: TextAlign.start,
                      ),
                    ),
                  for (var i = 0; i < logged.length; i++) ...[
                    _LoggedSetRow(
                      exercise: ex,
                      index: i,
                      entry: logged[i],
                      previous: prev != null && i < prev.sets.length
                          ? prev.sets[i]
                          : null,
                      editing: editing && _editIdx == i,
                      onEdit: () => _toggleEdit(i, logged[i]),
                      onRemove: () => _removeSet(app, ex, i),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Expanded(child: SectionLabel('La última vez')),
                      if (prev != null)
                        Text(
                          '${capitalize(agoText(prev.date, app.today))} · ${shortDate(prev.date)}',
                          style: AppText.body(
                            14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (prev == null)
                    const EmptyBox(
                      padding: EdgeInsets.all(14),
                      radius: 16,
                      child: EmptyText(
                        'Es la primera vez que registras este ejercicio.',
                        align: TextAlign.start,
                      ),
                    )
                  else
                    EmptyBox(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      radius: 16,
                      child: Column(
                        children: [
                          for (var i = 0; i < prev.sets.length; i++)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: i == prev.sets.length - 1
                                        ? Colors.transparent
                                        : AppColors.border,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Serie ${i + 1}',
                                    style: AppText.body(
                                      14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '${prev.sets[i].reps} ${unitWord(ex)}${ex.weighted ? ' · ${fmtNum(prev.sets[i].kg ?? 0)} kg' : ''}',
                                    style: AppText.display(
                                      22,
                                      weight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 14),
                  SecondaryButton(
                    label: 'Ver mi progreso en este ejercicio',
                    icon: AppIcons.chart,
                    onTap: () => pushScreen(
                      context,
                      ExerciseProgressScreen(
                        exerciseId: ex.id,
                        backLabel: 'Volver',
                      ),
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

class _BeatCard extends StatelessWidget {
  const _BeatCard(this.beat);
  final BeatInfo beat;

  @override
  Widget build(BuildContext context) {
    final record = beat.state == BeatState.record;
    final beaten = beat.state == BeatState.beaten;
    final icon = record
        ? AppIcons.trophy
        : (beaten ? AppIcons.check : AppIcons.arrowUp);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: record
              ? AppColors.accent
              : (beaten ? AppColors.accentSoft(0.1) : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: record || beaten ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: record
                    ? AppColors.background.withValues(alpha: 0.14)
                    : AppColors.accentSoft(0.12),
              ),
              child: Center(
                child: AppIcon(
                  icon,
                  color: record ? AppColors.background : AppColors.accent,
                  strokeWidth: 2.6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    beat.label.toUpperCase(),
                    style: AppText.label(
                      tracking: 0.1,
                      weight: FontWeight.w800,
                      color: record
                          ? AppColors.background
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    beat.text,
                    style: AppText.display(
                      23,
                      weight: FontWeight.w700,
                      height: 1.15,
                      color: record ? AppColors.background : AppColors.text,
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

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.highlighted,
    required this.decimal,
    required this.onChanged,
    required this.onMinus,
    required this.onPlus,
    required this.minusLabel,
    required this.plusLabel,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool highlighted;
  final bool decimal;
  final ValueChanged<String> onChanged;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final String minusLabel;
  final String plusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted ? AppColors.accent : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(label.toUpperCase(), style: AppText.label()),
          const SizedBox(height: 6),
          ListenableBuilder(
            listenable: focusNode,
            builder: (context, _) => Container(
              height: 80,
              decoration: BoxDecoration(
                color: focusNode.hasFocus
                    ? const Color(0xFF1B1D22)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                ),
              ),
              child: DashedBottomLine(
                color: focusNode.hasFocus
                    ? AppColors.textSecondary
                    : AppColors.dashed,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: decimal,
                  ),
                  inputFormatters: decimal
                      ? [_KgFormatter()]
                      : [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                  style: AppText.display(76, height: 1),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.only(top: 2),
                    semanticCounterText: label,
                  ),
                  cursorHeight: 60,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StepButton(
                  icon: AppIcons.minus,
                  label: minusLabel,
                  onTap: onMinus,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StepButton(
                  icon: AppIcons.plus,
                  label: plusLabel,
                  onTap: onPlus,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Acepta hasta 3 enteros y 2 decimales, con coma o punto.
class _KgFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var v = newValue.text
        .replaceAll('.', ',')
        .replaceAll(RegExp(r'[^0-9,]'), '');
    final parts = v.split(',');
    v = parts.first.length > 3 ? parts.first.substring(0, 3) : parts.first;
    if (parts.length > 1) {
      final dec = parts.sublist(1).join();
      v += ',${dec.length > 2 ? dec.substring(0, 2) : dec}';
    }
    return TextEditingValue(
      text: v,
      selection: TextSelection.collapsed(offset: v.length),
    );
  }
}

/// Línea inferior punteada del campo numérico.
class DashedBottomLine extends StatelessWidget {
  const DashedBottomLine({super.key, required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashLinePainter(color),
    child: Center(child: child),
  );
}

class _DashLinePainter extends CustomPainter {
  _DashLinePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    final y = size.height - 1;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, y), Offset((x + 6).clamp(0, size.width), y), p);
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter old) => old.color != color;
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: AppColors.control,
      borderColor: AppColors.borderStrong,
      radius: 14,
      height: 54,
      semanticLabel: label,
      child: Center(
        child: AppIcon(icon, size: 26, color: AppColors.text, strokeWidth: 2.6),
      ),
    );
  }
}

class _LoggedSetRow extends StatelessWidget {
  const _LoggedSetRow({
    required this.exercise,
    required this.index,
    required this.entry,
    required this.previous,
    required this.editing,
    required this.onEdit,
    required this.onRemove,
  });

  final Exercise exercise;
  final int index;
  final SetEntry entry;
  final SetEntry? previous;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    final cmp = previous == null ? null : compareSet(ex, entry, previous!);
    final (arrowIcon, arrowColor, arrowText) = switch (cmp) {
      SetCompare.up => (
        AppIcons.arrowUp,
        AppColors.accent,
        ', mejor que la última vez',
      ),
      SetCompare.equal => (
        AppIcons.equal,
        AppColors.textSecondary,
        ', igual que la última vez',
      ),
      SetCompare.down => (
        AppIcons.arrowDown,
        AppColors.alert,
        ', por debajo de la última vez',
      ),
      null => (null, Colors.transparent, ''),
    };
    final Color bg, border, numColor;
    if (editing) {
      bg = AppColors.accentSoft(0.1);
      border = AppColors.accent;
      numColor = AppColors.accent;
    } else if (cmp == SetCompare.up) {
      bg = AppColors.accentSoft(0.07);
      border = AppColors.accentSoft(0.4);
      numColor = AppColors.accent;
    } else if (cmp == SetCompare.down) {
      bg = AppColors.alertSoft(0.07);
      border = AppColors.alertSoft(0.4);
      numColor = AppColors.alert;
    } else {
      bg = AppColors.surface;
      border = AppColors.border;
      numColor = AppColors.textFaint;
    }
    final main =
        '${entry.reps} ${unitWord(ex)}${ex.weighted ? ' · ${fmtNum(entry.kg ?? 0)} kg' : ''}';
    final big = AppText.display(32, height: 1);
    final small = AppText.display(
      15,
      weight: FontWeight.w700,
      color: AppColors.textSecondary,
      height: 1,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Pressable(
              onTap: onEdit,
              color: Colors.transparent,
              radius: 12,
              height: 50,
              selected: editing,
              semanticLabel: 'Editar serie ${index + 1}: $main$arrowText',
              padding: const EdgeInsets.only(left: 6, right: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${index + 1}',
                      style: AppText.display(20, color: numColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          if (ex.weighted) ...[
                            Text(fmtNum(entry.kg ?? 0), style: big),
                            const SizedBox(width: 4),
                            Text('kg', style: small),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                '×',
                                style: AppText.display(
                                  22,
                                  weight: FontWeight.w700,
                                  color: AppColors.textDisabled,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                          Text('${entry.reps}', style: big),
                          const SizedBox(width: 4),
                          Text(unitWord(ex), style: small),
                        ],
                      ),
                    ),
                  ),
                  if (arrowIcon != null)
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: arrowColor,
                      ),
                      child: Center(
                        child: AppIcon(
                          arrowIcon,
                          color: AppColors.background,
                          strokeWidth: 3.2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          CircleIconButton(
            icon: AppIcons.close,
            semanticLabel: 'Eliminar serie ${index + 1}',
            onTap: onRemove,
            color: Colors.transparent,
            borderColor: null,
            iconColor: AppColors.textSecondary,
            radius: 12,
          ),
        ],
      ),
    );
  }
}
