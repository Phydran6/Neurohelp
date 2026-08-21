import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../logging/app_logger.dart';
import 'openrouter_key.dart';

/// Ablage für den nutzereigenen OpenRouter-Schlüssel.
///
/// Eigene Schnittstelle statt direktem Zugriff auf den sicheren Speicher:
/// Tests brauchen keinen Keystore, und der Rest der App sieht nur „lesen,
/// schreiben, wegwerfen".
abstract interface class OpenRouterKeyStore {
  Future<OpenRouterKey?> read();

  Future<void> write(OpenRouterKey key);

  Future<void> clear();
}

/// Der echte Speicher: Android Keystore, iOS Keychain.
///
/// **Nie** in die SQLite-Datenbank und **nie** ins Backend – ein fremder
/// Zugang, der bei uns liegt, wäre genau das, was das Konzept ausschließt.
class SecureOpenRouterKeyStore implements OpenRouterKeyStore {
  const SecureOpenRouterKeyStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const String _keyValue = 'openrouter_key';
  static const String _keyOrigin = 'openrouter_key_origin';

  @override
  Future<OpenRouterKey?> read() async {
    try {
      final value = await _storage.read(key: _keyValue);
      if (value == null || value.isEmpty) return null;

      final origin = await _storage.read(key: _keyOrigin);
      return OpenRouterKey(
        value: value,
        origin: origin == OpenRouterKeyOrigin.manual.name
            ? OpenRouterKeyOrigin.manual
            : OpenRouterKeyOrigin.login,
      );
    } on Exception catch (error, stackTrace) {
      // Ein unlesbarer Keystore darf die App nicht anhalten: Ohne Schlüssel
      // läuft sie über die eigene KI weiter.
      AppLogger.error(
        'Gespeicherter KI-Zugang ist nicht lesbar',
        scope: 'openrouter',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> write(OpenRouterKey key) async {
    await _storage.write(key: _keyValue, value: key.value);
    await _storage.write(key: _keyOrigin, value: key.origin.name);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyValue);
    await _storage.delete(key: _keyOrigin);
  }
}

/// Speicher im Arbeitsspeicher – für Tests und für den Fall, dass es gar
/// keinen sicheren Speicher gibt.
class InMemoryOpenRouterKeyStore implements OpenRouterKeyStore {
  InMemoryOpenRouterKeyStore([this._key]);

  OpenRouterKey? _key;

  @override
  Future<OpenRouterKey?> read() async => _key;

  @override
  Future<void> write(OpenRouterKey key) async => _key = key;

  @override
  Future<void> clear() async => _key = null;
}
