import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/account_repository.dart';

/// Codes aus Supabase-Mails: Die Länge stellt das Projekt ein (6 bis 10).
void main() {
  test('nimmt sechs- und achtstellige Codes an', () {
    expect(EmailCode.looksComplete('123456'), isTrue);
    expect(EmailCode.looksComplete('12345678'), isTrue);
  });

  test('zu kurz ist nicht fertig', () {
    expect(EmailCode.looksComplete('12345'), isFalse);
  });

  test('Leerzeichen aus der Mail zählen nicht mit', () {
    expect(EmailCode.normalize(' 1234 5678 '), '12345678');
    expect(EmailCode.looksComplete('123 45'), isFalse);
  });

  test('das Feld lässt alle erlaubten Längen zu', () {
    expect(EmailCode.maxLength, greaterThanOrEqualTo(10));
  });
}
