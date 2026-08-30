import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/calendar/date_text.dart';

void main() {
  group('Datum in Worten', () {
    test('nennt den Wochentag vor dem Datum', () {
      // Montag, 31.08.2026 – der Tag, an dem der Sonntag danebenlag.
      expect(DateText.date(DateTime(2026, 8, 31)), 'Mo, 31.08.2026');
      expect(DateText.date(DateTime(2026, 8, 30)), 'So, 30.08.2026');
    });

    test('schreibt Tag, Monat und Stunde zweistellig', () {
      expect(
        DateText.dateTime(DateTime(2026, 1, 5, 9, 5)),
        'Mo, 05.01.2026, 09:05 Uhr',
      );
    });

    test('kennt jeden Wochentag', () {
      // Montag, 24.08.2026, und die sechs Tage danach.
      const erwartet = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
      for (var i = 0; i < erwartet.length; i++) {
        expect(DateText.weekday(DateTime(2026, 8, 24 + i)), erwartet[i]);
      }
    });
  });
}
