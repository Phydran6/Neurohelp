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
  const MessageFlow({required this.draft, this.step = MessageStep.subject});

  final MessageStep step;
  final MessageDraft draft;

  static const List<MessageStep> _order = MessageStep.values;

  /// Ob der aktuelle Schritt erledigt ist.
  bool get canAdvance => switch (step) {
    MessageStep.subject => draft.subject.trim().isNotEmpty,
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
    return next == null ? this : MessageFlow(draft: draft, step: next);
  }

  /// Zurück – ohne Datenverlust, der Entwurf bleibt wie er ist.
  MessageFlow back() {
    final index = _order.indexOf(step);
    if (index == 0) return this;
    return MessageFlow(draft: draft, step: _order[index - 1]);
  }

  MessageFlow withDraft(MessageDraft value) =>
      MessageFlow(draft: value, step: step);

  /// Springt direkt zum Bearbeiten zurück – der Ausweg aus der Vorschau.
  MessageFlow editAgain() =>
      MessageFlow(draft: draft, step: MessageStep.compose);

  static bool _isFilled(String? value) =>
      value != null && value.trim().isNotEmpty;
}
