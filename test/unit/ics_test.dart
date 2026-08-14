import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/calendar/calendar_service.dart';
import 'package:neurohelp/core/calendar/ics.dart';

void main() {
  final event = CalendarEvent(
    title: 'Sehtest beim Optiker',
    start: DateTime.utc(2026, 9, 3, 10, 30),
    end: DateTime.utc(2026, 9, 3, 11),
    location: 'Optik Meyer, Hauptstr. 5',
    description: 'Mitnehmen: Versichertenkarte, alte Brille',
  );

  group('ICS-Export', () {
    test('erzeugt einen vollständigen Kalendereintrag', () {
      final ics = IcsExporter.export(event, uid: 'test@neurohelp');

      expect(ics, contains('BEGIN:VCALENDAR'));
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('UID:test@neurohelp'));
      expect(ics, contains('DTSTART:20260903T103000Z'));
      expect(ics, contains('DTEND:20260903T110000Z'));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('maskiert Kommas, sonst zerreißt die Zeile', () {
      final ics = IcsExporter.export(event, uid: 'test@neurohelp');

      expect(ics, contains(r'LOCATION:Optik Meyer\, Hauptstr. 5'));
    });

    test('nutzt CRLF, wie RFC 5545 es verlangt', () {
      final ics = IcsExporter.export(event, uid: 'test@neurohelp');

      expect(ics, contains('\r\n'));
      // Kein nacktes LF: Manche Kalender lesen die Datei sonst gar nicht.
      expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('bricht zu lange Zeilen um', () {
      final long = IcsExporter.export(
        CalendarEvent(title: 'x' * 200, start: event.start, end: event.end),
        uid: 'test@neurohelp',
      );

      for (final line in long.split('\r\n')) {
        expect(line.length, lessThanOrEqualTo(76));
      }
    });

    test('lässt Felder weg, die es nicht gibt', () {
      final bare = IcsExporter.export(
        CalendarEvent(title: 'Termin', start: event.start, end: event.end),
        uid: 'test@neurohelp',
      );

      expect(bare, isNot(contains('LOCATION:')));
      expect(bare, isNot(contains('DESCRIPTION:')));
    });
  });
}
