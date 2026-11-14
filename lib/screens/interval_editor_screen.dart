import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../logic/intervals.dart';
import '../models/intervals.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/interval_controls.dart';
import '../widgets/ui.dart';
import 'new_exercise_screen.dart' show BigTextField;

/// Crear o editar una plantilla de Intervalos. Al guardar devuelve la plantilla.
class IntervalEditorScreen extends StatefulWidget {
  const IntervalEditorScreen({super.key, this.protocol});

  /// La plantilla a editar; null para crear una.
  final IntervalProtocol? protocol;

  @override
  State<IntervalEditorScreen> createState() => _IntervalEditorScreenState();
}

class _IntervalEditorScreenState extends State<IntervalEditorScreen> {
  late final _editing = widget.protocol;
  late final _name = TextEditingController(text: _editing?.name ?? '');
  late int _work = _editing?.workSeconds ?? 30;
  late int _rest = _editing?.restSeconds ?? 60;
  late int _rounds = _editing?.rounds ?? 5;
  late bool _sided = _editing?.sided ?? false;
  late int _switch = _editing?.switchSeconds ?? 10;
  late bool _weighted = _editing?.weighted ?? false;
  String? _error;
  bool _confirmDelete = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  IntervalProtocol get _draft => IntervalProtocol(
    id: _editing?.id ?? '',
    name: _name.text.trim(),
    workSeconds: _work,
    restSeconds: _rest,
    rounds: _rounds,
    sided: _sided,
    switchSeconds: _switch,
    weighted: _weighted,
  );

  void _save() {
    final app = AppScope.read(context);
    final name = _name.text.trim();
    String? error;
    if (name.isEmpty) {
      error = 'Ponle un nombre a la plantilla.';
    } else if (app.intervalNameExists(name, except: _editing?.id)) {
      error = 'Ya tienes una plantilla con ese nombre.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final p = app.saveIntervalProtocol(
      id: _editing?.id,
      name: name,
      workSeconds: _work,
      restSeconds: _rest,
      rounds: _rounds,
      sided: _sided,
      switchSeconds: _switch,
      weighted: _weighted,
    );
    app.flash(
      _editing == null ? '«${p.name}» creada.' : '«${p.name}» actualizada.',
      ToastTarget.intervals,
      highlightId: p.id,
    );
    Navigator.pop(context, p);
  }

  void _delete() {
    final app = AppScope.read(context);
    final p = _editing!;
    app.deleteIntervalProtocol(p.id);
    app.flash('«${p.name}» eliminada.', ToastTarget.intervals);
    Navigator.pop(context);
  }

  /// Un selector de tiempo entre [min] y [max] segundos.
  Widget _time(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged,
  ) {
    final (v, u) = _timeParts(value);
    return ValueStepper(
      label: label,
      value: v,
      unit: u,
      minusLabel: 'Restar a ${label.toLowerCase()}',
      plusLabel: 'Sumar a ${label.toLowerCase()}',
      onMinus: value <= min
          ? null
          : () => setState(() => onChanged(math.max(min, timeStepDown(value)))),
      onPlus: value >= max
          ? null
          : () => setState(() => onChanged(math.min(max, timeStepUp(value)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editing;
    final sessions = editing == null
        ? 0
        : AppScope.of(
            context,
          ).intervalSessions.where((s) => s.protocolId == editing.id).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BackPill(
                    label: 'Cancelar',
                    onTap: () => Navigator.pop(context),
                  ),
                  SectionLabel(
                    editing == null ? 'Nueva plantilla' : 'Editar plantilla',
                    size: 13,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  const SectionLabel('Ejercicio'),
                  const SizedBox(height: 8),
                  BigTextField(
                    controller: _name,
                    hint: 'Ej. Isométrico de talón',
                    error: _error != null && _name.text.trim().isEmpty,
                    autofocus: editing == null,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Tiempos'),
                  const SizedBox(height: 8),
                  _time(
                    'Trabajo',
                    _work,
                    5,
                    IntervalLimits.maxWork,
                    (v) => _work = v,
                  ),
                  const SizedBox(height: 8),
                  _time(
                    'Descanso',
                    _rest,
                    0,
                    IntervalLimits.maxRest,
                    (v) => _rest = v,
                  ),
                  const SizedBox(height: 8),
                  ValueStepper(
                    label: 'Rondas',
                    value: '$_rounds',
                    minusLabel: 'Restar una ronda',
                    plusLabel: 'Sumar una ronda',
                    onMinus: _rounds <= 1
                        ? null
                        : () => setState(() => _rounds--),
                    onPlus: _rounds >= IntervalLimits.maxRounds
                        ? null
                        : () => setState(() => _rounds++),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Opciones'),
                  const SizedBox(height: 8),
                  ToggleRow(
                    title: 'Por lado',
                    subtitle:
                        'Cada ronda hace el lado izquierdo y luego el derecho.',
                    value: _sided,
                    onChanged: (v) => setState(() => _sided = v),
                  ),
                  if (_sided) ...[
                    const SizedBox(height: 8),
                    _time(
                      'Cambio de lado',
                      _switch,
                      0,
                      IntervalLimits.maxSwitch,
                      (v) => _switch = v,
                    ),
                  ],
                  const SizedBox(height: 8),
                  ToggleRow(
                    title: 'Con peso',
                    subtitle:
                        'Anota el peso de cada sesión (p. ej. paseo del granjero).',
                    value: _weighted,
                    onChanged: (v) => setState(() => _weighted = v),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const AppIcon(
                        AppIcons.timer,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Dura ${durationText(intervalTotalSeconds(_draft))} · ${intervalSummary(_draft)}',
                          style: AppText.body(
                            14,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (editing != null) ...[
                    const SizedBox(height: 22),
                    if (!_confirmDelete)
                      SecondaryButton(
                        label: 'Eliminar plantilla',
                        icon: AppIcons.trash,
                        iconColor: AppColors.alert,
                        onTap: () => setState(() => _confirmDelete = true),
                      )
                    else
                      DangerConfirm(
                        title: '¿Eliminar «${editing.name}»?',
                        message: sessions == 0
                            ? 'Aún no tiene sesiones registradas.'
                            : 'Sus $sessions ${plural(sessions, 'sesión registrada se conserva', 'sesiones registradas se conservan')} en el registro.',
                        onCancel: () => setState(() => _confirmDelete = false),
                        onConfirm: _delete,
                      ),
                  ],
                ],
              ),
            ),
            BottomActionBar(
              label: editing == null ? 'Crear plantilla' : 'Guardar cambios',
              onTap: _save,
              error: _error,
            ),
          ],
        ),
      ),
    );
  }
}

/// «45» «seg», «1:30» «min» o «2» «min», para mostrar un tiempo en grande.
(String, String) _timeParts(int s) {
  if (s < 60) return ('$s', 'seg');
  final m = s ~/ 60, r = s % 60;
  return r == 0 ? ('$m', 'min') : ('$m:${r.toString().padLeft(2, '0')}', 'min');
}
