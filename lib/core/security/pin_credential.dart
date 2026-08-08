import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Gespeicherte Form einer PIN bzw. eines Passworts.
///
/// Die PIN selbst wird **nie** gespeichert – nur Salt und Hash. Beides gehört
/// in den sicheren Speicher des Geräts (Keystore / Keychain), nicht in die
/// normale Datenbank.
class PinCredential {
  const PinCredential({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  final String salt;
  final String hash;
  final int iterations;

  /// Rundenzahl der Ableitung. Bewusst hoch genug, damit Durchprobieren auf
  /// dem Gerät teuer ist, aber niedrig genug für ein flüssiges Entsperren.
  static const int defaultIterations = 120000;

  static const int _minLength = 4;

  /// Leitet aus einer PIN eine speicherbare Form ab.
  ///
  /// Wirft [ArgumentError], wenn die PIN zu kurz ist.
  factory PinCredential.fromPin(
    String pin, {
    String? salt,
    int iterations = defaultIterations,
  }) {
    if (pin.trim().length < _minLength) {
      throw ArgumentError.value(
        pin,
        'pin',
        'Die PIN braucht mindestens $_minLength Zeichen.',
      );
    }

    final actualSalt = salt ?? _randomSalt();
    return PinCredential(
      salt: actualSalt,
      hash: _derive(pin, actualSalt, iterations),
      iterations: iterations,
    );
  }

  /// Prüft eine eingegebene PIN gegen die gespeicherte Form.
  bool matches(String pin) {
    final candidate = _derive(pin, salt, iterations);
    return _constantTimeEquals(candidate, hash);
  }

  Map<String, Object?> toJson() => {
    'salt': salt,
    'hash': hash,
    'iterations': iterations,
  };

  static PinCredential fromJson(Map<String, Object?> json) => PinCredential(
    salt: json['salt']! as String,
    hash: json['hash']! as String,
    iterations: json['iterations']! as int,
  );

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes);
  }

  /// Wiederholtes Hashen (PBKDF2-artig, HMAC-SHA256).
  static String _derive(String pin, String salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(salt));
    var bytes = utf8.encode(pin);

    for (var round = 0; round < iterations; round++) {
      bytes = hmac.convert(bytes).bytes;
    }

    return base64Url.encode(bytes);
  }

  /// Vergleicht ohne früh abzubrechen, damit die Laufzeit nichts verrät.
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;

    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
