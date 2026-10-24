// Genera las imágenes fuente del ícono de la app en assets/icon/.
//
//   flutter test tool/generate_icons.dart
//   dart run flutter_launcher_icons
//
// El dibujo es el del tablero «Marca» del diseño: yunque con chispa en el
// color de acento sobre la superficie oscura, ocupando el 64 % del ícono.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _accent = ui.Color(0xFF2EE6D6);
const _surface = ui.Color(0xFF16181C);
const _white = ui.Color(0xFFFFFFFF);
const _size = 1024.0;

/// Logo en su viewBox de 64×64 (mismos trazos que TempleLogo).
ui.Path _logo() {
  final anvil = ui.Path()
    ..moveTo(5, 17.5)
    ..cubicTo(10, 15.5, 15, 15, 20, 15)
    ..lineTo(58, 15)
    ..lineTo(58, 25)
    ..lineTo(46, 25)
    ..cubicTo(41.5, 25, 39, 28, 39, 32.5)
    ..lineTo(39, 39)
    ..lineTo(47, 39)
    ..lineTo(47, 48)
    ..lineTo(17, 48)
    ..lineTo(17, 39)
    ..lineTo(25, 39)
    ..lineTo(25, 32.5)
    ..cubicTo(25, 28, 22.5, 25, 18, 25)
    ..lineTo(15, 25)
    ..cubicTo(10, 25, 6.5, 22, 5, 17.5)
    ..close();
  final spark = ui.Path()
    ..moveTo(50, 2.5)
    ..lineTo(51.6, 5.9)
    ..lineTo(55, 7.5)
    ..lineTo(51.6, 9.1)
    ..lineTo(50, 12.5)
    ..lineTo(48.4, 9.1)
    ..lineTo(45, 7.5)
    ..lineTo(48.4, 5.9)
    ..close();
  return ui.Path()
    ..addPath(anvil, ui.Offset.zero)
    ..addPath(spark, ui.Offset.zero);
}

/// Dibuja el logo centrado (por su contorno real) con [logoSize] px por viewBox.
Future<void> _write(
  String path, {
  required double logoSize,
  required ui.Color color,
  ui.Color? background,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (background != null) {
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, _size, _size),
      ui.Paint()..color = background,
    );
  }
  final logo = _logo();
  final bounds = logo.getBounds();
  final scale = logoSize / 64;
  canvas
    ..translate(_size / 2, _size / 2)
    ..scale(scale)
    ..translate(-bounds.center.dx, -bounds.center.dy)
    ..drawPath(
      logo,
      ui.Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  final image = await recorder.endRecording().toImage(
    _size.toInt(),
    _size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('genera assets/icon', () async {
    await TestWidgetsFlutterBinding.ensureInitialized().runAsync(() async {
      // Ícono completo (iOS, web, Windows, Android antiguo).
      await _write(
        'assets/icon/icon.png',
        logoSize: _size * 0.64,
        color: _accent,
        background: _surface,
      );
      // Android adaptativo: flutter_launcher_icons ya añade un inset del 16 %,
      // así que la capa usa la misma proporción que el ícono completo.
      await _write(
        'assets/icon/icon_foreground.png',
        logoSize: _size * 0.64,
        color: _accent,
      );
      await _write(
        'assets/icon/icon_monochrome.png',
        logoSize: _size * 0.64,
        color: _white,
      );
    });
  });
}
