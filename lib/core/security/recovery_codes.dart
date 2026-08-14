import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Wiederherstellungs-Codes (Konzept, Abschnitt 13).
///
/// Der Weg zurück, wenn Fingerabdruck, PIN und Authenticator-App alle nicht
/// mehr zur Verfügung stehen – Gerät gewechselt, App neu installiert, Handy
/// weg. Ohne sie ist ein vergessener Zugang eine Sackgasse.
///
/// Gespeichert wird **nie** der Code selbst, nur Salt und Hash – dieselbe
/// Regel wie bei der PIN. Alle Codes teilen sich ein Salt, damit das Prüfen
/// eine einzige Ableitung braucht statt einer pro Code.
class RecoveryCodes {
  const RecoveryCodes({
    required this.salt,
    required this.hashes,
    required this.iterations,
  });

  final String salt;

  /// Die Hashes der **noch nicht verbrauchten** Codes.
  final List<String> hashes;

  final int iterations;

  /// Wie viele Codes erzeugt werden. Zehn ist genug für jeden realistischen
  /// Notfall und passt noch auf einen Zettel.
  static const int defaultCount = 10;

  /// Rundenzahl der Ableitung.
  ///
  /// Niedriger als bei der PIN, und das mit Absicht: Eine vierstellige PIN hat
  /// rund 13 Bit und lebt allein von der teuren Ableitung. Ein Code aus acht
  /// Zeichen dieses Alphabets hat knapp 39 Bit – die Arbeit steckt schon im
  /// Code selbst. Bei zehn Codes wäre die PIN-Rundenzahl das Zehnfache an
  /// Rechenzeit, und das Einrichten würde spürbar hängen.
  static const int defaultIterations = 20000;

  /// Zeichen ohne Verwechslungsgefahr: kein O/0, kein I/1, kein S/5.
  ///
  /// Diese Codes werden abgeschrieben und abgetippt, oft in schlechter
  /// Verfassung. Ein „war das eine Null oder ein O?" macht den Notfallweg
  /// wertlos.
  static const String _alphabet = 'ABCDEFGHJKLMNPQRTUVWXY2346789';

  static const int _groupLength = 4;
  static const int _groups = 2;

  int get remaining => hashes.length;

  bool get isEmpty => hashes.isEmpty;

  /// Erzeugt neue Codes.
  ///
  /// Liefert die speicherbare Form **und** den Klartext – der ist der einzige
  /// Moment, in dem die Codes lesbar sind. Danach existieren sie nur noch
  /// dort, wo der User sie hingelegt hat.
  static ({RecoveryCodes stored, List<String> plain}) generate({
    int count = defaultCount,
    int iterations = defaultIterations,
    Random? random,
  }) {
    final source = random ?? Random.secure();
    final salt = _randomSalt(source);

    final plain = <String>[];
    while (plain.length < count) {
      final code = _randomCode(source);
      // Doppelte wären zwar unwahrscheinlich, würden aber einen Code
      // verschenken: Der zweite ließe sich nie einlösen.
      if (!plain.contains(code)) plain.add(code);
    }

    return (
      stored: RecoveryCodes(
        salt: salt,
        hashes: [for (final code in plain) _derive(code, salt, iterations)],
        iterations: iterations,
      ),
      plain: plain,
    );
  }

  /// Ob [code] zu einem der offenen Codes passt.
  bool matches(String code) => hashes.contains(_hashOf(code));

  /// Löst einen Code ein.
  ///
  /// Liefert den verbleibenden Satz, oder `null`, wenn der Code nicht passt.
  /// Ein eingelöster Code ist verbraucht – sonst wäre ein abfotografierter
  /// Zettel ein Dauerschlüssel.
  RecoveryCodes? consume(String code) {
    final hash = _hashOf(code);
    if (!hashes.contains(hash)) return null;

    return RecoveryCodes(
      salt: salt,
      hashes: [...hashes]..remove(hash),
      iterations: iterations,
    );
  }

  Map<String, Object?> toJson() => {
    'salt': salt,
    'hashes': hashes,
    'iterations': iterations,
  };

  static RecoveryCodes fromJson(Map<String, Object?> json) => RecoveryCodes(
    salt: json['salt']! as String,
    hashes: [
      for (final hash in json['hashes']! as List<Object?>) hash! as String,
    ],
    iterations: json['iterations']! as int,
  );

  /// Normalisiert die Eingabe, bevor sie geprüft wird.
  ///
  /// Bindestriche, Leerzeichen und Kleinschreibung sind beim Abtippen normal
  /// und dürfen nicht der Grund sein, warum der Notfallweg scheitert.
  static String normalize(String code) =>
      code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  String _hashOf(String code) => _derive(normalize(code), salt, iterations);

  static String _randomCode(Random random) {
    final buffer = StringBuffer();
    for (var group = 0; group < _groups; group++) {
      if (group > 0) buffer.write('-');
      for (var i = 0; i < _groupLength; i++) {
        buffer.write(_alphabet[random.nextInt(_alphabet.length)]);
      }
    }
    return buffer.toString();
  }

  static String _randomSalt(Random random) {
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes);
  }

  /// Wiederholtes Hashen (PBKDF2-artig, HMAC-SHA256) – wie bei der PIN.
  static String _derive(String code, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(salt));
    List<int> bytes = utf8.encode(normalize(code));

    for (var round = 0; round < iterations; round++) {
      bytes = hmac.convert(bytes).bytes;
    }
    return base64Url.encode(bytes);
  }
}
