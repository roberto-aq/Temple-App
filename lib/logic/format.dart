import '../models/models.dart';

const monthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];
const monthsLong = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Indexados por `DateTime.weekday - 1` (lunes = 0).
const weekdaysLong = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const weekdaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const weekdaysLetter = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// La fecha sin hora.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Clave estable para guardar por día: `2026-10-23`.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Días enteros entre dos fechas (independiente de cambios de horario).
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Lunes de la semana de `d`.
DateTime weekStart(DateTime d) =>
    dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// Un decimal como máximo, con coma: 62.5 → «62,5», 60 → «60».
String fmtNum(num n) {
  final r = (n * 10).round() / 10;
  final s = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
  return s.replaceAll('.', ',');
}

/// Miles con punto: 12500 → «12.500».
String thousands(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Valores de métricas: miles con punto o un decimal.
String fmtVal(num v) => v.abs() >= 1000 ? thousands(v) : fmtNum(v);

String capitalize(String t) =>
    t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// «hoy», «ayer», «hace 3 días».
String agoText(DateTime date, DateTime today) {
  final d = daysBetween(date, today);
  if (d <= 0) return 'hoy';
  if (d == 1) return 'ayer';
  return 'hace $d días';
}

/// «23 oct».
String shortDate(DateTime d) => '${d.day} ${monthsShort[d.month - 1]}';

/// «Viernes 23 oct».
String longDate(DateTime d) =>
    '${weekdaysLong[d.weekday - 1]} ${d.day} ${monthsShort[d.month - 1]}';

String unitWord(Exercise ex) => ex.timed ? 'seg' : 'reps';

/// Resumen de series: «60 kg × 8, 8, 7» o «8 × 60 kg · 6 × 65 kg» o «15, 14 reps».
/// Por tiempo: «45, 40 seg», «20, 15 min» o «1 min 30 seg, 45 seg».
String setsText(Exercise ex, List<SetEntry> sets) {
  final reps = sets.map((s) => s.reps).join(', ');
  if (ex.weighted) {
    final weights = sets.map(weightText).toList();
    if (weights.every((w) => w == weights.first)) {
      return '${weights.first} × $reps';
    }
    return sets.map((s) => '${s.reps} × ${weightText(s)}').join(' · ');
  }
  if (ex.timed && sets.any((s) => s.reps >= 60)) {
    if (sets.every((s) => s.reps % 60 == 0)) {
      return '${sets.map((s) => s.reps ~/ 60).join(', ')} min';
    }
    return sets.map((s) => durationText(s.reps)).join(', ');
  }
  return '$reps ${unitWord(ex)}';
}

/// Una serie: «62,5 kg × 8», «12 reps» o «1 min 30 seg».
String setLabel(Exercise ex, SetEntry s) =>
    ex.weighted ? '${weightText(s)} × ${s.reps}' : amountText(ex, s.reps);

/// El peso de una serie en la unidad en que se anotó, sin unidad: «25».
String weightValue(SetEntry s) => fmtNum(s.unit.fromKg(s.kg ?? 0));

/// El peso de una serie con su unidad: «62,5 kg» o «25 lb».
String weightText(SetEntry s) => '${weightValue(s)} ${s.unit.symbol}';

/// Repeticiones o tiempo de una serie, sin el peso: «12 reps» o «20 min».
String amountText(Exercise ex, int reps) =>
    ex.timed ? durationText(reps) : '$reps reps';

/// Las partes de una serie para mostrarlas en grande con su unidad:
/// [(«12», «reps»)] o, por tiempo, [(«1», «min»), («30», «seg»)].
/// Con [long], las unidades de tiempo completas: «minuto», «segundos».
List<(String, String)> amountParts(Exercise ex, int reps, {bool long = false}) {
  if (!ex.timed) return [('$reps', 'reps')];
  final m = reps ~/ 60, s = reps % 60;
  return [
    if (m > 0) ('$m', long ? plural(m, 'minuto', 'minutos') : 'min'),
    if (s > 0 || m == 0)
      ('$s', long ? plural(s, 'segundo', 'segundos') : 'seg'),
  ];
}

/// Total de las series: «45 reps» o, por tiempo, «2 min 15 seg».
String setsTotal(Exercise ex, List<SetEntry> sets) {
  final total = sets.fold(0, (sum, s) => sum + s.reps);
  return ex.timed ? durationText(total) : '$total reps';
}

/// El total en cifra y unidad, para mostrarlo en grande: («45», «reps»),
/// («26», «min») o («26:30», «min»).
(String, String) setsTotalParts(Exercise ex, List<SetEntry> sets) {
  final total = sets.fold(0, (sum, s) => sum + s.reps);
  if (!ex.timed) return ('$total', 'reps');
  if (total < 60) return ('$total', 'seg');
  final m = total ~/ 60, s = total % 60;
  return s == 0 ? ('$m', 'min') : ('$m:${s.toString().padLeft(2, '0')}', 'min');
}

/// «45 seg», «2 min» o «2 min 15 seg».
String durationText(int seconds) {
  final m = seconds ~/ 60, s = seconds % 60;
  if (m == 0) return '$s seg';
  return s == 0 ? '$m min' : '$m min $s seg';
}

/// Para buscar sin acentos ni mayúsculas.
String normalize(String t) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñÁÀÄÂÉÈËÊÍÌÏÎÓÒÖÔÚÙÜÛÑ';
  const to = 'aaaaeeeeiiiioooouuuunAAAAEEEEIIIIOOOOUUUUN';
  final b = StringBuffer();
  for (final ch in t.trim().split('')) {
    final i = from.indexOf(ch);
    b.write(i == -1 ? ch : to[i]);
  }
  return b.toString().toLowerCase();
}

String plural(int n, String one, String many) => n == 1 ? one : many;
