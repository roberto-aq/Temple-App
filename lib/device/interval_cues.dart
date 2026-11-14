import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Avisos del temporizador de Intervalos: sonido y vibración al cambiar de
/// fase, y pantalla encendida mientras corre. Sirven para entrenar sin mirar
/// el teléfono (p. ej. corriendo con él en el bolsillo).
abstract class IntervalCues {
  /// Los que usa la app. Los tests lo reemplazan por unos silenciosos.
  static IntervalCues instance = DeviceCues();

  /// Carga los sonidos; se llama al abrir el temporizador.
  Future<void> prepare();

  /// Cuenta regresiva de los últimos 3 segundos.
  void tick();

  /// Empieza un trabajo.
  void work();

  /// Empieza un descanso o un cambio de lado.
  void rest();

  /// Terminó la sesión.
  void done();

  /// Mantiene la pantalla encendida (o deja que se apague).
  Future<void> keepAwake(bool on);
}

/// Sonidos de assets/sounds (ver tool/generate_sounds.dart), vibración del
/// teléfono y bloqueo de pantalla con wakelock_plus. Si algo falla (p. ej. el
/// teléfono no vibra), el temporizador sigue igual.
class DeviceCues implements IntervalCues {
  static const _vibrator = MethodChannel('temple/vibrate');
  static const _sounds = ['tick', 'work', 'rest', 'done'];

  /// Por el volumen multimedia y sin pedir el foco de audio: suenan encima de
  /// la música sin pausarla.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
  );

  final _players = <String, AudioPlayer>{};
  Future<void>? _loading;

  @override
  Future<void> prepare() => _loading ??= _load();

  Future<void> _load() async {
    for (final name in _sounds) {
      try {
        final p = AudioPlayer();
        await p.setAudioContext(_context);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource('sounds/$name.wav'));
        _players[name] = p;
      } catch (e) {
        debugPrint('Temple intervalos: sin sonido «$name»: $e');
      }
    }
  }

  void _play(String name) {
    final p = _players[name];
    if (p == null) return;
    unawaited(
      p.stop().then((_) => p.resume()).catchError((Object e) {
        debugPrint('Temple intervalos: $e');
      }),
    );
  }

  /// [pattern]: pausa, vibración, pausa, vibración… en milisegundos.
  void _vibrate(List<int> pattern) {
    unawaited(
      _vibrator
          .invokeMethod<void>('vibrate', {'pattern': pattern})
          .catchError((Object _) => HapticFeedback.heavyImpact()),
    );
  }

  @override
  void tick() {
    _play('tick');
    _vibrate(const [0, 60]);
  }

  @override
  void work() {
    _play('work');
    _vibrate(const [0, 450]);
  }

  @override
  void rest() {
    _play('rest');
    _vibrate(const [0, 200, 120, 200]);
  }

  @override
  void done() {
    _play('done');
    _vibrate(const [0, 300, 150, 300, 150, 600]);
  }

  @override
  Future<void> keepAwake(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (e) {
      debugPrint('Temple intervalos: pantalla encendida: $e');
    }
  }
}
