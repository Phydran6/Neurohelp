import 'calendar_service.dart';

/// Erzeugt ICS-Dateien (RFC 5545).
///
/// Der Weg für alle, die keinen Kalenderzugriff geben wollen oder deren
/// Kalender die App nicht kennt. Ohne Kollisionsprüfung – die Datei weiß
/// nichts von anderen Terminen (Konzept, Abschnitt 8, Schritt 7).
abstract final class IcsExporter {
  /// Baut den Inhalt einer `.ics`-Datei für [event].
  ///
  /// [uid] und [stamp] sind überschreibbar, damit die Ausgabe testbar ist.
  static String export(CalendarEvent event, {String? uid, DateTime? stamp}) {
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Neurohelp//DE',
      'CALSCALE:GREGORIAN',
      'BEGIN:VEVENT',
      'UID:${uid ?? _uidFor(event)}',
      'DTSTAMP:${_utc(stamp ?? DateTime.now())}',
      'DTSTART:${_utc(event.start)}',
      'DTEND:${_utc(event.end)}',
      'SUMMARY:${_escape(event.title)}',
      if (event.location != null) 'LOCATION:${_escape(event.location!)}',
      if (event.description != null)
        'DESCRIPTION:${_escape(event.description!)}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];

    // RFC 5545 verlangt CRLF als Zeilenende.
    return lines.map(_fold).join('\r\n');
  }

  static String _uidFor(CalendarEvent event) =>
      '${event.start.microsecondsSinceEpoch}@neurohelp';

  /// Zeitstempel in UTC, im Basisformat ohne Trenner.
  static String _utc(DateTime value) {
    final utc = value.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${utc.year.toString().padLeft(4, '0')}'
        '${two(utc.month)}${two(utc.day)}'
        'T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  /// Sonderzeichen maskieren, sonst zerreißt ein Komma die Datei.
  static String _escape(String value) => value
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  /// Zeilen über 75 Oktetts werden umgebrochen, Fortsetzung mit Leerzeichen.
  static String _fold(String line) {
    if (line.length <= 75) return line;

    final buffer = StringBuffer(line.substring(0, 75));
    var rest = line.substring(75);

    while (rest.isNotEmpty) {
      final take = rest.length > 74 ? 74 : rest.length;
      buffer.write('\r\n ${rest.substring(0, take)}');
      rest = rest.substring(take);
    }
    return buffer.toString();
  }
}
