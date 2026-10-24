import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';

/// Superficie pulsable con borde y esquinas redondeadas; base de casi todos los botones.
class Pressable extends StatelessWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.color = AppColors.surface,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 16,
    this.height,
    this.width,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
    this.selected,
    this.alignment,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;
  final bool? selected;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor!, width: borderWidth),
    );
    Widget content = Padding(padding: padding, child: child);
    if (alignment != null) {
      content = Align(alignment: alignment!, child: content);
    }
    return Semantics(
      button: true,
      label: semanticLabel,
      selected: selected,
      excludeSemantics: semanticLabel != null,
      child: SizedBox(
        height: height,
        width: width,
        child: Material(
          color: color,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

/// Botón principal: fondo acento y texto oscuro.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.trailingIcon,
    this.height = 58,
    this.fontSize = 17,
    this.radius = 16,
  });

  final String label;
  final VoidCallback? onTap;
  final AppIcons? icon;
  final AppIcons? trailingIcon;
  final double height;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: AppColors.accent,
      radius: radius,
      height: height,
      width: double.infinity,
      child: _IconLabel(
        label: label,
        icon: icon,
        trailingIcon: trailingIcon,
        color: AppColors.background,
        fontSize: fontSize,
        weight: FontWeight.w700,
        iconStroke: 2.8,
      ),
    );
  }
}

/// Botón secundario: superficie con borde.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.trailingIcon,
    this.height = 52,
    this.fontSize = 16,
    this.color = AppColors.surface,
    this.radius = 16,
    this.weight = FontWeight.w600,
    this.iconColor = AppColors.accent,
  });

  final String label;
  final VoidCallback? onTap;
  final AppIcons? icon;
  final AppIcons? trailingIcon;
  final double height;
  final double fontSize;
  final Color color;
  final double radius;
  final FontWeight weight;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      color: color,
      borderColor: AppColors.borderStrong,
      radius: radius,
      height: height,
      width: double.infinity,
      child: _IconLabel(
        label: label,
        icon: icon,
        iconColor: iconColor,
        trailingIcon: trailingIcon,
        color: AppColors.text,
        fontSize: fontSize,
        weight: weight,
      ),
    );
  }
}

/// «+ Agregar ejercicio» con borde punteado del color de acento.
class DashedAddButton extends StatelessWidget {
  const DashedAddButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashedBorder(
      color: AppColors.accent,
      strokeWidth: 1.5,
      radius: 16,
      child: Pressable(
        onTap: onTap,
        color: Colors.transparent,
        radius: 16,
        height: 54,
        width: double.infinity,
        child: _IconLabel(
          label: label,
          icon: AppIcons.plus,
          color: AppColors.accent,
          fontSize: 16,
          weight: FontWeight.w700,
          iconStroke: 2.6,
        ),
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  const _IconLabel({
    required this.label,
    required this.color,
    required this.fontSize,
    required this.weight,
    this.icon,
    this.iconColor,
    this.trailingIcon,
    this.iconStroke = 2.2,
  });

  final String label;
  final Color color;
  final double fontSize;
  final FontWeight weight;
  final AppIcons? icon;
  final Color? iconColor;
  final AppIcons? trailingIcon;
  final double iconStroke;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          AppIcon(icon!, color: iconColor ?? color, strokeWidth: iconStroke),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            style: AppText.body(fontSize, weight: weight, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: 10),
          AppIcon(trailingIcon!, color: color, strokeWidth: 2.4),
        ],
      ],
    );
  }
}

/// Botón «‹ Volver» en forma de píldora.
class BackPill extends StatelessWidget {
  const BackPill({
    super.key,
    required this.label,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      radius: 99,
      height: 44,
      borderColor: AppColors.borderStrong,
      padding: const EdgeInsets.only(left: 8, right: 14),
      semanticLabel: semanticLabel ?? label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.chevronLeft, size: 22, color: AppColors.text),
          const SizedBox(width: 4),
          Text(label, style: AppText.body(15, weight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Botón redondo de 44 px con un ícono.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 44,
    this.iconSize = 20,
    this.color = AppColors.surface,
    this.iconColor = AppColors.text,
    this.borderColor = AppColors.borderStrong,
    this.radius,
  });

  final AppIcons icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final double size;
  final double iconSize;
  final Color color;
  final Color iconColor;
  final Color? borderColor;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Pressable(
        onTap: onTap,
        color: color,
        borderColor: borderColor,
        radius: radius ?? size / 2,
        width: size,
        height: size,
        semanticLabel: semanticLabel,
        child: Center(
          child: AppIcon(
            icon,
            size: iconSize,
            color: iconColor,
            strokeWidth: 2.4,
          ),
        ),
      ),
    );
  }
}

/// Píldora «+ Crear» / «+ Nueva» de las cabeceras.
class HeaderActionPill extends StatelessWidget {
  const HeaderActionPill({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.background : AppColors.accent;
    return Pressable(
      onTap: onTap,
      radius: 99,
      height: 44,
      color: filled ? AppColors.accent : Colors.transparent,
      borderColor: filled ? null : AppColors.accent,
      borderWidth: 1.5,
      padding: const EdgeInsets.only(left: 12, right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(AppIcons.plus, size: 18, color: fg, strokeWidth: 2.8),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppText.body(15, weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de superficie.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.borderColor = AppColors.border,
    this.borderWidth = 1,
    this.color = AppColors.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color borderColor;
  final double borderWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );
  }
}

/// Recuadro punteado para estados vacíos.
class EmptyBox extends StatelessWidget {
  const EmptyBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DashedBorder(
      color: AppColors.dashed,
      radius: radius,
      child: Padding(
        padding: padding,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

/// Texto de estado vacío, gris y centrado.
class EmptyText extends StatelessWidget {
  const EmptyText(this.text, {super.key, this.align = TextAlign.center});
  final String text;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: AppText.body(15, color: AppColors.textSecondary, height: 1.4),
  );
}

/// Dibuja un borde punteado redondeado alrededor del hijo.
class DashedBorder extends StatelessWidget {
  const DashedBorder({
    super.key,
    required this.child,
    required this.color,
    this.strokeWidth = 1,
    this.radius = 16,
  });

  final Widget child;
  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(color, strokeWidth, radius),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(this.color, this.strokeWidth, this.radius);

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final source = Path()..addRRect(rrect);
    const dash = 6.0, gap = 4.0;
    for (final PathMetric m in source.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

/// Etiqueta de sección en mayúsculas.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    super.key,
    this.color = AppColors.textSecondary,
    this.size = 12,
  });
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text.toUpperCase(),
      style: AppText.label(size: size, color: color),
    ),
  );
}

/// Título grande en Barlow Condensed y mayúsculas.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.size = 44});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text.toUpperCase(), style: AppText.display(size, height: 1)),
  );
}

/// Chip de filtro (grupo muscular, tendencia).
class FilterChipButton extends StatelessWidget {
  const FilterChipButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 15,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      radius: 99,
      height: 40,
      selected: selected,
      color: selected ? AppColors.accent : Colors.transparent,
      borderColor: selected ? AppColors.accent : AppColors.dashed,
      borderWidth: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.body(
            fontSize,
            weight: FontWeight.w600,
            color: selected ? AppColors.background : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Fila horizontal desplazable de chips que llega a los bordes de la pantalla.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.semanticLabel});
  final List<Widget> children;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      container: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Barritas que cuentan series (18×5 px cada una).
class SetPills extends StatelessWidget {
  const SetPills({
    super.key,
    required this.count,
    this.alignment = WrapAlignment.start,
  });
  final int count;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: alignment,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 18,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      ),
    );
  }
}

/// Insignia «RÉCORD».
class RecordBadge extends StatelessWidget {
  const RecordBadge({
    super.key,
    this.height = 22,
    this.fontSize = 11,
    this.label = 'RÉCORD',
    this.outlined = false,
  });
  final double height;
  final double fontSize;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: outlined ? null : AppColors.accent,
        border: outlined
            ? Border.all(color: AppColors.accent, width: 1.5)
            : null,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.body(
            fontSize,
            weight: FontWeight.w800,
            color: outlined ? AppColors.text : AppColors.background,
            letterSpacing: fontSize * 0.08,
          ),
        ),
      ),
    );
  }
}

/// Aviso de confirmación con check («Rutina guardada…»).
class ToastBanner extends StatelessWidget {
  const ToastBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accentSoft(0.12),
          border: Border.all(color: AppColors.accent),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const AppIcon(
              AppIcons.check,
              color: AppColors.accent,
              strokeWidth: 2.6,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppText.body(15, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Píldora de grupo muscular junto al título («Pecho»).
class GroupTag extends StatelessWidget {
  const GroupTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: AppText.body(
            13,
            weight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Barra inferior fija con botón principal y error opcional (Crear rutina, Crear ejercicio).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.label,
    required this.onTap,
    this.error,
  });
  final String label;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: AppText.body(14, color: AppColors.error),
              ),
            ),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: label,
            onTap: onTap,
            height: 60,
            fontSize: 19,
            radius: 18,
          ),
        ],
      ),
    );
  }
}
