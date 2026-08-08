/// Wie der Anruf ausgegangen ist.
///
/// Die Nachbereitung ist bewusst **minimal**: eine Frage, zwei Antworten
/// (Konzept, Abschnitt 8, Schritt 8).
enum CallOutcome {
  /// Noch nicht nachbereitet.
  open,

  /// „Hat geklappt?" – Ja.
  succeeded,

  /// Nein. Die App bietet Weiterhilfe an, drängt aber nicht.
  failed,
}

/// Ein vorbereiteter Anruf.
class CallPlan {
  const CallPlan({
    required this.id,
    required this.entryId,
    required this.category,
    required this.createdAt,
    this.situation = '',
    this.goal,
    this.contactName,
    this.contactNumber,
    this.talkingPoints = const [],
    this.note,
    this.outcome = CallOutcome.open,
    this.calledAt,
  });

  final String id;
  final String entryId;

  /// „Arzt", „Versicherung", „Handwerker" – vom User gewählt.
  final String category;

  /// Was los ist, in eigenen Worten.
  final String situation;

  /// Das abgeleitete Ziel, z.B. „Termin beim Optiker für Sehtest".
  final String? goal;

  final String? contactName;
  final String? contactNumber;

  /// Der Leitfaden – **kein Skript zum Ablesen**, sondern Merkposten
  /// (Konzept, Abschnitt 8, Schritt 5).
  final List<String> talkingPoints;

  /// Notiz aus oder nach dem Gespräch.
  final String? note;

  final CallOutcome outcome;
  final DateTime createdAt;
  final DateTime? calledAt;

  /// Ob genug da ist, um den Anruf zu starten.
  bool get isReadyToCall =>
      contactNumber != null &&
      contactNumber!.trim().isNotEmpty &&
      talkingPoints.isNotEmpty;

  bool get isDone => outcome != CallOutcome.open;

  CallPlan copyWith({
    String? situation,
    String? goal,
    String? contactName,
    String? contactNumber,
    List<String>? talkingPoints,
    String? note,
    CallOutcome? outcome,
    DateTime? calledAt,
  }) {
    return CallPlan(
      id: id,
      entryId: entryId,
      category: category,
      situation: situation ?? this.situation,
      goal: goal ?? this.goal,
      contactName: contactName ?? this.contactName,
      contactNumber: contactNumber ?? this.contactNumber,
      talkingPoints: talkingPoints ?? this.talkingPoints,
      note: note ?? this.note,
      outcome: outcome ?? this.outcome,
      createdAt: createdAt,
      calledAt: calledAt ?? this.calledAt,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'entry_id': entryId,
    'category': category,
    'situation': situation,
    'goal': goal,
    'contact_name': contactName,
    'contact_number': contactNumber,
    // Ein Punkt pro Zeile – einfacher als JSON und für Menschen lesbar,
    // falls die Datenbank mal von Hand angesehen wird.
    'talking_points': talkingPoints.join('\n'),
    'note': note,
    'outcome': outcome.name,
    'created_at': createdAt.millisecondsSinceEpoch,
    'called_at': calledAt?.millisecondsSinceEpoch,
  };

  static CallPlan fromRow(Map<String, Object?> row) {
    final rawPoints = (row['talking_points'] as String?) ?? '';

    return CallPlan(
      id: row['id']! as String,
      entryId: row['entry_id']! as String,
      category: row['category']! as String,
      situation: (row['situation'] as String?) ?? '',
      goal: row['goal'] as String?,
      contactName: row['contact_name'] as String?,
      contactNumber: row['contact_number'] as String?,
      talkingPoints: rawPoints.isEmpty
          ? const []
          : rawPoints.split('\n').where((line) => line.isNotEmpty).toList(),
      note: row['note'] as String?,
      outcome: CallOutcome.values.firstWhere(
        (value) => value.name == row['outcome'],
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      calledAt: row['called_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['called_at']! as int),
    );
  }
}
