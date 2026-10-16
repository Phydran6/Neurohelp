import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../logging/app_logger.dart';
import 'custom_endpoint.dart';
import 'custom_endpoint_store.dart';

/// Warum ein eigener Endpunkt nicht funktioniert hat.
///
/// Der Unterschied zählt: „Adresse nicht erreichbar" schickt den User ins
/// Netzwerk, „Schlüssel abgelehnt" zum Anbieter, „Modell unbekannt" in die
/// Modellliste. Eine gemeinsame Fehlermeldung schickt ihn nirgendwohin.
enum CustomEndpointFailure {
  unreachable,
  unauthorized,
  modelUnknown,
  malformed,
  server,
}

class CustomEndpointException implements Exception {
  const CustomEndpointException(this.failure, this.reason, {this.technical});

  final CustomEndpointFailure failure;

  /// Der Satz, der auf den Bildschirm darf.
  final String reason;

  /// Fürs aufklappbare Kleingedruckte.
  final String? technical;

  @override
  String toString() => 'CustomEndpointException(${failure.name}): $reason';
}

/// Der selbst eingetragene KI-Zugang samt Verbindungstest.
///
/// Hält den Zustand für die Oberfläche und prüft vor dem Speichern **einmal
/// wirklich nach**. Ein Zugang, der erst mitten in einem Ablauf als falsch
/// auffällt, ist schlimmer als gar keiner.
class CustomEndpointAccount extends ChangeNotifier {
  CustomEndpointAccount({
    required CustomEndpointStore store,
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : _store = store,
       _given = client;

  final CustomEndpointStore _store;
  final http.Client? _given;
  http.Client? _own;

  /// Ohne eigenen Endpunkt wird hier nie etwas gefragt – dann soll auch kein
  /// HTTP-Client herumstehen.
  http.Client get _client => _given ?? (_own ??= http.Client());

  final Duration timeout;

  CustomAiEndpoint? _endpoint;
  bool _loaded = false;

  CustomAiEndpoint? get endpoint => _endpoint;

  bool get isConnected => _endpoint != null;

  bool get isLoaded => _loaded;

  Future<void> load() async {
    _endpoint = await _store.read();
    _loaded = true;
    notifyListeners();
  }

  /// Probiert [endpoint] aus und übernimmt ihn nur, wenn er antwortet.
  Future<void> connect(CustomAiEndpoint endpoint) async {
    final problem = endpoint.problem;
    if (problem != null) {
      throw CustomEndpointException(CustomEndpointFailure.malformed, problem);
    }

    await complete(
      endpoint,
      system: 'Antworte mit einem einzigen Wort.',
      input: 'Verbindungstest.',
    );

    await _store.write(endpoint);
    _endpoint = endpoint;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _store.clear();
    _endpoint = null;
    notifyListeners();
  }

  /// Eine Anfrage an den eingetragenen Server.
  ///
  /// Statisch gehalten von der Oberfläche getrennt: Der KI-Client ruft
  /// dieselbe Methode wie der Verbindungstest, damit beide sich nicht
  /// auseinanderentwickeln.
  Future<String> complete(
    CustomAiEndpoint endpoint, {
    required String system,
    required String input,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            endpoint.completionUrl,
            headers: endpoint.headers,
            body: jsonEncode(
              endpoint.requestBody(system: system, input: input),
            ),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw CustomEndpointException(
        CustomEndpointFailure.unreachable,
        'Der Server hat nicht geantwortet. Ist die Adresse richtig, und '
        'erreicht dieses Gerät sie überhaupt?',
        technical: 'Zeitüberschreitung nach ${timeout.inSeconds} s',
      );
    } on Exception catch (error) {
      throw CustomEndpointException(
        CustomEndpointFailure.unreachable,
        'Die Adresse war nicht erreichbar.',
        technical: error.toString(),
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CustomEndpointException(
        CustomEndpointFailure.unauthorized,
        'Der Schlüssel wurde nicht angenommen.',
        technical: 'HTTP ${response.statusCode}: ${_short(response.body)}',
      );
    }

    if (response.statusCode == 404) {
      throw CustomEndpointException(
        CustomEndpointFailure.modelUnknown,
        'Unter dieser Adresse gibt es den Aufruf nicht. Bei OpenWebUI endet '
        'sie meist auf /api, bei den meisten anderen auf /v1.',
        technical: 'HTTP 404 auf ${endpoint.completionUrl}',
      );
    }

    if (response.statusCode >= 400) {
      final body = _short(response.body);
      final aboutModel = body.toLowerCase().contains('model');
      throw CustomEndpointException(
        aboutModel
            ? CustomEndpointFailure.modelUnknown
            : CustomEndpointFailure.server,
        aboutModel
            ? 'Das Modell „${endpoint.model}" kennt der Server nicht.'
            : 'Der Server hat die Anfrage abgelehnt.',
        technical: 'HTTP ${response.statusCode}: $body',
      );
    }

    return _textOf(response, endpoint.kind);
  }

  /// Die Antwort aus dem JSON holen – je Schnittstelle woanders.
  static String _textOf(http.Response response, CustomEndpointKind kind) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (error) {
      throw CustomEndpointException(
        CustomEndpointFailure.malformed,
        'Die Antwort des Servers war nicht lesbar.',
        technical: error.message,
      );
    }

    if (json is! Map<String, Object?>) {
      throw const CustomEndpointException(
        CustomEndpointFailure.malformed,
        'Die Antwort des Servers war nicht lesbar.',
      );
    }

    final text = switch (kind) {
      CustomEndpointKind.openAiCompatible => _openAiText(json),
      CustomEndpointKind.anthropic => _anthropicText(json),
    };

    if (text == null || text.trim().isEmpty) {
      throw const CustomEndpointException(
        CustomEndpointFailure.malformed,
        'Der Server hat geantwortet, aber ohne Text.',
      );
    }
    return text.trim();
  }

  static String? _openAiText(Map<String, Object?> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) return null;

    final first = choices.first;
    if (first is! Map<String, Object?>) return null;

    final message = first['message'];
    if (message is! Map<String, Object?>) return null;

    return message['content'] as String?;
  }

  static String? _anthropicText(Map<String, Object?> json) {
    final content = json['content'];
    if (content is! List) return null;

    final parts = <String>[];
    for (final block in content) {
      if (block is Map<String, Object?> && block['type'] == 'text') {
        final text = block['text'];
        if (text is String) parts.add(text);
      }
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  /// Fehlermeldungen von Servern sind manchmal seitenlang. Fürs
  /// Kleingedruckte reicht der Anfang.
  static String _short(String body) {
    final cleaned = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.length <= 300 ? cleaned : '${cleaned.substring(0, 300)}…';
  }

  @override
  void dispose() {
    _own?.close();
    super.dispose();
  }

  /// Nur zum Protokollieren – nie auf dem Bildschirm.
  void logState() => AppLogger.info(
    isConnected ? 'Eigener Endpunkt: ${_endpoint!.label}' : 'Kein Endpunkt',
    scope: 'ai',
  );
}
