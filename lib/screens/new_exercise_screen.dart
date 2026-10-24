import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ui.dart';

/// 6 · Crear ejercicio. Devuelve el [Exercise] creado al cerrar.
class NewExerciseScreen extends StatefulWidget {
  const NewExerciseScreen({super.key, this.initialName = '', this.initialGroup, this.saveLabel = 'Guardar ejercicio'});

  final String initialName;
  final String? initialGroup;
  final String saveLabel;

  @override
  State<NewExerciseScreen> createState() => _NewExerciseScreenState();
}

class _NewExerciseScreenState extends State<NewExerciseScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late String? _group = widget.initialGroup;
  ExerciseKind _kind = ExerciseKind.weight;
  String? _error;

  static const _kinds = [
    (ExerciseKind.weight, 'Repeticiones y peso', 'Ej. press, sentadilla, curl'),
    (ExerciseKind.reps, 'Solo repeticiones', 'Ej. dominadas, flexiones, fondos'),
    (ExerciseKind.seconds, 'Tiempo (segundos)', 'Ej. plancha, sentadilla isométrica'),
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
    } else if (app.exerciseNameExists(name)) {
      error = 'Ya tienes un ejercicio con ese nombre.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context, app.createExercise(name: name, group: _group!, kind: _kind));
  }

  @override
  Widget build(BuildContext context) {
    final nameError = _error != null && _name.text.trim().isEmpty;
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
                  BackPill(label: 'Cancelar', onTap: () => Navigator.pop(context)),
                  const SectionLabel('Nuevo ejercicio', size: 13),
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
                    autofocus: widget.initialName.isEmpty,
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
                          color: _group == g.id ? AppColors.accent : AppColors.surface,
                          borderColor: _group == g.id ? AppColors.accent : AppColors.borderStrong,
                          child: Center(
                            child: Text(
                              g.label,
                              style: AppText.body(15, weight: FontWeight.w600, color: _group == g.id ? AppColors.background : AppColors.text),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Qué vas a registrar'),
                  const SizedBox(height: 8),
                  for (final (kind, title, sub) in _kinds) ...[
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
                  ],
                ],
              ),
            ),
            BottomActionBar(label: widget.saveLabel, onTap: _save, error: _error),
          ],
        ),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({required this.title, required this.subtitle, required this.selected, required this.onTap});
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
                border: Border.all(color: selected ? AppColors.accent : AppColors.ring, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? AppColors.accent : Colors.transparent),
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
                  Text(subtitle, style: AppText.body(13, color: AppColors.textSecondary)),
                ],
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
  const BigTextField({super.key, required this.controller, required this.hint, this.error = false, this.onChanged, this.autofocus = false});

  final TextEditingController controller;
  final String hint;
  final bool error;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c, width: 1.5));
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
        hintStyle: AppText.display(30, weight: FontWeight.w700, color: AppColors.textDisabled),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: border(error ? AppColors.error : AppColors.borderStrong),
        focusedBorder: border(error ? AppColors.error : AppColors.textSecondary),
      ),
    );
  }
}
