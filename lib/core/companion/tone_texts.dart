import '../ai/ai_client.dart';

/// Die Texte, die sich mit dem gewählten Ton ändern (Konzept, Abschnitt 5).
///
/// Anlass: Die Frage „Wie soll ich mit dir reden?" kam im Onboarding, wurde
/// gespeichert – und danach klang die App überall gleich. Eine Frage ohne
/// sichtbare Folge ist schlimmer als keine.
///
/// Hier steht **nur**, was sich mit dem Ton wirklich unterscheidet. Alles
/// andere bleibt eine feste Zeichenkette an Ort und Stelle; ein Register für
/// jeden Satz der App wäre nicht zu pflegen.
class ToneTexts {
  const ToneTexts(this.tone);

  final AiTone tone;

  String _pick(String locker, String neutral, String sachlich) =>
      switch (tone) {
        AiTone.locker => locker,
        AiTone.neutral => neutral,
        AiTone.sachlich => sachlich,
      };

  /// Der große Knopf auf der Startseite.
  String get startButton => _pick('Los geht’s', 'Anfangen', 'Auswahl öffnen');

  /// Die Überschrift im Hauptmenü.
  String get menuTitle => _pick(
    'Was geht? Womit kann ich helfen?',
    'Womit kann ich helfen?',
    'Auswahl treffen.',
  );

  /// Über dem nächsten offenen Schritt im Fokus-Modus.
  String get nextStepLabel =>
      _pick('Als Nächstes', 'Als Nächstes', 'Nächster Schritt');

  /// Wenn eine Aufgabe durch ist. Feststellung, kein Lob.
  String get allDone =>
      _pick('Alles abgehakt.', 'Alles erledigt.', 'Keine offenen Schritte.');

  /// Überschrift über gefundenen offenen Vorgängen.
  String get historyFound =>
      _pick('Da war noch was', 'Es ist noch etwas offen', 'Offene Vorgänge');

  /// Wenn der Historie-Check nichts gefunden hat.
  String get historyEmpty => _pick(
    'Ich hab nachgeschaut – da ist nichts Offenes.',
    'Ich habe nachgesehen. Es ist nichts offen.',
    'Historie geprüft: nichts offen.',
  );

  /// Der Knopf, der die KI um einen Vorschlag bittet.
  String get askAi =>
      _pick('Soll ich was vorschlagen?', 'Vorschlag holen', 'Vorschlag');

  /// Während die KI arbeitet. Kein Ladekringel – der flackert nur.
  String get aiWorking =>
      _pick('Ich denk kurz nach …', 'Einen Moment …', 'Wird erzeugt …');

  /// Über der Liste der KI-Vorschläge.
  String get aiResultTitle =>
      _pick('Mein Vorschlag – nimm, was passt', 'Vorschlag', 'Vorschlag');
}
