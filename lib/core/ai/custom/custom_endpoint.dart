/// Welche Sprache der Server spricht.
///
/// Zwei reichen für praktisch alles: Fast jeder Anbieter und jede selbst
/// betriebene Oberfläche versteht die OpenAI-Schnittstelle. Anthropic hat
/// eine eigene – und wer ein Claude-Konto hat, soll es benutzen können, ohne
/// vorher einen Übersetzer davorzustellen.
enum CustomEndpointKind {
  /// OpenAI, OpenWebUI, LM Studio, Ollama, Groq, LocalAI, vLLM …
  openAiCompatible,

  /// Anthropic (Claude) mit `x-api-key`.
  anthropic,
}

/// Ein selbst eingetragener KI-Zugang (Konzept, Abschnitt 17a, Expertenweg).
///
/// **Warum es das gibt:** Der Login-Weg über OpenRouter ist für alle da, die
/// nichts einrichten wollen. Wer aber schon eine eigene KI betreibt – ein
/// OpenWebUI im Heimnetz, ein Ollama auf dem Rechner, ein Konto bei OpenAI
/// oder Anthropic –, soll sie benutzen dürfen, statt sich einen zweiten
/// Zugang zuzulegen.
///
/// Der Schlüssel liegt **ausschließlich** im Schlüsselbund des Geräts und
/// geht nie ins Backend. Die Anfragen gehen direkt vom Gerät an den Server,
/// den der User eingetragen hat – ein Umweg über uns wäre nur eine weitere
/// Station, auf der fremde Daten landen.
class CustomAiEndpoint {
  const CustomAiEndpoint({
    required this.kind,
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
  });

  final CustomEndpointKind kind;

  /// Die Adresse ohne den Aufruf am Ende, z.B. `https://api.openai.com/v1`.
  final String baseUrl;

  /// Der Modellname, so wie der Server ihn kennt.
  ///
  /// Hier **darf** ein fester Name stehen: Bei OpenRouter verbietet das
  /// Konzept die feste Verdrahtung, weil dort die kostenlosen Modelle
  /// rotieren. Auf einem eigenen Server weiß nur der Betreiber, was
  /// installiert ist – raten wäre hier schlechter als fragen.
  final String model;

  /// Leer erlaubt: Ein Ollama im Heimnetz verlangt oft keinen Schlüssel.
  final String apiKey;

  bool get hasKey => apiKey.trim().isNotEmpty;

  /// Was in den Einstellungen steht – Adresse ohne Schema, plus Modell.
  String get label {
    final host = Uri.tryParse(baseUrl)?.host;
    final where = host == null || host.isEmpty ? baseUrl : host;
    return '$where · $model';
  }

  /// Nur die letzten vier Zeichen des Schlüssels. Der volle Wert gehört
  /// nirgends auf einen Bildschirm.
  String get keyHint {
    final value = apiKey.trim();
    if (value.isEmpty) return 'ohne Schlüssel';
    if (value.length <= 4) return '••••';
    return '••••${value.substring(value.length - 4)}';
  }

  /// Die vollständige Adresse für eine Anfrage.
  ///
  /// Tolerant gegenüber dem, was Leute eintragen: mit und ohne Schrägstrich
  /// am Ende, und auch dann richtig, wenn jemand die volle Adresse inklusive
  /// Aufruf aus einer Anleitung kopiert hat.
  Uri get completionUrl {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final suffix = switch (kind) {
      CustomEndpointKind.openAiCompatible => '/chat/completions',
      CustomEndpointKind.anthropic => '/messages',
    };

    if (trimmed.endsWith(suffix)) return Uri.parse(trimmed);
    return Uri.parse('$trimmed$suffix');
  }

  /// Ob die Eingaben überhaupt einen Versuch wert sind.
  ///
  /// Wird **vor** dem Speichern geprüft. Ein Zugang, der erst mitten in einem
  /// Ablauf als unbrauchbar auffällt, ist schlimmer als gar keiner.
  String? get problem {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Die Adresse sieht nicht nach einer Adresse aus. Sie fängt mit '
          'https:// an, zum Beispiel https://api.openai.com/v1';
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'Die Adresse muss mit http:// oder https:// anfangen.';
    }
    if (model.trim().isEmpty) {
      return 'Ohne Modellnamen weiß der Server nicht, wen er fragen soll.';
    }
    if (kind == CustomEndpointKind.anthropic && !hasKey) {
      return 'Anthropic verlangt einen Schlüssel. Er fängt mit sk-ant- an.';
    }
    return null;
  }

  Map<String, String> get headers => switch (kind) {
    CustomEndpointKind.openAiCompatible => {
      'Content-Type': 'application/json',
      if (hasKey) 'Authorization': 'Bearer ${apiKey.trim()}',
    },
    CustomEndpointKind.anthropic => {
      'Content-Type': 'application/json',
      'x-api-key': apiKey.trim(),
      // Pflichtfeld bei Anthropic. Ohne das kommt 400 zurück, und die
      // Meldung liest sich wie ein falscher Schlüssel.
      'anthropic-version': '2023-06-01',
    },
  };

  Map<String, Object?> requestBody({
    required String system,
    required String input,
  }) => switch (kind) {
    CustomEndpointKind.openAiCompatible => {
      'model': model.trim(),
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': input},
      ],
    },
    CustomEndpointKind.anthropic => {
      'model': model.trim(),
      // Pflichtfeld bei Anthropic, anders als bei OpenAI. Großzügig genug
      // für eine zerlegte Aufgabe, klein genug, um nicht zu entgleisen.
      'max_tokens': 1024,
      'system': system,
      'messages': [
        {'role': 'user', 'content': input},
      ],
    },
  };

  CustomAiEndpoint copyWith({
    CustomEndpointKind? kind,
    String? baseUrl,
    String? model,
    String? apiKey,
  }) => CustomAiEndpoint(
    kind: kind ?? this.kind,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    apiKey: apiKey ?? this.apiKey,
  );

  @override
  bool operator ==(Object other) =>
      other is CustomAiEndpoint &&
      other.kind == kind &&
      other.baseUrl == baseUrl &&
      other.model == model &&
      other.apiKey == apiKey;

  @override
  int get hashCode => Object.hash(kind, baseUrl, model, apiKey);
}

/// Was man eintragen kann, mit einem Beispiel dazu.
///
/// Steht in der Oberfläche als Auswahl. Ein leeres Adressfeld mit dem Hinweis
/// „Basis-URL" hilft niemandem – auch keinem Experten.
class CustomEndpointPreset {
  const CustomEndpointPreset({
    required this.id,
    required this.label,
    required this.kind,
    required this.baseUrl,
    required this.model,
    required this.hint,
  });

  final String id;
  final String label;
  final CustomEndpointKind kind;
  final String baseUrl;
  final String model;

  /// Wo der User seinen Schlüssel herbekommt.
  final String hint;

  static const List<CustomEndpointPreset> all = [
    CustomEndpointPreset(
      id: 'openai',
      label: 'OpenAI (ChatGPT-Konto)',
      kind: CustomEndpointKind.openAiCompatible,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      hint:
          'Schlüssel unter platform.openai.com/api-keys. Achtung: Ein '
          'ChatGPT-Plus-Abo ist nicht dasselbe – die Schnittstelle wird '
          'getrennt abgerechnet.',
    ),
    CustomEndpointPreset(
      id: 'anthropic',
      label: 'Anthropic (Claude)',
      kind: CustomEndpointKind.anthropic,
      baseUrl: 'https://api.anthropic.com/v1',
      model: 'claude-haiku-4-5-20251001',
      hint:
          'Schlüssel unter console.anthropic.com. Auch hier gilt: Ein '
          'Claude-Abo ist nicht die Schnittstelle.',
    ),
    CustomEndpointPreset(
      id: 'openwebui',
      label: 'OpenWebUI (eigener Server)',
      kind: CustomEndpointKind.openAiCompatible,
      baseUrl: 'https://deine-adresse/api',
      model: 'llama3.1',
      hint:
          'Schlüssel in OpenWebUI unter Einstellungen → Konto → API-Keys. '
          'Das Gerät muss den Server erreichen können.',
    ),
    CustomEndpointPreset(
      id: 'ollama',
      label: 'Ollama / LM Studio (lokal)',
      kind: CustomEndpointKind.openAiCompatible,
      baseUrl: 'http://192.168.1.10:11434/v1',
      model: 'llama3.1',
      hint:
          'Meist ohne Schlüssel. Ollama muss auf allen Adressen lauschen, '
          'sonst kommt das Telefon nicht heran.',
    ),
  ];
}
