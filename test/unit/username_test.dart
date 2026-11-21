import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/account_repository.dart';
import 'package:neurohelp/core/account/data/unconfigured_account_repository.dart';

/// **Anlass:** Eine Mail-Adresse als Benutzername ging bis zum Server durch
/// und kam dort als unverständlicher Backend-Fehler zurück. Die App kennt
/// die Regel der Datenbank jetzt selbst.
void main() {
  group('Username.problem', () {
    test('ein schlichter Name passt', () {
      expect(Username.problem('philipp'), isNull);
      expect(Username.problem('max_mustermann.2-b'), isNull);
    });

    test('eine Mail-Adresse wird abgelehnt', () {
      expect(Username.problem('philipp@example.test'), contains('E-Mail'));
      expect(
        Username.problem('philipp@', whileTyping: true),
        contains('E-Mail'),
      );
    });

    test('Leerzeichen und Umlaute gehen nicht – wie in der Datenbank', () {
      expect(Username.problem('max muster'), contains('Leerzeichen'));
      expect(Username.problem('jürgen'), isNotNull);
    });

    test('Länge wie in der Datenbank: 3 bis 32 Zeichen', () {
      expect(Username.problem('ab'), contains('mindestens'));
      expect(Username.problem('a' * 33), contains('höchstens'));
      expect(Username.problem('a' * 32), isNull);
    });

    test('beim Tippen bleibt ein noch kurzer Name ohne Hinweis', () {
      expect(Username.problem('', whileTyping: true), isNull);
      expect(Username.problem('p', whileTyping: true), isNull);
    });
  });

  test('die Registrierung lehnt eine Mail als Benutzername ab', () async {
    final account = LocalAccountRepository();

    await expectLater(
      account.signUp(
        username: 'philipp@example.test',
        email: 'philipp@example.test',
        password: 'geheim1234',
      ),
      throwsA(
        isA<AccountException>().having(
          (e) => e.failure,
          'failure',
          AccountFailure.invalidInput,
        ),
      ),
    );
  });
}
