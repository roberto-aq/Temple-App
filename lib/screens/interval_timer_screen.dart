import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../device/interval_cues.dart';
import '../logic/format.dart';
import '../logic/intervals.dart';
import '../models/intervals.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/interval_controls.dart';
import '../widgets/ui.dart';

enum _Stage { ready, running, finished }

/// Temporizador de una plantilla de Intervalos: preparar (y elegir el peso),
/// correr con avisos de sonido y vibración, y al final guardar la sesión.
class IntervalTimerScreen extends StatefulWidget {
  const IntervalTimerScreen({super.key, required this.protocol});

  final IntervalProtocol protocol;

  @override
  State<IntervalTimerScreen> createState() => _IntervalTimerScreenState();
}

class _IntervalTimerScreenState extends State<IntervalTimerScreen> {
  final _cues = IntervalCues.instance;
  final _notes = TextEditingController();

  late final IntervalProtocol _p = widget.protocol;
  late final List<IntervalStep> _steps = intervalTimeline(_p);
  late IntervalRun _run;

  _Stage _stage = _Stage.ready;
  Timer? _ticker;
  int _lastIndex = 0;
  int _lastTick = -1;
  bool _locked = false;
  bool _confirmDiscard = false;
  DateTime? _startedAt;
  List<IntervalRound> _done = const [];

  /// Peso en la unidad elegida; se pasa a kg al guardar.
  double _weight = 20;
  WeightUnit _unit = WeightUnit.kg;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_cues.prepare());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = AppScope.read(context);
    _run = IntervalRun(_steps, () => app.now);
    // El peso de la última vez, en su unidad.
    final last = app.lastIntervalSession(_p.id);
    if (last?.kg != null) {
      _unit = last!.unit;
      _weight = (_unit.fromKg(last.kg!) * 100).round() / 100;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_cues.keepAwake(false));
    _notes.dispose();
    super.dispose();
  }

  double get _maxWeight => _unit == WeightUnit.lb ? 999 : 500;
  double get _weightStep => _unit == WeightUnit.lb ? 5 : 2.5;

  void _setUnit(WeightUnit unit) {
    if (unit == _unit) return;
    setState(() {
      final v = unit.fromKg(_unit.toKg(_weight));
      final r = unit == WeightUnit.lb ? 2.5 : 0.5;
      _unit = unit;
      _weight = ((v / r).round() * r).clamp(0, _maxWeight).toDouble();
    });
  }

  // ---------------------------------------------------------------------------
  // Temporizador
  // ---------------------------------------------------------------------------

  void _start() {
    _startedAt = AppScope.read(context).now;
    _run.start();
    _lastIndex = _run.index;
    _lastTick = -1;
    unawaited(_cues.keepAwake(true));
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    setState(() => _stage = _Stage.running);
  }

  /// Revisa la fase cada décima de segundo: avisa al cambiar de tramo y en los
  /// últimos 3 segundos de cada uno.
  void _tick() {
    if (!mounted || _stage != _Stage.running) return;
    final i = _run.index;
    if (i != _lastIndex) {
      _lastIndex = i;
      _lastTick = -1;
      if (i >= _steps.length) {
        _cues.done();
        _complete();
        return;
      }
      _steps[i].phase == IntervalPhase.work ? _cues.work() : _cues.rest();
    } else if (_run.running) {
      final left = _run.remainingSeconds;
      final step = _run.current;
      if (step != null &&
          left >= 1 &&
          left <= 3 &&
          left < step.seconds &&
          left != _lastTick) {
        _lastTick = left;
        _cues.tick();
      }
    }
    setState(() {});
  }

  void _togglePause() {
    setState(() => _run.running ? _run.pause() : _run.resume());
  }

  void _skip() {
    _run.skip();
    _tick();
  }

  void _finishEarly() {
    _run.finish();
    _complete();
  }

  void _complete() {
    _ticker?.cancel();
    unawaited(_cues.keepAwake(false));
    setState(() {
      _stage = _Stage.finished;
      _locked = false;
      _done = _run.rounds;
    });
  }

  void _save() {
    final app = AppScope.read(context);
    app.addIntervalSession(
      protocol: _p,
      startedAt: _startedAt!,
      done: _done,
      kg: _p.weighted ? _unit.toKg(_weight) : null,
      unit: _unit,
      notes: _notes.text,
    );
    app.flash('Sesión de «${_p.name}» guardada.', ToastTarget.intervals);
    Navigator.pop(context);
  }

  void _onBack() {
    switch (_stage) {
      case _Stage.ready:
        Navigator.pop(context);
      case _Stage.running:
        // Con la pantalla bloqueada no se sale por accidente.
        if (!_locked) _finishEarly();
      case _Stage.finished:
        if (_done.isEmpty) {
          Navigator.pop(context);
        } else {
          setState(() => _confirmDiscard = true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: switch (_stage) {
          _Stage.ready => _buildReady(context),
          _Stage.running => _buildRunning(context),
          _Stage.finished => _buildFinished(context),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Antes de empezar
  // ---------------------------------------------------------------------------

  Widget _buildReady(BuildContext context) {
    final p = _p;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [BackPill(label: 'Volver', onTap: _onBack)],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                ScreenTitle(p.name, size: 40),
                const SizedBox(height: 6),
                Text(
                  intervalSummary(p),
                  style: AppText.body(15, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Row(
                    children: [
                      Expanded(child: _Stat('${p.rounds}', 'Rondas')),
                      Expanded(
                        child: _Stat(clockText(p.workSeconds), 'Trabajo'),
                      ),
                      Expanded(
                        child: _Stat(clockText(p.restSeconds), 'Descanso'),
                      ),
                      Expanded(
                        child: _Stat(
                          clockText(intervalTotalSeconds(p)),
                          'Total',
                          accent: true,
                        ),
                      ),
                    ],
                  ),
                ),
                if (p.weighted) ...[
                  const SizedBox(height: 22),
                  const SectionLabel('Peso'),
                  const SizedBox(height: 8),
                  UnitChoice(
                    options: [
                      for (final u in WeightUnit.values)
                        (u, u.symbol.toUpperCase(), u.word),
                    ],
                    value: _unit,
                    onChanged: _setUnit,
                  ),
                  const SizedBox(height: 8),
                  ValueStepper(
                    label: 'Peso en ${_unit.word}',
                    value: fmtNum(_weight),
                    unit: _unit.symbol,
                    minusLabel: 'Restar ${fmtNum(_weightStep)} ${_unit.symbol}',
                    plusLabel: 'Sumar ${fmtNum(_weightStep)} ${_unit.symbol}',
                    onMinus: _weight <= 0
                        ? null
                        : () => setState(
                            () => _weight = math.max(0, _weight - _weightStep),
                          ),
                    onPlus: _weight >= _maxWeight
                        ? null
                        : () => setState(
                            () => _weight = math.min(
                              _maxWeight,
                              _weight + _weightStep,
                            ),
                          ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Empieza con $intervalPrepareSeconds segundos para prepararte. '
                  'Suena y vibra al cambiar de fase y en los últimos 3 segundos; '
                  'la pantalla queda encendida mientras corre.',
                  style: AppText.body(
                    14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          BottomActionBar(label: 'Empezar', onTap: _start),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Corriendo
  // ---------------------------------------------------------------------------

  Widget _buildRunning(BuildContext context) {
    final step = _run.current ?? _steps.last;
    final paused = _run.paused;
    final work = step.phase == IntervalPhase.work;
    final bg = work ? AppColors.accent : AppColors.background;
    final fg = work ? AppColors.background : AppColors.text;
    final phaseColor = switch (step.phase) {
      IntervalPhase.work => AppColors.background,
      IntervalPhase.change => AppColors.alert,
      IntervalPhase.prepare => AppColors.accent,
      _ => AppColors.textSoft,
    };
    final roundText = work
        ? 'Ronda ${step.round} de ${_p.rounds}'
        : 'Sigue: ronda ${step.round} de ${_p.rounds}';
    final next = _run.next;
    final nextText = next == null
        ? 'Último tramo'
        : 'Después: ${_stepName(next)} · ${durationText(next.seconds)}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: work ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: bg,
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              roundText.toUpperCase(),
                              style: AppText.label(size: 14, color: fg),
                            ),
                          ),
                          Text(
                            _p.name,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(
                              14,
                              weight: FontWeight.w600,
                              color: fg.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          label:
                              '${step.phase.label}${_p.sided ? ', ${step.side.label}' : ''}, '
                              'quedan ${durationText(_run.remainingSeconds)}',
                          excludeSemantics: true,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                (paused ? 'En pausa' : step.phase.label)
                                    .toUpperCase(),
                                style: AppText.display(
                                  44,
                                  color: paused ? fg : phaseColor,
                                  height: 1,
                                ),
                              ),
                              if (_p.sided) ...[
                                const SizedBox(height: 6),
                                Text(
                                  step.side.label.toUpperCase(),
                                  style: AppText.display(
                                    30,
                                    weight: FontWeight.w700,
                                    color: fg,
                                    height: 1,
                                  ),
                                ),
                              ],
                              FittedBox(
                                child: Text(
                                  clockText(_run.remainingSeconds),
                                  style: AppText.display(
                                    170,
                                    color: fg,
                                    height: 1.05,
                                  ),
                                ),
                              ),
                              Text(
                                nextText,
                                textAlign: TextAlign.center,
                                style: AppText.body(
                                  16,
                                  weight: FontWeight.w600,
                                  color: fg.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _ProgressBar(
                        value: _run.stepProgress,
                        color: work ? AppColors.background : AppColors.accent,
                        track: work
                            ? AppColors.background.withValues(alpha: 0.18)
                            : AppColors.control,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.navBackground,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.paddingOf(context).bottom.clamp(8, 40),
              ),
              child: _locked ? _unlockButton() : _controls(paused),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(bool paused) {
    return Row(
      children: [
        CircleIconButton(
          icon: AppIcons.lock,
          size: 56,
          radius: 16,
          color: AppColors.control,
          semanticLabel: 'Bloquear la pantalla',
          onTap: () => setState(() => _locked = true),
        ),
        const SizedBox(width: 10),
        CircleIconButton(
          icon: AppIcons.skip,
          size: 56,
          radius: 16,
          color: AppColors.control,
          semanticLabel: 'Saltar al siguiente tramo',
          onTap: _skip,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Pressable(
            onTap: _togglePause,
            color: AppColors.accent,
            radius: 16,
            height: 56,
            semanticLabel: paused ? 'Seguir' : 'Pausar',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(
                  paused ? AppIcons.play : AppIcons.pause,
                  color: AppColors.background,
                  strokeWidth: 2.8,
                ),
                const SizedBox(width: 8),
                Text(
                  paused ? 'Seguir' : 'Pausa',
                  style: AppText.body(
                    17,
                    weight: FontWeight.w700,
                    color: AppColors.background,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        CircleIconButton(
          icon: AppIcons.stop,
          size: 56,
          radius: 16,
          color: AppColors.control,
          iconColor: AppColors.alert,
          semanticLabel: 'Terminar',
          onTap: _finishEarly,
        ),
      ],
    );
  }

  /// Bloqueado: los toques no hacen nada; se desbloquea manteniendo presionado.
  Widget _unlockButton() {
    return Semantics(
      button: true,
      label: 'Pantalla bloqueada. Mantén presionado para desbloquear.',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(() => _locked = false);
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.control,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderStrong, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppIcon(AppIcons.lock, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(
                'Mantén presionado para desbloquear',
                style: AppText.body(15, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stepName(IntervalStep s) => switch (s.phase) {
    IntervalPhase.work =>
      _p.sided ? 'trabajo ${s.side.label.toLowerCase()}' : 'trabajo',
    IntervalPhase.change => 'cambio de lado',
    IntervalPhase.rest => 'descanso',
    IntervalPhase.prepare => 'preparación',
    IntervalPhase.done => 'fin',
  };

  // ---------------------------------------------------------------------------
  // Al terminar
  // ---------------------------------------------------------------------------

  Widget _buildFinished(BuildContext context) {
    final p = _p;
    final complete = roundsCompleted(_done, sided: p.sided);
    final all =
        complete >= p.rounds && _done.every((r) => r.seconds >= p.workSeconds);
    final total = _done.fold(0, (s, r) => s + r.seconds);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                SectionLabel(p.name),
                const SizedBox(height: 4),
                ScreenTitle(all ? '¡Completado!' : 'Terminado', size: 44),
                const SizedBox(height: 16),
                if (_done.isEmpty)
                  const EmptyBox(
                    child: EmptyText(
                      'No alcanzaste a hacer ninguna ronda, así que no hay nada que guardar.',
                      align: TextAlign.start,
                    ),
                  )
                else ...[
                  SurfaceCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: _Stat(
                            '$complete/${p.rounds}',
                            'Rondas',
                            accent: true,
                          ),
                        ),
                        Expanded(child: _Stat(clockText(total), 'Trabajo')),
                        if (p.weighted)
                          Expanded(
                            child: _Stat(
                              '${fmtNum(_weight)} ${_unit.symbol}',
                              'Peso',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final r in _done)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
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
                          if (p.sided)
                            Expanded(
                              child: Text(
                                r.side.label,
                                style: AppText.body(15),
                              ),
                            )
                          else
                            const Spacer(),
                          Text(
                            durationText(r.seconds),
                            style: AppText.display(
                              20,
                              weight: FontWeight.w700,
                              color: r.seconds < p.workSeconds
                                  ? AppColors.alert
                                  : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  const SectionLabel('Observaciones (opcional)'),
                  const SizedBox(height: 8),
                  NotesField(controller: _notes),
                ],
                if (_confirmDiscard) ...[
                  const SizedBox(height: 16),
                  DangerConfirm(
                    title: '¿Descartar esta sesión?',
                    message: 'No se guardará en el registro.',
                    confirmLabel: 'Descartar',
                    onCancel: () => setState(() => _confirmDiscard = false),
                    onConfirm: () => Navigator.pop(context),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.navBackground,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.paddingOf(context).bottom.clamp(12, 40),
            ),
            child: _done.isEmpty
                ? PrimaryButton(
                    label: 'Salir',
                    height: 60,
                    radius: 18,
                    onTap: () => Navigator.pop(context),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PrimaryButton(
                        label: 'Guardar sesión',
                        icon: AppIcons.check,
                        height: 60,
                        fontSize: 19,
                        radius: 18,
                        onTap: _save,
                      ),
                      const SizedBox(height: 8),
                      SecondaryButton(
                        label: 'Descartar',
                        height: 46,
                        fontSize: 15,
                        radius: 14,
                        onTap: () => setState(() => _confirmDiscard = true),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label, {this.accent = false});
  final String value;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FittedBox(
          child: Text(
            value,
            style: AppText.display(
              28,
              color: accent ? AppColors.accent : AppColors.text,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label.toUpperCase(), style: AppText.label(size: 11)),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.value,
    required this.color,
    required this.track,
  });
  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: 8,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: track)),
              FractionallySizedBox(
                widthFactor: value.clamp(0, 1).toDouble(),
                child: ColoredBox(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de observaciones de varias líneas.
class NotesField extends StatelessWidget {
  const NotesField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return TextField(
      controller: controller,
      minLines: 2,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [
        LengthLimitingTextInputFormatter(IntervalLimits.maxNotes),
      ],
      style: AppText.body(16, height: 1.35),
      decoration: InputDecoration(
        hintText: 'Cómo te sentiste, molestias, ajustes…',
        hintStyle: AppText.body(16, color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: border(AppColors.borderStrong),
        focusedBorder: border(AppColors.textSecondary),
      ),
    );
  }
}
