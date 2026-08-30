/// Datum und Uhrzeit so, wie man sie im Deutschen hinschreibt.
///
/// Der Wochentag steht bewusst davor. Im Kalenderblatt liegt der Sonntag
/// direkt neben dem Montag; ein Griff daneben fällt sonst erst am falschen
/// Tag auf. Steht „Mo, 31.08.2026" da, sieht man es sofort.
abstract final class DateText {
  static const List<String> _weekdays = [
    'Mo',
    'Di',
    'Mi',
    'Do',
    'Fr',
    'Sa',
    'So',
  ];

  /// Der abgekürzte Wochentag, z.B. `Mo`.
  static String weekday(DateTime value) => _weekdays[value.weekday - 1];

  /// Wochentag und Datum, z.B. `Mo, 31.08.2026`.
  static String date(DateTime value) =>
      '${weekday(value)}, ${_two(value.day)}.${_two(value.month)}.'
      '${value.year}';

  /// Wochentag, Datum und Uhrzeit, z.B. `Mo, 31.08.2026, 10:00 Uhr`.
  static String dateTime(DateTime value) =>
      '${date(value)}, ${_two(value.hour)}:${_two(value.minute)} Uhr';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
