import 'message_draft.dart';

/// Die Schritte beim Schreiben einer Nachricht (Konzept, Abschnitt 10).
///
/// Die Reihenfolge ist bewusst festgelegt und nicht verhandelbar:
/// **Inhalt zuerst, Empfänger später** – der richtige Empfänger ergibt sich
/// oft erst aus dem Inhalt.
enum MessageStep {
  /// Worum geht es? Kein „An wen?" an dieser Stelle.
  subject,

  /// Die App gräbt zuerst in der Historie. Erst wenn sie nichts findet,
  /// kommen sanfte Rückfragen als Gedächtnisstütze.
  historyCheck,

  /// „Das geht wohl an deine Krankenkasse." – Typ vor Adresse. Das ist
  /// zugleich Fehlerschutz.
  recipientType,

  /// Jetzt erst die konkrete Adresse bzw. der Formular-Link.
  recipient,

  /// „Schaffst du's allein oder brauchst du Hilfe?"
  compose,

  /// Die fertige Nachricht: direkt senden oder nochmal bearbeiten.
  /// Kein Zwang in beide Richtungen.
  review,
}

/// Zustand des Nachrichten-Ablaufs. Reine Logik, ohne UI und ohne Speicher.
class MessageFlow {
  const MessageFlow({
    required this.draft,
    this.step = MessageStep.subject,
    this.subjectDeferred = false,
  });

  final MessageStep step;
  final MessageDraft draft;

  /// „Ich weiß nur, dass da was war." – der User kommt am Betreff nicht
  /// weiter und hat das ausdrücklich gesagt (Konzept, Abschnitt 10,
  /// Schritt 2).
  ///
  /// Ohne das blieb der Ablauf am ersten Feld stehen: kein Text, kein Weiter.
  /// Genau die Situation, für die es die App gibt. Der Betreff ergibt sich
  /// dann später aus dem, was geschrieben wird.
  final bool subjectDeferred;

  static const List<MessageStep> _order = MessageStep.values;

  /// Ob der aktuelle Schritt erledigt ist.
  bool get canAdvance => switch (step) {
    MessageStep.subject => draft.subject.trim().isNotEmpty || subjectDeferred,
    // Der Historie-Check ist Arbeit der App, nicht des Users – er blockiert
    // nie.
    MessageStep.historyCheck => true,
    MessageStep.recipientType => _isFilled(draft.recipientType),
    MessageStep.recipient => _isFilled(draft.recipient),
    MessageStep.compose => draft.body.trim().isNotEmpty,
    MessageStep.review => draft.isReadyToSend,
  };

  MessageStep? get nextStep {
    final index = _order.indexOf(step);
    return index + 1 < _order.length ? _order[index + 1] : null;
  }

  /// Geht einen Schritt weiter.
  ///
  /// Wirft [StateError], solange der aktuelle Schritt offen ist.
  MessageFlow advance() {
    if (!canAdvance) {
      throw StateError('Schritt $step ist noch nicht abgeschlossen.');
    }
    final next = nextStep;
    return next == null ? this : _copyWith(step: next);
  }

  /// Zurück – ohne Datenverlust, der Entwurf bleibt wie er ist.
  MessageFlow back() {
    final index = _order.indexOf(step);
    if (index == 0) return this;
    return _copyWith(step: _order[index - 1]);
  }

  MessageFlow withDraft(MessageDraft value) => _copyWith(draft: value);

  /// „Weiß ich noch nicht" – der Ablauf geht trotzdem weiter.
  MessageFlow deferSubject() => _copyWith(subjectDeferred: true);

  /// Springt direkt zum Bearbeiten zurück – der Ausweg aus der Vorschau.
  MessageFlow editAgain() => _copyWith(step: MessageStep.compose);

  MessageFlow _copyWith({
    MessageDraft? draft,
    MessageStep? step,
    bool? subjectDeferred,
  }) => MessageFlow(
    draft: draft ?? this.draft,
    step: step ?? this.step,
    subjectDeferred: subjectDeferred ?? this.subjectDeferred,
  );

  static bool _isFilled(String? value) =>
      value != null && value.trim().isNotEmpty;
}
