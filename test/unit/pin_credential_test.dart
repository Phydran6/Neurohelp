import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/security/pin_credential.dart';

void main() {
  // Niedrige Rundenzahl, damit die Tests schnell bleiben. Produktiv gilt
  // PinCredential.defaultIterations.
  const iterations = 100;

  group('Anlegen', () {
    test('speichert die PIN nicht im Klartext', () {
      final credential = PinCredential.fromPin('1234', iterations: iterations);

      expect(credential.hash, isNot(contains('1234')));
      expect(credential.salt, isNotEmpty);
      expect(credential.iterations, iterations);
    });

    test('gleiche PIN ergibt bei neuem Salt einen anderen Hash', () {
      final a = PinCredential.fromPin('1234', iterations: iterations);
      final b = PinCredential.fromPin('1234', iterations: iterations);

      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
    });

    test('weist zu kurze PINs ab', () {
      expect(
        () => PinCredential.fromPin('12', iterations: iterations),
        throwsArgumentError,
      );
      expect(
        () => PinCredential.fromPin('   ', iterations: iterations),
        throwsArgumentError,
      );
    });
  });

  group('Prüfen', () {
    test('erkennt die richtige PIN', () {
      final credential = PinCredential.fromPin('4711', iterations: iterations);

      expect(credential.matches('4711'), isTrue);
      expect(credential.matches('4712'), isFalse);
      expect(credential.matches(''), isFalse);
    });

    test('überlebt eine Speicher-Runde', () {
      final original = PinCredential.fromPin(
        'geheim123',
        iterations: iterations,
      );
      final restored = PinCredential.fromJson(original.toJson());

      expect(restored.matches('geheim123'), isTrue);
      expect(restored.matches('geheim124'), isFalse);
    });
  });
}
