import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Íconos de trazo del diseño (viewBox 24×24). Cada valor es el contenido del `<svg>`.
enum AppIcons {
  calendar(
    '<rect x="3.5" y="5" width="17" height="15" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
  ),
  plus('<path d="M12 5v14M5 12h14"/>'),
  minus('<path d="M5 12h14"/>'),
  routine(
    '<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M8 9h8M8 12.5h8M8 16h5"/>',
  ),
  chevronRight('<path d="M9 6l6 6-6 6"/>'),
  chevronLeft('<path d="M15 18l-6-6 6-6"/>'),
  close('<path d="M6 6l12 12M18 6L6 18"/>'),
  bookmark('<path d="M6 4h12v16l-6-4-6 4z"/>'),
  repeat(
    '<path d="M4 12a8 8 0 0 1 14-5.3L20 9M20 4v5h-5M20 12a8 8 0 0 1-14 5.3L4 15M4 20v-5h5"/>',
  ),
  arrowRight('<path d="M5 12h14M13 6l6 6-6 6"/>'),
  arrowUp('<path d="M12 19V5M6 11l6-6 6 6"/>'),
  arrowDown('<path d="M12 5v14M6 13l6 6 6-6"/>'),
  equal('<path d="M6 9.5h12M6 14.5h12"/>'),
  info('<path d="M12 7v6M12 17v.5"/>'),
  check('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  trophy(
    '<path d="M8 4h8v5a4 4 0 0 1-8 0zM8 6H5a3 3 0 0 0 3 4M16 6h3a3 3 0 0 1-3 4M12 13v4M9 20h6M10 17h4"/>',
  ),
  chart('<path d="M4 19h16M5 15l5-5 3 3 6-7"/>'),
  search('<circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/>'),
  dragHandle('<path d="M5 7.5h14M5 12h14M5 16.5h14"/>'),
  play('<path d="M7 5l12 7-12 7z"/>'),
  edit('<path d="M4 20h4L18.5 9.5a2.1 2.1 0 0 0-4-4L4 16v4z"/>'),
  trash(
    '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12M9 7V4h6v3"/>',
  ),
  list('<path d="M9 6h11M9 12h11M9 18h11M4 6h1M4 12h1M4 18h1"/>'),
  lock(
    '<rect x="5" y="11" width="14" height="9.5" rx="2.5"/><path d="M8.5 11V8a3.5 3.5 0 0 1 7 0v3"/>',
  ),
  dumbbell('<path d="M6.5 6.5v11M17.5 6.5v11M3.5 9v6M20.5 9v6M6.5 12h11"/>'),
  // Cuenta y sincronización (no están en el diseño; mismo estilo de trazo).
  user(
    '<circle cx="12" cy="8" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>',
  ),
  cloud(
    '<path d="M7 18.5h10.5a4 4 0 0 0 .6-7.96A6 6 0 0 0 6.6 9.1 4.75 4.75 0 0 0 7 18.5z"/>',
  ),
  cloudOff(
    '<path d="M7 18.5h10.5a4 4 0 0 0 .6-7.96A6 6 0 0 0 6.6 9.1 4.75 4.75 0 0 0 7 18.5zM3.5 3.5l17 17"/>',
  ),
  eye(
    '<path d="M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12z"/><circle cx="12" cy="12" r="3"/>',
  ),
  eyeOff(
    '<path d="M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12zM4 4l16 16"/>',
  ),
  logOut(
    '<path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4M15 16l4-4-4-4M19 12H9"/>',
  ),
  // Intervalos (no están en el diseño; mismo estilo de trazo).
  timer(
    '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 9.5v4l2.5 2M10 2.5h4M18.5 7l1.5-1.5"/>',
  ),
  pause('<path d="M8.5 5v14M15.5 5v14"/>'),
  skip('<path d="M6 5.5l9 6.5-9 6.5zM18.5 5.5v13"/>'),
  stop('<rect x="6" y="6" width="12" height="12" rx="2"/>');

  const AppIcons(this.markup);
  final String markup;
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.strokeWidth = 2.2,
  });

  final AppIcons icon;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.white;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" '
        'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">${icon.markup}</svg>';
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// Logo de Temple: yunque con chispa (relleno, viewBox 64×64).
class TempleLogo extends StatelessWidget {
  const TempleLogo({super.key, this.size = 26, this.color});

  final double size;
  final Color? color;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" fill="#FFFFFF">'
      '<path d="M5 17.5C10 15.5 15 15 20 15H58V25H46C41.5 25 39 28 39 32.5V39H47V48H17V39H25V32.5C25 28 22.5 25 18 25H15C10 25 6.5 22 5 17.5Z"/>'
      '<path d="M50 2.5l1.6 3.4 3.4 1.6-3.4 1.6L50 12.5l-1.6-3.4-3.4-1.6 3.4-1.6z"/></svg>';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? Theme.of(context).colorScheme.primary,
        BlendMode.srcIn,
      ),
      semanticsLabel: 'Temple',
    );
  }
}
