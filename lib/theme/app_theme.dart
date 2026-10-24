import 'package:flutter/material.dart';

/// Paleta de Temple (ver tablero «Marca» en el diseño).
class AppColors {
  AppColors._();

  static const accent = Color(0xFF2EE6D6);
  static const alert = Color(0xFFFF8A6B);
  static const error = Color(0xFFFF9B8A);

  static const background = Color(0xFF0D0E10);
  static const navBackground = Color(0xFF0F1013);
  static const sheet = Color(0xFF121316);
  static const surface = Color(0xFF16181C);
  static const surfaceDragged = Color(0xFF1D2025);
  static const surfaceRaised = Color(0xFF1F2228);
  static const control = Color(0xFF22252B);
  static const pill = Color(0xFF2A2E35);

  static const line = Color(0xFF1F2228);
  static const border = Color(0xFF23262C);
  static const borderStrong = Color(0xFF2C3038);
  static const dashed = Color(0xFF343840);
  static const handle = Color(0xFF3A3F47);
  static const ring = Color(0xFF4A4F57);

  static const text = Color(0xFFF3F4F6);
  static const textSoft = Color(0xFFE4E6EA);
  static const textMuted = Color(0xFFC9CDD2);
  static const textSecondary = Color(0xFF9BA1AA);
  static const textFaint = Color(0xFF7C828B);
  static const textDisabled = Color(0xFF5E646D);

  /// El acento con transparencia, como `soft(accent, a)` del diseño.
  static Color accentSoft(double alpha) => accent.withValues(alpha: alpha);
  static Color alertSoft(double alpha) => alert.withValues(alpha: alpha);
}

/// Estilos de texto. Barlow Condensed para números y títulos, Barlow para el resto.
class AppText {
  AppText._();

  static const bodyFamily = 'Barlow';
  static const displayFamily = 'BarlowCondensed';

  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.text,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: bodyFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Etiqueta en mayúsculas con tracking amplio («SERIES», «LA ÚLTIMA VEZ»…).
  static TextStyle label({
    double size = 12,
    Color color = AppColors.textSecondary,
    FontWeight weight = FontWeight.w700,
    double tracking = 0.12,
  }) {
    return body(
      size,
      weight: weight,
      color: color,
      letterSpacing: size * tracking,
    );
  }
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: AppText.bodyFamily,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.background,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accentSoft(0.35),
      selectionHandleColor: AppColors.accent,
    ),
  );
}
