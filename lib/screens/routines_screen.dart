import 'package:flutter/material.dart';

import '../logic/format.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_icon.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'routine_editor_screen.dart';

/// 5 · Mis rutinas.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  String? _confirmDelete;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final routines = app.routinesByRecentUse(pinFirst: app.highlightId);
    final toast = app.toastFor(ToastTarget.routines);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(child: ScreenTitle('Mis rutinas')),
              const SizedBox(width: 12),
              HeaderActionPill(label: 'Nueva', filled: true, onTap: () => pushScreen(context, const RoutineEditorScreen())),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              if (toast != null) ...[ToastBanner(toast), const SizedBox(height: 12)],
              const SizedBox(height: 8),
              SectionLabel('${routines.length} ${plural(routines.length, 'rutina', 'rutinas')} · por uso reciente'),
              const SizedBox(height: 10),
              if (routines.isEmpty)
                const EmptyBox(child: EmptyText('Aún no tienes rutinas. Toca «Nueva» para armar la primera.', align: TextAlign.start)),
              for (final r in routines) ...[
                _RoutineCard(
                  routine: r,
                  highlighted: app.highlightId == r.id,
                  confirming: _confirmDelete == r.id,
                  onAskDelete: () => setState(() => _confirmDelete = r.id),
                  onCancelDelete: () => setState(() => _confirmDelete = null),
                  onDelete: () {
                    setState(() => _confirmDelete = null);
                    app.deleteRoutine(r.id);
                    app.flash('«${r.name}» eliminada.', ToastTarget.routines);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.highlighted,
    required this.confirming,
    required this.onAskDelete,
    required this.onCancelDelete,
    required this.onDelete,
  });

  final Routine routine;
  final bool highlighted;
  final bool confirming;
  final VoidCallback onAskDelete;
  final VoidCallback onCancelDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final r = routine;
    final last = app.routineLastUsed(r);
    final n = r.items.length;
    final meta = '$n ${plural(n, 'ejercicio', 'ejercicios')} · ${last == null ? 'aún no la usas' : 'última vez ${agoText(last, app.today)}'}';
    final exList = [for (final it in r.items) app.exercise(it.exerciseId)?.name ?? it.exerciseId].join(' · ');

    return SurfaceCard(
      radius: 20,
      borderWidth: 1.5,
      borderColor: highlighted ? AppColors.accent : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.name, style: AppText.display(27, weight: FontWeight.w700, height: 1.05)),
          const SizedBox(height: 3),
          Text(meta, style: AppText.body(13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          Text(exList, style: AppText.body(14, color: AppColors.textMuted, height: 1.4)),
          const SizedBox(height: 14),
          if (!confirming)
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Usar hoy',
                    icon: AppIcons.play,
                    height: 44,
                    fontSize: 15,
                    radius: 12,
                    color: AppColors.control,
                    onTap: () {
                      app.loadRoutine(r.id, app.today);
                      goToTab(context, AppTab.hoy);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                CircleIconButton(
                  icon: AppIcons.edit,
                  iconSize: 18,
                  radius: 12,
                  color: AppColors.control,
                  semanticLabel: 'Editar ${r.name}',
                  onTap: () => pushScreen(context, RoutineEditorScreen(routine: r)),
                ),
                const SizedBox(width: 8),
                CircleIconButton(
                  icon: AppIcons.trash,
                  iconSize: 18,
                  radius: 12,
                  color: AppColors.control,
                  iconColor: AppColors.textMuted,
                  semanticLabel: 'Eliminar ${r.name}',
                  onTap: onAskDelete,
                ),
              ],
            )
          else
            Semantics(
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
                    Text('¿Eliminar «${r.name}»?', style: AppText.body(15, weight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Tus series registradas no se borran.', style: AppText.body(13, color: AppColors.textSecondary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(label: 'Cancelar', height: 44, fontSize: 15, radius: 12, onTap: onCancelDelete),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Pressable(
                            onTap: onDelete,
                            color: AppColors.alert,
                            radius: 12,
                            height: 44,
                            child: Center(child: Text('Eliminar', style: AppText.body(15, weight: FontWeight.w700, color: AppColors.background))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
