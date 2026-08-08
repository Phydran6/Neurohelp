import 'message_framing.dart';

/// Auf welchem Weg die Nachricht rausgeht.
enum MessageChannel {
  email,

  /// Kontaktformular auf einer Webseite. Die konkrete Ansteuerung ist laut
  /// Konzept (Abschnitt 21) noch offen.
  webForm,

  /// Freie Nachricht, z.B. Messenger.
  free,
}

/// Wer die Nachricht formuliert (Konzept, Abschnitt 10, Schritt 4).
enum ComposeMode {
  /// „Schaffst du's allein?" – der User schreibt den Inhalt, der Rahmen
  /// wird automatisch ergänzt.
  self,

  /// „Brauchst du Hilfe?" – die KI formuliert aus Stichpunkten.
  assisted,
}

/// Wie weit die Nachricht ist.
///
/// Die App kann **nicht** wissen, ob wirklich gesendet wurde: sobald der User
/// in der System-Mail-App ist, gibt es keinen Rückkanal (Konzept,
/// Abschnitt 10, Schritt 6). Deshalb der Zwischenzustand [handedOver].
enum MessageState {
  /// In Arbeit.
  draft,

  /// An die System-App übergeben. Ob gesendet wurde, ist offen.
  handedOver,

  /// Der User hat auf Nachfrage bestätigt, dass es rausging.
  confirmed,

  /// Der User hat verneint – der Vorgang bleibt als offene Aufgabe liegen.
  notSent,
}

/// Eine Nachricht in Arbeit.
class MessageDraft {
  const MessageDraft({
    required this.id,
    required this.entryId,
    required this.subject,
    required this.createdAt,
    this.channel = MessageChannel.email,
    this.recipientType,
    this.recipient,
    this.body = '',
    this.composeMode = ComposeMode.self,
    this.state = MessageState.draft,
    this.handedOverAt,
  });

  final String id;

  /// Der Historien-Vorgang dazu.
  final String entryId;

  /// Worum es geht. Kommt zuerst – **vor** dem Empfänger, weil der sich oft
  /// erst aus dem Inhalt ergibt (Konzept, Abschnitt 10, Schritt 1).
  final String subject;

  final MessageChannel channel;

  /// Erst der Typ: „Das geht wohl an deine Krankenkasse."
  final String? recipientType;

  /// Dann erst der konkrete Kontakt – Adresse oder Formular-Link.
  final String? recipient;

  /// Der reine Inhalt, ohne Floskel-Rahmen.
  final String body;

  final ComposeMode composeMode;
  final MessageState state;
  final DateTime createdAt;
  final DateTime? handedOverAt;

  /// Der fertige Text inklusive Anrede und Grußformel.
  String fullText({String? senderName}) =>
      MessageFraming.wrap(body, senderName: senderName);

  /// Ob die Nachricht abgeschickt werden kann.
  bool get isReadyToSend => body.trim().isNotEmpty && recipient != null;

  /// Ob die App später noch einmal sanft nachfragen soll.
  bool get needsFollowUp => state == MessageState.handedOver;

  MessageDraft copyWith({
    String? subject,
    MessageChannel? channel,
    String? recipientType,
    String? recipient,
    String? body,
    ComposeMode? composeMode,
    MessageState? state,
    DateTime? handedOverAt,
  }) {
    return MessageDraft(
      id: id,
      entryId: entryId,
      subject: subject ?? this.subject,
      channel: channel ?? this.channel,
      recipientType: recipientType ?? this.recipientType,
      recipient: recipient ?? this.recipient,
      body: body ?? this.body,
      composeMode: composeMode ?? this.composeMode,
      state: state ?? this.state,
      createdAt: createdAt,
      handedOverAt: handedOverAt ?? this.handedOverAt,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'entry_id': entryId,
    'subject': subject,
    'channel': channel.name,
    'recipient_type': recipientType,
    'recipient': recipient,
    'body': body,
    'compose_mode': composeMode.name,
    'state': state.name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'handed_over_at': handedOverAt?.millisecondsSinceEpoch,
  };

  static MessageDraft fromRow(Map<String, Object?> row) => MessageDraft(
    id: row['id']! as String,
    entryId: row['entry_id']! as String,
    subject: row['subject']! as String,
    channel: _byName(MessageChannel.values, row['channel']! as String),
    recipientType: row['recipient_type'] as String?,
    recipient: row['recipient'] as String?,
    body: (row['body'] as String?) ?? '',
    composeMode: _byName(ComposeMode.values, row['compose_mode']! as String),
    state: _byName(MessageState.values, row['state']! as String),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    handedOverAt: row['handed_over_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['handed_over_at']! as int),
  );

  static T _byName<T extends Enum>(List<T> values, String name) =>
      values.firstWhere((value) => value.name == name);
}
