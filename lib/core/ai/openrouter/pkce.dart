import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Ein PKCE-Paar für den OpenRouter-Login (Konzept, Abschnitt 17a).
///
/// PKCE („Proof Key for Code Exchange") sorgt dafür, dass der Code aus dem
/// Rücksprung nur von genau der App eingelöst werden kann, die den Login
/// gestartet hat. Ohne das könnte eine andere App, die dasselbe URL-Schema
/// beansprucht, den Code abfangen und gegen einen Schlüssel tauschen.
///
/// Der [verifier] bleibt im Arbeitsspeicher der App. Nach außen geht nur die
/// [challenge] – der SHA-256-Hash, base64url-kodiert und ohne Füllzeichen.
class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  /// Erzeugt ein frisches Paar.
  ///
  /// [Random.secure] ist Absicht: Ein vorhersagbarer Verifier hebelt den
  /// ganzen Schutz aus. Für Tests lässt sich eine feste Quelle übergeben.
  factory PkcePair.generate({Random? random}) {
    final verifier = _randomVerifier(random ?? Random.secure());
    return PkcePair(verifier: verifier, challenge: challengeFor(verifier));
  }

  /// Die zufällige Zeichenkette, die die App behält.
  final String verifier;

  /// Der Wert, der im Login-Link steht.
  final String challenge;

  /// Das Verfahren, das OpenRouter erwartet.
  static const String method = 'S256';

  /// Erlaubte Zeichen laut RFC 7636 – alles URL-sicher, nichts muss kodiert
  /// werden.
  static const String _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  /// 64 Zeichen: deutlich über dem Minimum von 43 und unter dem Maximum
  /// von 128.
  static const int _length = 64;

  static String challengeFor(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));

    // Ohne `=` am Ende: Die Füllzeichen gehören nicht in eine URL, und die
    // Spezifikation verlangt ihr Weglassen ausdrücklich.
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  static String _randomVerifier(Random random) {
    return String.fromCharCodes([
      for (var i = 0; i < _length; i++)
        _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
    ]);
  }
}
