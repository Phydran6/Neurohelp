import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'openrouter_exception.dart';
import 'openrouter_model.dart';
import 'pkce.dart';

/// Was OpenRouter über einen Schlüssel sagt.
class OpenRouterKeyInfo {
  const OpenRouterKeyInfo({required this.hasCredit, this.remaining});

  /// Ob der User bei OpenRouter Guthaben aufgeladen hat.
  ///
  /// Nur dann darf die App auch kostenpflichtige Modelle in Betracht ziehen.
  /// Ungefragt Geld ausgeben tut sie nicht.
  final bool hasCredit;

  /// Restguthaben in US-Dollar, falls OpenRouter eine Zahl liefert.
  final double? remaining;
}

/// Der direkte Draht zu OpenRouter – die einzige Stelle in der App, die eine
/// fremde HTTP-Adresse kennt.
///
/// **Warum hier kein Proxy:** Die eigene gehostete KI läuft über das Backend,
/// weil sie geschützt werden muss. Der nutzereigene Zugang geht direkt vom
/// Gerät raus (Konzept, Abschnitt 17a). Ein Proxy hätte hier keinen Zweck und
/// wäre nur eine zusätzliche Station, auf der fremde Daten landen.
class OpenRouterApi {
  OpenRouterApi({
    http.Client? client,
    this.timeout = const Duration(seconds: 45),
  }) : _given = client;

  final http.Client? _given;
  http.Client? _own;

  /// Erst beim ersten Aufruf angelegt.
  ///
  /// Ohne eigenen Zugang wird hier nie etwas gefragt – dann soll auch kein
  /// HTTP-Client herumstehen. In Widget-Tests warnt Flutter sonst über einen
  /// Client, den niemand benutzt.
  http.Client get _client => _given ?? (_own ??= http.Client());

  /// Ohne Deckel wartet ein Aufruf im Zug ohne Empfang endlos, und für den
  /// User „hängt die App".
  final Duration timeout;

  static const String _base = 'https://openrouter.ai/api/v1';

  /// Die Seite, auf der sich der User anmeldet. Sie gehört nicht unter
  /// `/api/v1`.
  static const String _authPage = 'https://openrouter.ai/auth';

  /// Rücksprung in die App. Muss zum Schema im Android-Manifest und in der
  /// Info.plist passen – sonst kommt der User im Browser nicht zurück.
  static const String callbackScheme = 'neurohelp';
  static const String callbackUrl = '$callbackScheme://openrouter';

  /// Damit die App bei OpenRouter zugeordnet wird. Kein Geheimnis, keine
  /// Nutzerdaten – nur der Name des Programms.
  static Map<String, String> get attribution => const {
    'HTTP-Referer': 'https://github.com/Phydran6/Neurohelp',
    'X-Title': 'Neurohelp',
  };

  /// Der Link, auf den der User im Browser geschickt wird.
  static Uri loginUrl(PkcePair pkce) {
    return Uri.parse(_authPage).replace(
      queryParameters: {
        'callback_url': callbackUrl,
        'code_challenge': pkce.challenge,
        'code_challenge_method': PkcePair.method,
      },
    );
  }

  /// Tauscht den Code aus dem Rücksprung gegen den nutzereigenen Schlüssel.
  Future<String> exchangeCode({
    required String code,
    required String verifier,
  }) async {
    final json = await _postJson(
      Uri.parse('$_base/auth/keys'),
      body: {
        'code': code,
        'code_verifier': verifier,
        'code_challenge_method': PkcePair.method,
      },
    );

    final key = json['key'];
    if (key is! String || key.isEmpty) {
      throw const OpenRouterException(
        OpenRouterFailure.malformed,
        'Die Anmeldung kam ohne Zugang zurück.',
      );
    }
    return key;
  }

  /// Holt das Modellverzeichnis. **Zur Laufzeit**, weil es rotiert.
  Future<List<OpenRouterModel>> listModels() async {
    final json = await _getJson(Uri.parse('$_base/models'));

    final data = json['data'];
    if (data is! List) {
      throw const OpenRouterException(
        OpenRouterFailure.malformed,
        'Das Modellverzeichnis war nicht lesbar.',
      );
    }

    return [
      for (final entry in data)
        if (entry is Map<String, Object?>) OpenRouterModel.fromJson(entry),
    ];
  }

  /// Fragt nach, ob der Schlüssel noch gilt und ob Guthaben da ist.
  Future<OpenRouterKeyInfo> keyInfo(String key) async {
    final json = await _getJson(Uri.parse('$_base/key'), key: key);

    final data = json['data'];
    if (data is! Map) return const OpenRouterKeyInfo(hasCredit: false);

    final freeTier = data['is_free_tier'];
    final remaining = data['limit_remaining'];

    return OpenRouterKeyInfo(
      // `is_free_tier == false` heißt: Der User hat schon einmal aufgeladen.
      hasCredit: freeTier == false,
      remaining: remaining is num ? remaining.toDouble() : null,
    );
  }

  /// Stellt eine Anfrage an ein Modell und liefert den Antworttext.
  Future<String> complete({
    required String key,
    required String model,
    required String system,
    required String input,
  }) async {
    final json = await _postJson(
      Uri.parse('$_base/chat/completions'),
      key: key,
      body: {
        'model': model,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': input},
        ],
      },
    );

    final choices = json['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const OpenRouterException(
        OpenRouterFailure.malformed,
        'Da kam keine Antwort zurück.',
      );
    }

    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;

    if (content is! String || content.trim().isEmpty) {
      throw const OpenRouterException(
        OpenRouterFailure.malformed,
        'Die Antwort war leer.',
      );
    }

    return content.trim();
  }

  void close() {
    _own?.close();
    _own = null;
  }

  // ------------------------------------------------------------------ intern

  Future<Map<String, Object?>> _getJson(Uri url, {String? key}) {
    return _send(() => _client.get(url, headers: _headers(key: key)));
  }

  Future<Map<String, Object?>> _postJson(
    Uri url, {
    required Map<String, Object?> body,
    String? key,
  }) {
    return _send(
      () => _client.post(
        url,
        headers: {
          ..._headers(key: key),
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
  }

  Map<String, String> _headers({String? key}) => {
    ...attribution,
    if (key != null) 'Authorization': 'Bearer $key',
  };

  Future<Map<String, Object?>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const OpenRouterException(
        OpenRouterFailure.network,
        'Das hat zu lange gedauert.',
      );
    } on Exception catch (error) {
      throw OpenRouterException(
        OpenRouterFailure.network,
        'Keine Verbindung zum KI-Dienst.',
        technical: error.toString(),
      );
    }

    if (response.statusCode >= 400) {
      throw _failureFor(response);
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Kein JSON-Objekt.');
      }
      return decoded;
    } on FormatException catch (error) {
      throw OpenRouterException(
        OpenRouterFailure.malformed,
        'Die Antwort war nicht lesbar.',
        technical: error.message,
      );
    }
  }

  /// Übersetzt einen HTTP-Fehler in etwas, mit dem die App umgehen kann.
  static OpenRouterException _failureFor(http.Response response) {
    final detail = _messageIn(response.body);

    return switch (response.statusCode) {
      401 || 403 => OpenRouterException(
        OpenRouterFailure.unauthorized,
        'Dein KI-Konto ist nicht mehr verbunden.',
        technical: detail,
      ),
      402 => OpenRouterException(
        // Kein Guthaben mehr: Ein anderes, kostenloses Modell kann tragen.
        OpenRouterFailure.modelUnavailable,
        'Für dieses Modell reicht dein Guthaben nicht.',
        technical: detail,
      ),
      404 => OpenRouterException(
        OpenRouterFailure.modelUnavailable,
        'Dieses Modell gibt es nicht mehr.',
        technical: detail,
      ),
      429 => OpenRouterException(
        OpenRouterFailure.rateLimited,
        'Gerade ist das Limit erreicht.',
        technical: detail,
      ),
      >= 500 => OpenRouterException(
        OpenRouterFailure.network,
        'Der KI-Dienst hat gerade ein Problem.',
        technical: detail,
      ),
      _ => OpenRouterException(
        OpenRouterFailure.refused,
        'Die Anfrage ging nicht durch.',
        technical: detail ?? 'HTTP ${response.statusCode}',
      ),
    };
  }

  static String? _messageIn(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (error is String) return error;
      }
    } on FormatException {
      // Kein JSON – dann eben der Rohtext, gekürzt.
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > 300 ? '${trimmed.substring(0, 300)}…' : trimmed;
  }
}
