import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalog.dart';
import '../logic/format.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';

/// 6 · Crear ejercicio, o editar uno propio si se pasa [exercise].
/// Devuelve el [Exercise] creado o editado al cerrar (null si se eliminó).
class NewExerciseScreen extends StatefulWidget {
  const NewExerciseScreen({
    super.key,
    this.initialName = '',
    this.initialGroup,
    this.saveLabel = 'Guardar ejercicio',
    this.exercise,
  });

  final String initialName;
  final String? initialGroup;
  final String saveLabel;

  /// Ejercicio propio a editar: solo cambian el nombre y el grupo.
  final Exercise? exercise;

  @override
  State<NewExerciseScreen> createState() => _NewExerciseScreenState();
}

class _NewExerciseScreenState extends State<NewExerciseScreen> {
  late final _editing = widget.exercise;
  late final _name = TextEditingController(
    text: _editing?.name ?? widget.initialName,
  );
  late String? _group = _editing?.group ?? widget.initialGroup;
  late ExerciseKind _kind = _editing?.kind ?? ExerciseKind.weight;
  String? _error;
  bool _confirmDelete = false;

  static const _kinds = [
    (ExerciseKind.weight, 'Repeticiones y peso', 'Ej. press, sentadilla, curl'),
    (
      ExerciseKind.reps,
      'Solo repeticiones',
      'Ej. dominadas, flexiones, fondos',
    ),
    (
      ExerciseKind.seconds,
      'Tiempo (segundos o minutos)',
      'Ej. plancha, bicicleta estática',
    ),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final app = AppScope.read(context);
    final name = _name.text.trim();
    String? error;
    if (name.isEmpty) {
      error = 'Ponle un nombre al ejercicio.';
    } else if (_group == null) {
      error = 'Elige el grupo muscular.';
    } else if (app.exerciseNameExists(name, except: _editing?.id)) {
      error = 'Ya tienes un ejercicio con ese nombre.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final editing = _editing;
    Navigator.pop(
      context,
      editing == null
          ? app.createExercise(name: name, group: _group!, kind: _kind)
          : app.updateExercise(editing.id, name: name, group: _group!),
    );
  }

  void _delete() {
    final app = AppScope.read(context);
    final ex = _editing!;
    app.deleteExercise(ex.id);
    app.flash('«${ex.name}» eliminado.', ToastTarget.library);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _error != null && _name.text.trim().isEmpty;
    final editing = _editing;
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
                    editing == null ? 'Nuevo ejercicio' : 'Editar ejercicio',
                    size: 13,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  const SectionLabel('Nombre del ejercicio'),
                  const SizedBox(height: 8),
                  BigTextField(
                    controller: _name,
                    hint: 'Ej. Hip thrust',
                    error: nameError,
                    autofocus: editing == null && widget.initialName.isEmpty,
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Grupo muscular'),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2,
                    children: [
                      for (final g in muscleGroups)
                        Pressable(
                          onTap: () => setState(() {
                            _group = g.id;
                            _error = null;
                          }),
                          radius: 14,
                          borderWidth: 1.5,
                          selected: _group == g.id,
                          color: _group == g.id
                              ? AppColors.accent
                              : AppColors.surface,
                          borderColor: _group == g.id
                              ? AppColors.accent
                              : AppColors.borderStrong,
                          child: Center(
                            child: Text(
                              g.label,
                              style: AppText.body(
                                15,
                                weight: FontWeight.w600,
                                color: _group == g.id
                                    ? AppColors.background
                                    : AppColors.text,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Qué vas a registrar'),
                  const SizedBox(height: 8),
                  for (final (kind, title, sub) in _kinds)
                    // Al editar solo se muestra el tipo elegido, bloqueado.
                    if (editing == null) ...[
                      _KindOption(
                        title: title,
                        subtitle: sub,
                        selected: _kind == kind,
                        onTap: () => setState(() {
                          _kind = kind;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                    ] else if (kind == _kind)
                      // Sin el paréntesis, para que quepa junto a «BLOQUEADO».
                      _LockedKind(title: title.split(' (').first),
                  if (editing != null) ...[
                    const SizedBox(height: 22),
                    if (!_confirmDelete)
                      SecondaryButton(
                        label: 'Eliminar ejercicio',
                        icon: AppIcons.trash,
                        iconColor: AppColors.alert,
                        onTap: () => setState(() => _confirmDelete = true),
                      )
                    else
                      _DeleteConfirm(
                        exercise: editing,
                        onCancel: () => setState(() => _confirmDelete = false),
                        onDelete: _delete,
                      ),
                  ],
                ],
              ),
            ),
            BottomActionBar(
              label: editing == null ? widget.saveLabel : 'Guardar cambios',
              onTap: _save,
              error: _error,
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmación de borrado, con lo que se pierde junto al ejercicio.
class _DeleteConfirm extends StatelessWidget {
  const _DeleteConfirm({
    required this.exercise,
    required this.onCancel,
    required this.onDelete,
  });
  final Exercise exercise;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sets = app.setCount(exercise.id);
    final routines = app.routinesWith(exercise.id).length;
    final lost = [
      sets == 0
          ? 'No tiene series registradas.'
          : 'Se borrarán también sus $sets ${plural(sets, 'serie registrada', 'series registradas')}.',
      if (routines > 0)
        'Se quitará de $routines ${plural(routines, 'rutina', 'rutinas')}.',
      'No se puede deshacer.',
    ].join(' ');
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.alertSoft(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF5A3A32)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Eliminar «${exercise.name}»?',
              style: AppText.body(15, weight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              lost,
              style: AppText.body(
                13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancelar',
                    height: 44,
                    fontSize: 15,
                    radius: 12,
                    onTap: onCancel,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Pressable(
                    onTap: onDelete,
                    color: AppColors.alert,
                    radius: 12,
                    height: 44,
                    child: Center(
                      child: Text(
                        'Eliminar',
                        style: AppText.body(
                          15,
                          weight: FontWeight.w700,
                          color: AppColors.background,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      radius: 16,
      borderWidth: 1.5,
      selected: selected,
      color: selected ? AppColors.accentSoft(0.08) : AppColors.surface,
      borderColor: selected ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.accent : AppColors.ring,
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.accent : Colors.transparent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(16, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.body(13, color: AppColors.textSecondary),
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

/// Tipo de registro de un ejercicio ya creado: visible pero bloqueado, sin
/// interacción (las series ya registradas se leen según él).
class _LockedKind extends StatelessWidget {
  const _LockedKind({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. Bloqueado: no se puede cambiar.',
      excludeSemantics: true,
      child: EmptyBox(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.lock,
              size: 22,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body(
                      16,
                      weight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No se puede cambiar: tus series se registraron así.',
                    style: AppText.body(13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'BLOQUEADO',
                style: AppText.label(size: 10, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Campo de nombre grande (Barlow Condensed 30) de los formularios.
class BigTextField extends StatelessWidget {
  const BigTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.error = false,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool error;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textCapitalization: TextCapitalization.sentences,
      // Mismo tope que la base de datos (supabase/migrations).
      inputFormatters: [LengthLimitingTextInputFormatter(80)],
      style: AppText.display(30, weight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.display(
          30,
          weight: FontWeight.w700,
          color: AppColors.textDisabled,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        enabledBorder: border(error ? AppColors.error : AppColors.borderStrong),
        focusedBorder: border(
          error ? AppColors.error : AppColors.textSecondary,
        ),
      ),
    );
  }
}
