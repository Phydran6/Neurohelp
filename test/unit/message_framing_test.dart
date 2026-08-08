import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/features/messages/domain/message_framing.dart';

void main() {
  group('Rahmen setzen', () {
    test('ergänzt Anrede und Grußformel', () {
      final text = MessageFraming.wrap(
        'Ich brauche eine neue Versichertenkarte.',
        senderName: 'Philipp Fischer',
      );

      expect(text, '''
Guten Tag,

Ich brauche eine neue Versichertenkarte.

Mit freundlichen Grüßen
Philipp Fischer''');
    });

    test('lässt den Namen weg, wenn keiner da ist', () {
      final text = MessageFraming.wrap('Kurze Frage.');

      expect(text.endsWith('Mit freundlichen Grüßen'), isTrue);
    });

    test('ist bei jedem Empfänger gleich', () {
      // Konzept, Abschnitt 10: ein einziger höflich-neutraler Standard.
      final a = MessageFraming.wrap('Text A');
      final b = MessageFraming.wrap('Text B');

      expect(a.split('\n').first, b.split('\n').first);
      expect(a.split('\n').last, b.split('\n').last);
    });

    test('doppelt den Rahmen nicht', () {
      const alreadyFramed = '''
Sehr geehrte Damen und Herren,

mein Anliegen.

Viele Grüße
Philipp''';

      expect(MessageFraming.wrap(alreadyFramed), alreadyFramed);
    });

    test('ergänzt nur, was fehlt', () {
      final onlySalutation = MessageFraming.wrap('Hallo,\n\nmein Anliegen.');

      expect(onlySalutation.startsWith('Hallo,'), isTrue);
      expect(onlySalutation.contains('Mit freundlichen Grüßen'), isTrue);
    });

    test('leerer Text bleibt leer', () {
      expect(MessageFraming.wrap('   '), '');
    });
  });

  group('Rahmen abziehen', () {
    test('liefert den reinen Inhalt zurück', () {
      const body = 'Ich brauche eine neue Versichertenkarte.';
      final framed = MessageFraming.wrap(body, senderName: 'Philipp');

      expect(MessageFraming.unwrap(framed), body);
    });

    test('behält mehrzeiligen Inhalt', () {
      const body = 'Erste Zeile.\nZweite Zeile.';
      final framed = MessageFraming.wrap(body);

      expect(MessageFraming.unwrap(framed), body);
    });
  });

  group('Erkennung', () {
    test('erkennt gängige Anreden und Grußformeln', () {
      expect(MessageFraming.hasSalutation('Sehr geehrte Frau Müller,'), isTrue);
      expect(MessageFraming.hasSalutation('Moin,'), isTrue);
      expect(MessageFraming.hasSalutation('Ich schreibe wegen…'), isFalse);

      expect(MessageFraming.hasClosing('Text\n\nViele Grüße'), isTrue);
      expect(MessageFraming.hasClosing('Nur Text'), isFalse);
    });
  });
}
