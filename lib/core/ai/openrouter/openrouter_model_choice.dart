import 'openrouter_model.dart';

/// Wählt aus dem Verzeichnis die Modelle aus, die die App benutzen darf.
///
/// **Merksatz aus dem Konzept: kein Modell wird fest verdrahtet.** Die Liste
/// der kostenlosen Modelle rotiert – Anbieter kommen dazu und fallen weg. Ein
/// eingebauter Name wäre irgendwann tot, und die App wüsste es nicht.
///
/// Der User bekommt von alldem nichts mit. Er soll nie ein Modell auswählen.
abstract final class OpenRouterModelChoice {
  /// Wie viele Modelle die App in Reserve hält.
  ///
  /// Das erste kann am Ratenlimit hängen oder gerade abgeschaltet worden
  /// sein. Dann geht es still zum nächsten – erst wenn keins mehr übrig ist,
  /// fällt der ganze Weg auf die nächste Stufe zurück.
  static const int candidateCount = 4;

  /// Modelle, die zwar Text liefern, aber keine Aufgabe der App erledigen:
  /// Sicherheitsfilter, Einbettungen, Umsortierer, Sprachausgabe.
  ///
  /// Ohne diese Liste wählt die App irgendwann einen Inhaltsklassifizierer
  /// und bekommt „safe" zurück, wo eine Nachricht stehen sollte.
  static const List<String> _unsuitable = [
    'guard',
    'safety',
    'moderation',
    'embed',
    'rerank',
    'tts',
    'stt',
    'whisper',
    'transcribe',
  ];

  /// Sehr kleine Modelle. Für Formulierungen reichen sie, fürs Ableiten von
  /// Ziel und Ansprechpartner oft nicht (Konzept, Abschnitt 17a). Sie werden
  /// nicht ausgeschlossen, nur nach hinten sortiert.
  static final RegExp _tiny = RegExp(r'(?:^|[-/])(?:\d(?:\.\d)?b|nano|tiny)\b');

  /// Die Kandidaten in der Reihenfolge, in der sie versucht werden.
  ///
  /// [allowPaid] ist nur dann `true`, wenn der User bei OpenRouter selbst
  /// Guthaben aufgeladen hat. Ungefragt Geld ausgeben tut die App nicht.
  static List<OpenRouterModel> rank(
    List<OpenRouterModel> models, {
    bool allowPaid = false,
  }) {
    final usable =
        models
            .where((model) => model.isTextChat)
            .where((model) => allowPaid || model.isFree)
            .where((model) => !_isUnsuitable(model.id))
            .toList()
          ..sort(_byQuality);

    return usable.take(candidateCount).toList();
  }

  static bool _isUnsuitable(String id) {
    final lower = id.toLowerCase();
    return _unsuitable.any(lower.contains);
  }

  /// Grobe Rangfolge, keine Wissenschaft.
  ///
  /// Kostenlos zuerst – auch wenn Guthaben da ist, wird es nur ausgegeben,
  /// wenn nichts Kostenloses mehr trägt. Danach entscheidet die Kontextlänge:
  /// Sie ist die einzige Größe im Verzeichnis, die halbwegs mit der
  /// Leistungsfähigkeit mitläuft. Winzige Modelle rutschen ans Ende.
  static int _byQuality(OpenRouterModel a, OpenRouterModel b) {
    if (a.isFree != b.isFree) return a.isFree ? -1 : 1;

    final aTiny = _tiny.hasMatch(a.id.toLowerCase());
    final bTiny = _tiny.hasMatch(b.id.toLowerCase());
    if (aTiny != bTiny) return aTiny ? 1 : -1;

    final byContext = b.contextLength.compareTo(a.contextLength);
    if (byContext != 0) return byContext;

    // Letzter Vergleich, damit die Reihenfolge zwischen zwei Läufen gleich
    // bleibt und ein Fehler reproduzierbar ist.
    return a.id.compareTo(b.id);
  }
}
