import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/security/recovery_codes.dart';

void main() {
  // Wenige Runden: Der Test prüft die Logik, nicht die Rechenzeit.
  const rounds = 50;

  ({RecoveryCodes stored, List<String> plain}) make({int count = 5}) =>
      RecoveryCodes.generate(
        count: count,
        iterations: rounds,
        random: Random(42),
      );

  group('Wiederherstellungs-Codes', () {
    test('erzeugt genau so viele verschiedene Codes wie verlangt', () {
      final generated = make(count: 8);

      expect(generated.plain, hasLength(8));
      expect(generated.plain.toSet(), hasLength(8));
      expect(generated.stored.remaining, 8);
    });

    test('speichert den Code nirgends im Klartext', () {
      final generated = make();

      for (final code in generated.plain) {
        expect(generated.stored.hashes, isNot(contains(code)));
        expect(generated.stored.toJson().toString(), isNot(contains(code)));
      }
    });

    test('verwechselbare Zeichen kommen nicht vor', () {
      // O/0, I/1 und S/5 sind beim Abschreiben nicht auseinanderzuhalten.
      final generated = make(count: 20);

      for (final code in generated.plain) {
        expect(code, isNot(matches(RegExp('[O0I1S5]'))));
      }
    });

    test('erkennt einen Code auch schludrig getippt', () {
      final generated = make();
      final code = generated.plain.first;

      expect(generated.stored.matches(code), isTrue);
      expect(generated.stored.matches(code.toLowerCase()), isTrue);
      expect(generated.stored.matches(code.replaceAll('-', '')), isTrue);
      expect(
        generated.stored.matches(' ${code.replaceAll('-', ' ')} '),
        isTrue,
      );
    });

    test('ein eingelöster Code gilt kein zweites Mal', () {
      final generated = make();
      final code = generated.plain.first;

      final left = generated.stored.consume(code);
      expect(left, isNotNull);
      expect(left!.remaining, generated.stored.remaining - 1);

      // Ein abfotografierter Zettel darf kein Dauerschlüssel sein.
      expect(left.matches(code), isFalse);
      expect(left.consume(code), isNull);
    });

    test('die übrigen Codes bleiben gültig', () {
      final generated = make();
      final left = generated.stored.consume(generated.plain.first)!;

      for (final code in generated.plain.skip(1)) {
        expect(left.matches(code), isTrue);
      }
    });

    test('ein falscher Code verbraucht nichts', () {
      final generated = make();

      expect(generated.stored.consume('AAAA-BBBB'), isNull);
      expect(generated.stored.remaining, 5);
    });

    test('übersteht das Speichern und Lesen', () {
      final generated = make();
      final restored = RecoveryCodes.fromJson(generated.stored.toJson());

      expect(restored.remaining, generated.stored.remaining);
      expect(restored.matches(generated.plain.last), isTrue);
    });
  });
}
