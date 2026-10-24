import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Barlow en los tests para que el texto mida lo mismo que en el teléfono
/// (por defecto `flutter test` usa una fuente de cuadrados mucho más ancha).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Barlow', ['Barlow-Regular.ttf', 'Barlow-Medium.ttf', 'Barlow-SemiBold.ttf', 'Barlow-Bold.ttf', 'Barlow-ExtraBold.ttf']);
  await load('BarlowCondensed', ['BarlowCondensed-SemiBold.ttf', 'BarlowCondensed-Bold.ttf', 'BarlowCondensed-ExtraBold.ttf']);
  await testMain();
}
