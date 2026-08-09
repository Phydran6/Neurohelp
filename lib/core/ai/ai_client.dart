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

  /// Führt eine Aufgabe aus und liefert den Antworttext.
  ///
  /// Wirft [AiUnavailableException], wenn die KI nicht erreichbar ist – der
  /// aufrufende Ablauf fällt dann auf seinen lokalen Weg zurück.
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  });
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

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) {
    throw const AiUnavailableException('KI ist in den Einstellungen aus.');
  }
}
