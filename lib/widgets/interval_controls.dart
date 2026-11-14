import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'ui.dart';

/// Un valor con botones − y + a los lados (tiempos, rondas, peso).
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.minusLabel,
    required this.plusLabel,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;

  /// null deshabilita el botón (en el mínimo o el máximo).
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String minusLabel;
  final String plusLabel;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppText.label()),
                const SizedBox(height: 2),
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          style: AppText.display(34, height: 1.1),
                        ),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 5),
                        Text(
                          unit!,
                          style: AppText.display(
                            17,
                            weight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          CircleIconButton(
            icon: AppIcons.minus,
            size: 48,
            radius: 14,
            color: AppColors.control,
            semanticLabel: minusLabel,
            onTap: onMinus,
          ),
          const SizedBox(width: 8),
          CircleIconButton(
            icon: AppIcons.plus,
            size: 48,
            radius: 14,
            color: AppColors.control,
            semanticLabel: plusLabel,
            onTap: onPlus,
          ),
        ],
      ),
    );
  }
}

/// Opción que se activa o desactiva, con título y explicación.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => onChanged(!value),
      radius: 18,
      borderWidth: 1.5,
      borderColor: value ? AppColors.accent : AppColors.border,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      selected: value,
      semanticLabel: '$title. $subtitle',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(17, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.body(
                    13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.background,
              activeTrackColor: AppColors.accent,
              inactiveThumbColor: AppColors.textSecondary,
              inactiveTrackColor: AppColors.control,
              trackOutlineColor: const WidgetStatePropertyAll(
                AppColors.borderStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recuadro «¿Eliminar…?» con Cancelar y el botón de confirmar en rojo.
class DangerConfirm extends StatelessWidget {
  const DangerConfirm({
    super.key,
    required this.title,
    required this.message,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel = 'Eliminar',
  });

  final String title;
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
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
            Text(title, style: AppText.body(15, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              message,
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
                    onTap: onConfirm,
                    color: AppColors.alert,
                    radius: 12,
                    height: 44,
                    child: Center(
                      child: Text(
                        confirmLabel,
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

/// Selector «KG | LB».
class UnitChoice<T> extends StatelessWidget {
  const UnitChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  /// Valor, texto y nombre para lectores de pantalla.
  final List<(T, String, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, (v, text, word)) in options.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Pressable(
              onTap: () => onChanged(v),
              radius: 12,
              height: 44,
              borderWidth: 1.5,
              selected: value == v,
              color: value == v ? AppColors.accent : AppColors.surface,
              borderColor: value == v
                  ? AppColors.accent
                  : AppColors.borderStrong,
              semanticLabel: 'Peso en $word',
              child: Center(
                child: Text(
                  text,
                  style: AppText.body(
                    15,
                    weight: FontWeight.w700,
                    color: value == v ? AppColors.background : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
