import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../logic/format.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/routine_draft.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'log_exercise_screen.dart';
import 'new_exercise_screen.dart';

enum LibraryMode {
  /// Pestaña «Ejercicios»: tocar uno lo registra en el día elegido.
  browse,

  /// Desde Hoy: elegir qué ejercicio agregar a la sesión.
  session,

  /// Desde el editor de rutinas: marcar varios para la rutina.
  draft,
}

/// 3 · Elegir ejercicio / Ejercicios.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.mode = LibraryMode.browse, this.draft});

  final LibraryMode mode;
  final RoutineDraft? draft;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String _group = 'todos';

  bool get _picking => widget.mode != LibraryMode.browse;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _log(Exercise ex) {
    final app = AppScope.read(context);
    final day = app.selectedDay;
    app.addExerciseToDay(day, ex.id);
    final screen = LogExerciseScreen(exerciseId: ex.id, day: day);
    if (widget.mode == LibraryMode.session) {
      replaceScreen(context, screen);
    } else {
      pushScreen(context, screen);
    }
  }

  Future<void> _create({String name = ''}) async {
    final app = AppScope.read(context);
    final mode = widget.mode;
    final ex = await pushScreen<Exercise>(
      context,
      NewExerciseScreen(
        initialName: name,
        initialGroup: _group == 'todos' ? null : _group,
        saveLabel: switch (mode) {
          LibraryMode.draft => 'Guardar y agregar a la rutina',
          LibraryMode.session => 'Guardar y registrar',
          LibraryMode.browse => 'Guardar ejercicio',
        },
      ),
    );
    if (ex == null || !mounted) return;
    setState(() {
      _search.clear();
      _group = ex.group;
    });
    switch (mode) {
      case LibraryMode.draft:
        widget.draft!.add(ex);
        app.flash('«${ex.name}» creado y agregado a la rutina.', ToastTarget.library, highlightId: ex.id);
      case LibraryMode.session:
        _log(ex);
      case LibraryMode.browse:
        app.flash('«${ex.name}» agregado a tu biblioteca.', ToastTarget.library, highlightId: ex.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.draft == null
        ? _buildContent(context)
        : ListenableBuilder(listenable: widget.draft!, builder: (context, _) => _buildContent(context));
    // En la pestaña ya hay Scaffold (HomeShell); al elegir, es una pantalla propia.
    return _picking ? Scaffold(body: SafeArea(child: body)) : body;
  }

  Widget _buildContent(BuildContext context) {
    final app = AppScope.of(context);
    final query = normalize(_search.text);
    final day = app.selectedDay;
    final dayWord = app.dayWord(day);
    final session = app.sessionExercises(day);
    final list = app.exercises.where((ex) {
      if (_group != 'todos' && ex.group != _group) return false;
      if (query.isEmpty) return true;
      return normalize(ex.name).contains(query) || normalize(groupLabel(ex.group)).contains(query);
    }).toList();
    final toast = app.toastFor(ToastTarget.library);
    final draft = widget.draft;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.mode == LibraryMode.draft)
                Row(
                  children: [
                    CircleIconButton(icon: AppIcons.chevronLeft, iconSize: 22, semanticLabel: 'Volver a la rutina', onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Agregando a «${draft!.name.trim().isEmpty ? 'Nueva rutina' : draft.name.trim()}»',
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(14, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Pressable(
                      onTap: () => Navigator.pop(context),
                      color: AppColors.accent,
                      radius: 99,
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        widthFactor: 1,
                        child: Text('Listo · ${draft.items.length}', style: AppText.body(15, weight: FontWeight.w700, color: AppColors.background)),
                      ),
                    ),
                  ],
                ),
              if (widget.mode == LibraryMode.session)
                Row(
                  children: [
                    CircleIconButton(icon: AppIcons.chevronLeft, iconSize: 22, semanticLabel: 'Volver al entrenamiento', onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Agregar a tu entrenamiento de $dayWord', style: AppText.body(14, color: AppColors.textSecondary))),
                  ],
                ),
              SizedBox(height: _picking ? 8 : 6),
              Row(
                children: [
                  Expanded(child: ScreenTitle(_picking ? 'Elegir ejercicio' : 'Ejercicios', size: 40)),
                  const SizedBox(width: 12),
                  HeaderActionPill(label: 'Crear', onTap: () => _create()),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: AppText.body(16),
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicio',
                  hintStyle: AppText.body(16, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 10),
                    child: AppIcon(AppIcons.search, color: AppColors.textSecondary),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 20),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar búsqueda',
                          onPressed: () => setState(_search.clear),
                          icon: const AppIcon(AppIcons.close, size: 18, color: AppColors.textSecondary),
                        ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.borderStrong),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ChipRow(
          semanticLabel: 'Filtrar por grupo muscular',
          children: [
            FilterChipButton(label: 'Todos', selected: _group == 'todos', onTap: () => setState(() => _group = 'todos')),
            for (final g in muscleGroups) FilterChipButton(label: g.label, selected: _group == g.id, onTap: () => setState(() => _group = g.id)),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            children: [
              if (toast != null) ...[ToastBanner(toast), const SizedBox(height: 8)],
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  '${list.length} ${plural(list.length, 'ejercicio', 'ejercicios')}'
                  '${widget.mode == LibraryMode.draft ? '' : ' · toca uno para registrarlo $dayWord'}',
                  style: AppText.body(13, color: AppColors.textSecondary),
                ),
              ),
              if (list.isEmpty)
                EmptyBox(
                  padding: const EdgeInsets.all(20),
                  radius: 16,
                  child: Column(
                    children: [
                      const EmptyText('No está en tu biblioteca.'),
                      if (_search.text.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Pressable(
                          onTap: () => _create(name: _search.text.trim()),
                          color: AppColors.accent,
                          radius: 14,
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Center(
                            widthFactor: 1,
                            child: Text('Crear «${_search.text.trim()}»',
                                style: AppText.body(15, weight: FontWeight.w700, color: AppColors.background)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              for (final ex in list) ...[
                if (draft != null)
                  _PickRow(exercise: ex, picked: draft.contains(ex.id), highlighted: app.highlightId == ex.id, onTap: () => draft.toggle(ex))
                else
                  _LogRow(
                    exercise: ex,
                    inSession: session.contains(ex.id),
                    setsToday: app.setsOn(day, ex.id).length,
                    dayWord: dayWord,
                    highlighted: app.highlightId == ex.id,
                    onTap: () => _log(ex),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.exercise, required this.picked, required this.highlighted, required this.onTap});
  final Exercise exercise;
  final bool picked;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ex = exercise;
    return Pressable(
      onTap: onTap,
      radius: 16,
      borderWidth: 1.5,
      borderColor: picked || highlighted ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      selected: picked,
      semanticLabel: '${picked ? 'Quitar' : 'Agregar'} ${ex.name}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: AppText.body(17, weight: FontWeight.w600, height: 1.2)),
                  const SizedBox(height: 2),
                  Text('${groupLabel(ex.group)}${ex.custom ? ' · Creado por ti' : ''}', style: AppText.body(13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked ? AppColors.accent : Colors.transparent,
                border: Border.all(color: picked ? AppColors.accent : AppColors.handle, width: 1.5),
              ),
              child: Center(
                child: AppIcon(picked ? AppIcons.check : AppIcons.plus, color: picked ? AppColors.background : AppColors.text, strokeWidth: picked ? 2.8 : 2.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.exercise,
    required this.inSession,
    required this.setsToday,
    required this.dayWord,
    required this.highlighted,
    required this.onTap,
  });

  final Exercise exercise;
  final bool inSession;
  final int setsToday;
  final String dayWord;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ex = exercise;
    final history = app.history(ex.id).where((s) => !s.date.isAfter(app.today)).toList();
    var info = 'Sin registros todavía';
    if (history.isNotEmpty) {
      final last = history.last.sets;
      info = 'Última: ${last.length} × ${last.first.reps} ${unitWord(ex)}${ex.weighted ? ' · ${fmtNum(last.first.kg ?? 0)} kg' : ''}';
    }
    if (ex.custom) info = 'Creado por ti · $info';
    final chip = inSession ? (setsToday > 0 ? '$setsToday series $dayWord' : 'En tu sesión') : groupLabel(ex.group);

    return Pressable(
      onTap: onTap,
      radius: 16,
      borderWidth: 1.5,
      borderColor: highlighted ? AppColors.accent : (inSession ? AppColors.accentSoft(0.45) : AppColors.border),
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      semanticLabel: 'Registrar ${ex.name} $dayWord',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: AppText.body(17, weight: FontWeight.w600, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(info, style: AppText.body(13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: inSession ? AppColors.accent : AppColors.surfaceRaised, borderRadius: BorderRadius.circular(99)),
              child: Text(chip, style: AppText.body(12, weight: FontWeight.w700, color: inSession ? AppColors.background : AppColors.textMuted)),
            ),
            const SizedBox(width: 12),
            const AppIcon(AppIcons.chevronRight, size: 18, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
