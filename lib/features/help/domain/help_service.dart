import '../../../core/ai/ai_client.dart';
import 'faq.dart';

/// Woher eine Antwort kommt.
enum HelpSource {
  /// Aus dem festen FAQ-Katalog.
  catalog,

  /// Von der KI, weil im Katalog nichts passte.
  ai,

  /// Es gibt keine Antwort.
  none,
}

/// Die Antwort auf eine Frage im Hilfe-Bereich.
class HelpAnswer {
  const HelpAnswer({
    required this.source,
    required this.text,
    this.entries = const [],
  });

  final HelpSource source;

  /// Der Antworttext. Bei [HelpSource.none] eine ruhige Erklärung, warum
  /// gerade nichts kommt – kein Fehlertext.
  final String text;

  /// Die passenden Katalog-Einträge, falls es welche gab.
  final List<FaqEntry> entries;
}

/// Beantwortet Fragen im Hilfe-Bereich (Konzept, Abschnitt 15).
///
/// **Erst der Katalog, dann die KI.** Der feste Katalog ist der Weg ohne KI
/// und trägt allein; die KI kommt nur dazu, wenn nichts passt und der User
/// sie eingeschaltet hat.
class HelpService {
  const HelpService(this._ai);

  final AiClient _ai;

  /// Alle festen Einträge – die Ansicht, die der Hilfe-Bereich zuerst zeigt.
  List<FaqEntry> get allEntries => FaqCatalog.entries;

  Future<HelpAnswer> ask(String question) async {
    final matches = FaqCatalog.search(question);

    if (matches.isNotEmpty) {
      return HelpAnswer(
        source: HelpSource.catalog,
        text: matches.first.answer,
        entries: matches,
      );
    }

    if (!_ai.isEnabled) {
      return const HelpAnswer(
        source: HelpSource.none,
        text:
            'Dazu habe ich keine feste Antwort. Wenn du die KI einschaltest, '
            'kann ich frei auf solche Fragen antworten.',
      );
    }

    try {
      final text = await _ai.run(AiTask.answerHelp, input: question);
      return HelpAnswer(source: HelpSource.ai, text: text);
    } on AiUnavailableException {
      // Die KI ist gerade nicht erreichbar. Das ist kein Fehler des Users
      // und wird auch nicht so benannt.
      return const HelpAnswer(
        source: HelpSource.none,
        text:
            'Dazu habe ich gerade keine Antwort. Versuch es später noch mal '
            'oder schau in die Liste oben.',
      );
    }
  }
}
