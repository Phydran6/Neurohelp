import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/features/home/domain/greetings.dart';

void main() {
  group('Sprüche', () {
    test('sind vorhanden und nicht leer', () {
      expect(Greetings.lines, isNotEmpty);
      for (final line in Greetings.lines) {
        expect(line.trim(), isNotEmpty);
      }
    });

    test('fordern nichts und bewerten nicht', () {
      // Konzept, Abschnitt 4: kein Zwang, keine Leistungssprache.
      const verboten = [
        'musst',
        'solltest',
        'endlich',
        'schaffst du',
        'streak',
        'ziel erreicht',
        'gut gemacht',
        'weiter so',
      ];

      for (final line in Greetings.lines) {
        final klein = line.toLowerCase();
        for (final wort in verboten) {
          expect(
            klein.contains(wort),
            isFalse,
            reason: '„$line" enthält „$wort"',
          );
        }
      }
    });
  });

  group('Auswahl', () {
    test('ist innerhalb eines Tages stabil', () {
      final morgens = DateTime(2026, 8, 9, 7);
      final abends = DateTime(2026, 8, 9, 22);

      expect(Greetings.forDate(morgens), Greetings.forDate(abends));
    });

    test('wechselt von Tag zu Tag', () {
      final tage = List.generate(
        Greetings.lines.length,
        (i) => Greetings.forDate(DateTime(2026, 8, 9 + i)),
      );

      expect(tage.toSet(), hasLength(Greetings.lines.length));
    });

    test('kommt mit negativen und großen Seeds klar', () {
      expect(Greetings.forSeed(-1), isNotEmpty);
      expect(Greetings.forSeed(0), isNotEmpty);
      expect(Greetings.forSeed(999999), isNotEmpty);
    });
  });
}
