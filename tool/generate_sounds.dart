// Genera los avisos sonoros del temporizador de Intervalos en assets/sounds/.
//
//   dart run tool/generate_sounds.dart
//
// Tonos simples (onda senoidal, 44,1 kHz, 16 bits, mono) con entrada y salida
// suaves para que no chasqueen:
// - tick: cuenta regresiva de los últimos 3 segundos.
// - work: empieza el trabajo (agudo y largo).
// - rest: empieza el descanso o el cambio de lado (grave).
// - done: terminó la sesión (tres notas que suben).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const _rate = 44100;

/// Un tono: frecuencia en Hz y duración en milisegundos (0 Hz = silencio).
typedef _Note = (double hz, int ms);

Int16List _render(List<_Note> notes, {double volume = 0.8}) {
  final samples = <int>[];
  for (final (hz, ms) in notes) {
    final n = _rate * ms ~/ 1000;
    final fade = math.min(n ~/ 4, _rate * 8 ~/ 1000);
    for (var i = 0; i < n; i++) {
      var amp = hz == 0 ? 0.0 : volume;
      if (i < fade) amp *= i / fade;
      if (i > n - fade) amp *= (n - i) / fade;
      final v = amp * math.sin(2 * math.pi * hz * i / _rate);
      samples.add((v * 32767).round());
    }
  }
  return Int16List.fromList(samples);
}

Uint8List _wav(Int16List pcm) {
  final data = pcm.buffer.asUint8List();
  final b = BytesBuilder();
  void str(String s) => b.add(s.codeUnits);
  void u32(int v) =>
      b.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      b.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));
  str('RIFF');
  u32(36 + data.length);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1); // PCM
  u16(1); // mono
  u32(_rate);
  u32(_rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(data.length);
  b.add(data);
  return b.toBytes();
}

void main() {
  final sounds = <String, List<_Note>>{
    'tick': [(1000, 90)],
    'work': [(1320, 140), (0, 60), (1320, 420)],
    'rest': [(660, 450)],
    'done': [(880, 160), (1100, 160), (1320, 420)],
  };
  Directory('assets/sounds').createSync(recursive: true);
  for (final MapEntry(key: name, value: notes) in sounds.entries) {
    File('assets/sounds/$name.wav').writeAsBytesSync(_wav(_render(notes)));
    stdout.writeln('assets/sounds/$name.wav');
  }
}
