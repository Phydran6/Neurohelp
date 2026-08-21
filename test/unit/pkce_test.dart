import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/openrouter/pkce.dart';

/// PKCE ist der einzige Schutz davor, dass eine fremde App den Code aus dem
/// Rücksprung abfängt und gegen einen Schlüssel tauscht. Ein Fehler hier
/// fällt im Betrieb nicht auf – der Login funktioniert trotzdem.
void main() {
  group('PkcePair', () {
    test('die Challenge ist der base64url-Hash ohne Füllzeichen', () {
      const verifier = 'ein-fester-verifier-fuer-den-test';

      final expected = base64Url
          .encode(sha256.convert(utf8.encode(verifier)).bytes)
          .replaceAll('=', '');

      expect(PkcePair.challengeFor(verifier), expected);
      expect(PkcePair.challengeFor(verifier), isNot(contains('=')));
      expect(PkcePair.challengeFor(verifier), isNot(contains('+')));
      expect(PkcePair.challengeFor(verifier), isNot(contains('/')));
    });

    test('der Verifier hält die Längen- und Zeichenvorgaben ein', () {
      final pair = PkcePair.generate();

      // RFC 7636 erlaubt 43 bis 128 Zeichen.
      expect(pair.verifier.length, inInclusiveRange(43, 128));
      expect(pair.verifier, matches(RegExp(r'^[A-Za-z0-9\-._~]+$')));
      expect(pair.challenge, PkcePair.challengeFor(pair.verifier));
    });

    test('zwei Paare sind nicht gleich', () {
      final first = PkcePair.generate();
      final second = PkcePair.generate();

      expect(first.verifier, isNot(second.verifier));
    });

    test('bei fester Quelle ist das Ergebnis reproduzierbar', () {
      // Nur zur Absicherung des Aufbaus – im Betrieb kommt Random.secure.
      final a = PkcePair.generate(random: Random(7));
      final b = PkcePair.generate(random: Random(7));

      expect(a.verifier, b.verifier);
    });

    test('das Verfahren ist S256, nicht plain', () {
      expect(PkcePair.method, 'S256');
    });
  });
}
