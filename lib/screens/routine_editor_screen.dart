import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../data/catalog.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/routine_draft.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'library_screen.dart';
import 'new_exercise_screen.dart';

/// 4 · Crear / editar rutina.
class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key, this.routine, this.initialItems, this.returnToRoutines = false});

  /// La rutina a editar; null para crear una nueva.
  final Routine? routine;

  /// Ejercicios con los que arranca una rutina nueva («Guardar como rutina»).
  final List<RoutineItem>? initialItems;

  /// Al guardar, ir a la pestaña Rutinas (cuando se abre desde Hoy).
  final bool returnToRoutines;

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final RoutineDraft _draft = RoutineDraft(
    id: widget.routine?.id,
    name: widget.routine?.name ?? '',
    items: widget.routine?.items ?? widget.initialItems,
  );
  late final _name = TextEditingController(text: _draft.name);
  bool _saveError = false;

  @override
  void dispose() {
    _draft.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final app = AppScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty || _draft.items.isEmpty) {
      setState(() => _saveError = true);
      return;
    }
    final editing = _draft.id != null;
    final id = app.saveRoutine(id: _draft.id, name: name, items: _draft.items);
    app.flash(
      editing ? 'Cambios guardados en «$name».' : '«$name» guardada. Cárgala cuando quieras desde Hoy.',
      ToastTarget.routines,
      highlightId: id,
    );
    goToTab(context, AppTab.rutinas);
  }

  Widget _buildItem(AppState app, List<RoutineItem> items, int i, {double? dragLift}) {
    final ex = app.exercise(items[i].exerciseId);
    return _DraftItem(
      index: i,
      count: items.length,
      name: ex?.name ?? items[i].exerciseId,
      group: ex == null ? '' : groupLabel(ex.group),
      dragLift: dragLift,
      onRemove: () => _draft.removeAt(i),
      onMove: (to) => _draft.move(i, to),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _draft,
          builder: (context, _) {
            final items = _draft.items;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      BackPill(label: 'Cancelar', onTap: () => Navigator.pop(context)),
                      SectionLabel(_draft.id != null ? 'Editar rutina' : 'Nueva rutina', size: 13),
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionLabel('Nombre de la rutina'),
                              const SizedBox(height: 8),
                              BigTextField(
                                controller: _name,
                                hint: 'Ej. Brazos express',
                                error: _saveError && _name.text.trim().isEmpty,
                                onChanged: (v) {
                                  _draft.name = v;
                                  if (_saveError) setState(() => _saveError = false);
                                },
                              ),
                              const SizedBox(height: 18),
                              SectionLabel('Ejercicios · ${items.length}'),
                              const SizedBox(height: 12),
                              if (items.isEmpty) ...[
                                const EmptyBox(
                                  padding: EdgeInsets.all(22),
                                  child: EmptyText('Todavía no hay ejercicios. Agrégalos desde la biblioteca.'),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverReorderableList(
                          itemCount: items.length,
                          onReorder: (from, to) => _draft.move(from, to > from ? to - 1 : to),
                          proxyDecorator: (child, i, animation) => AnimatedBuilder(
                            animation: animation,
                            builder: (context, _) => Material(
                              color: Colors.transparent,
                              child: _buildItem(app, items, i, dragLift: animation.value),
                            ),
                          ),
                          itemBuilder: (context, i) => Padding(
                            key: ValueKey(items[i].exerciseId),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildItem(app, items, i),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                        sliver: SliverToBoxAdapter(
                          child: DashedAddButton(
                            label: 'Agregar ejercicios',
                            onTap: () => pushScreen(context, LibraryScreen(mode: LibraryMode.draft, draft: _draft)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                BottomActionBar(
                  label: 'Guardar rutina',
                  onTap: _save,
                  error: _saveError ? 'Ponle un nombre y agrega al menos un ejercicio.' : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DraftItem extends StatelessWidget {
  const _DraftItem({
    required this.index,
    required this.count,
    required this.name,
    required this.group,
    required this.onRemove,
    required this.onMove,
    this.dragLift,
  });

  final int index;
  final int count;
  final String name;
  final String group;
  final VoidCallback onRemove;
  final ValueChanged<int> onMove;

  /// Progreso (0–1) de la animación al levantar el elemento; null si no se arrastra.
  final double? dragLift;

  @override
  Widget build(BuildContext context) {
    final dragging = dragLift != null;
    return Container(
      height: 70,
      padding: const EdgeInsets.only(left: 4, right: 6),
      decoration: BoxDecoration(
        color: dragging ? AppColors.surfaceDragged : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dragging ? AppColors.accent : AppColors.border),
        boxShadow: dragging
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.55 * dragLift!), blurRadius: 30, offset: const Offset(0, 14))]
            : null,
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Mover $name, posición ${index + 1} de $count. Mantén presionado y arrastra',
            customSemanticsActions: {
              if (index > 0) const CustomSemanticsAction(label: 'Subir'): () => onMove(index - 1),
              if (index < count - 1) const CustomSemanticsAction(label: 'Bajar'): () => onMove(index + 1),
            },
            child: ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: AppIcon(AppIcons.dragHandle, size: 22, color: dragging ? AppColors.accent : AppColors.textSecondary, strokeWidth: 2.4)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text((index + 1).toString().padLeft(2, '0'), style: AppText.display(26, color: AppColors.accent)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(17, weight: FontWeight.w600, height: 1.2)),
                Text(group, style: AppText.body(13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          CircleIconButton(
            icon: AppIcons.close,
            semanticLabel: 'Quitar $name',
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
