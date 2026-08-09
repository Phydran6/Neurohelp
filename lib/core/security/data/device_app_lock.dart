import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../../logging/app_logger.dart';
import '../app_lock.dart';
import '../pin_credential.dart';

/// Die App-Sperre auf dem echten Gerät.
///
/// Die PIN liegt als Salt und Hash im sicheren Speicher des Geräts
/// (Android Keystore, iOS Keychain) – nie in der Datenbank, nie im
/// Klartext.
class DeviceAppLock implements AppLock {
  const DeviceAppLock({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    LocalAuthentication? biometrics,
  }) : _storage = storage,
       _biometrics = biometrics;

  final FlutterSecureStorage _storage;
  final LocalAuthentication? _biometrics;

  static const String _key = 'pin_credential';

  LocalAuthentication get _auth => _biometrics ?? LocalAuthentication();

  @override
  Future<bool> get isBiometricAvailable async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<UnlockResult> unlockWithBiometrics() async {
    if (!await isBiometricAvailable) return UnlockResult.unavailable;

    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Entsperre Neurohelp',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      return ok ? UnlockResult.success : UnlockResult.failed;
    } on Exception catch (error) {
      // Abbruch durch den User oder Biometrie gesperrt – beides ist kein
      // Fehler, sondern führt auf die PIN zurück.
      AppLogger.info('Biometrie nicht möglich: $error', scope: 'security');
      return UnlockResult.unavailable;
    }
  }

  @override
  Future<UnlockResult> unlockWithPin(String pin) async {
    final stored = await _read();
    if (stored == null) return UnlockResult.unavailable;

    return stored.matches(pin) ? UnlockResult.success : UnlockResult.failed;
  }

  @override
  Future<void> setPin(String pin) async {
    final credential = PinCredential.fromPin(pin);
    await _storage.write(key: _key, value: jsonEncode(credential.toJson()));
  }

  @override
  Future<void> clearPin() => _storage.delete(key: _key);

  @override
  Future<bool> get hasPin async => await _read() != null;

  Future<PinCredential?> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;

    try {
      return PinCredential.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException catch (error, stackTrace) {
      AppLogger.error(
        'Gespeicherte PIN ist unlesbar',
        scope: 'security',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}

/// App-Sperre im Arbeitsspeicher – für Tests und den Fall, dass der User
/// keine Sperre eingerichtet hat.
class InMemoryAppLock implements AppLock {
  InMemoryAppLock({this.biometricAvailable = false});

  final bool biometricAvailable;
  PinCredential? _credential;

  @override
  Future<bool> get isBiometricAvailable async => biometricAvailable;

  @override
  Future<UnlockResult> unlockWithBiometrics() async =>
      biometricAvailable ? UnlockResult.success : UnlockResult.unavailable;

  @override
  Future<UnlockResult> unlockWithPin(String pin) async {
    final credential = _credential;
    if (credential == null) return UnlockResult.unavailable;
    return credential.matches(pin) ? UnlockResult.success : UnlockResult.failed;
  }

  @override
  Future<void> setPin(String pin) async {
    // Wenige Runden: Tests sollen nicht an der Schlüsselableitung hängen.
    _credential = PinCredential.fromPin(pin, iterations: 100);
  }

  @override
  Future<void> clearPin() async => _credential = null;

  @override
  Future<bool> get hasPin async => _credential != null;
}
