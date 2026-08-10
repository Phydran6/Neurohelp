/// Aufgabentypen, die die KI-Schicht kennt.
///
/// Die App kennt **keinen** Anbieter und **kein** Modell – nur die Aufgabe.
/// Welches Modell welchen Anbieters antwortet, entscheidet ausschließlich die
/// Backend-Schicht (Konzept, Abschnitt 17).
enum AiTask {
  /// Eine Aufgabe in Mikroschritte zerlegen.
  splitTask('task.split'),

  /// Aus Stichpunkten eine fertige Nachricht formulieren.
  composeMessage('message.compose'),

  /// Ziel, Ansprechpartner und Stichpunkte für ein Telefonat vorbereiten.
  prepareCall('call.prepare'),

  /// Den wahrscheinlichsten Buchungsweg für einen Termin vorschlagen.
  routeAppointment('appointment.route'),

  /// Eine freie Frage zur App beantworten, wenn die festen FAQ-Antworten
  /// nicht passen.
  answerHelp('help.ask');

  const AiTask(this.wireName);

  /// Bezeichner, den das Backend erwartet.
  final String wireName;
}

/// Tonfall aus den Einstellungen (Konzept, Abschnitt 5).
enum AiTone { locker, neutral, sachlich }

/// Zugang zur KI – die einzige Schnittstelle, die Features benutzen dürfen.
///
/// Es gibt bewusst keine Methode, um Anbieter oder Modell zu wählen. Ein
/// Anbieterwechsel ist eine Backend-Änderung, nie eine App-Änderung.
abstract interface class AiClient {
  /// Ob KI überhaupt genutzt werden darf (KI-Toggle aus dem Onboarding).
  ///
  /// Ist das `false`, muss jeder Ablauf einen vollständig lokalen Weg haben.
  bool get isEnabled;

  /// Übernimmt den KI-Schalter aus den Einstellungen **zur Laufzeit**.
  ///
  /// Ohne das wirkt ein Umlegen des Schalters erst nach einem Neustart der
  /// App – für den User heißt das: es passiert nichts.
  void setEnabled({required bool enabled});

  /// Führt eine Aufgabe aus und liefert den Antworttext.
  ///
  /// Wirft [AiUnavailableException], wenn die KI nicht erreichbar ist – der
  /// aufrufende Ablauf fällt dann auf seinen lokalen Weg zurück.
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  });

  /// Fragt einmal beim Backend nach, ob die KI gerade antwortet.
  ///
  /// Damit der User nach dem Umlegen des Schalters eine echte Rückmeldung
  /// bekommt statt eines stummen Schalters. Wirft
  /// [AiUnavailableException] mit einem Grund, den man anzeigen kann.
  Future<void> probe();
}

/// Die KI ist gerade nicht nutzbar – kein Fehler des Users.
class AiUnavailableException implements Exception {
  const AiUnavailableException(this.reason);

  final String reason;

  @override
  String toString() => 'AiUnavailableException: $reason';
}

/// Ersatz-Implementierung für den KI-losen Betrieb.
///
/// Wird eingesetzt, wenn der User im Onboarding gegen KI entschieden hat.
/// Jeder Aufruf schlägt fehl – Features müssen das abfangen und ihren lokalen
/// Weg gehen.
class DisabledAiClient implements AiClient {
  const DisabledAiClient();

  @override
  bool get isEnabled => false;

  /// Ohne eingerichtetes Backend lässt sich die KI nicht anschalten. Der
  /// Schalter in den Einstellungen darf trotzdem existieren – er speichert
  /// die Absicht, und sobald ein Backend da ist, greift sie.
  @override
  void setEnabled({required bool enabled}) {}

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) {
    throw const AiUnavailableException('KI ist in den Einstellungen aus.');
  }

  @override
  Future<void> probe() async {
    throw const AiUnavailableException(
      'Für diese App ist kein KI-Backend hinterlegt.',
    );
  }
}

/// Zerlegt eine KI-Antwort in einzelne Vorschläge.
///
/// Die Modelle liefern trotz Prompt gern Nummerierungen, Spiegelstriche oder
/// eine Leerzeile zwischendurch. Das hier ist die eine Stelle, die das
/// aufräumt – nicht jede Seite für sich.
abstract final class AiSuggestions {
  static final RegExp _bullet = RegExp(r'^\s*(?:[-*•·]|\d+[.)])\s*');

  static List<String> linesOf(String answer) {
    return answer
        .split('\n')
        .map((line) => line.replaceFirst(_bullet, '').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }
}
