import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../logging/app_logger.dart';
import 'custom_endpoint.dart';

/// Ablage für den selbst eingetragenen KI-Zugang.
///
/// Wie beim OpenRouter-Schlüssel: Schlüsselbund des Geräts, **nie** die
/// SQLite-Datenbank und **nie** das Backend. Der Zugang gehört dem User.
abstract interface class CustomEndpointStore {
  Future<CustomAiEndpoint?> read();

  Future<void> write(CustomAiEndpoint endpoint);

  Future<void> clear();
}

/// Android Keystore, iOS Keychain.
class SecureCustomEndpointStore implements CustomEndpointStore {
  const SecureCustomEndpointStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  static const String _keyKind = 'custom_ai_kind';
  static const String _keyBaseUrl = 'custom_ai_base_url';
  static const String _keyModel = 'custom_ai_model';
  static const String _keyApiKey = 'custom_ai_key';

  @override
  Future<CustomAiEndpoint?> read() async {
    try {
      final baseUrl = await _storage.read(key: _keyBaseUrl);
      final model = await _storage.read(key: _keyModel);
      if (baseUrl == null || baseUrl.isEmpty) return null;
      if (model == null || model.isEmpty) return null;

      final kind = await _storage.read(key: _keyKind);
      return CustomAiEndpoint(
        kind: kind == CustomEndpointKind.anthropic.name
            ? CustomEndpointKind.anthropic
            : CustomEndpointKind.openAiCompatible,
        baseUrl: baseUrl,
        model: model,
        apiKey: await _storage.read(key: _keyApiKey) ?? '',
      );
    } on Exception catch (error, stackTrace) {
      // Ein unlesbarer Schlüsselbund darf die App nicht anhalten: Ohne
      // eigenen Endpunkt läuft die KI eine Stufe einfacher weiter.
      AppLogger.error(
        'Eigener KI-Zugang ist nicht lesbar',
        scope: 'ai',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> write(CustomAiEndpoint endpoint) async {
    await _storage.write(key: _keyKind, value: endpoint.kind.name);
    await _storage.write(key: _keyBaseUrl, value: endpoint.baseUrl);
    await _storage.write(key: _keyModel, value: endpoint.model);
    await _storage.write(key: _keyApiKey, value: endpoint.apiKey);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyKind);
    await _storage.delete(key: _keyBaseUrl);
    await _storage.delete(key: _keyModel);
    await _storage.delete(key: _keyApiKey);
  }
}

/// Ablage im Arbeitsspeicher – für Tests.
class InMemoryCustomEndpointStore implements CustomEndpointStore {
  InMemoryCustomEndpointStore([this._endpoint]);

  CustomAiEndpoint? _endpoint;

  @override
  Future<CustomAiEndpoint?> read() async => _endpoint;

  @override
  Future<void> write(CustomAiEndpoint endpoint) async => _endpoint = endpoint;

  @override
  Future<void> clear() async => _endpoint = null;
}
