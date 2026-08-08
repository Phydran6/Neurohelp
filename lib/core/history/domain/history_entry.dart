/// Feature, zu dem ein Historien-Eintrag gehört (Konzept, Abschnitt 12).
enum HistoryFeature { call, appointment, message, task }

/// Zustand eines Vorgangs.
///
/// [handedOver] deckt den Fall aus Abschnitt 10 ab: Die Nachricht wurde an die
/// System-App übergeben, ob sie gesendet wurde, kann die App nicht wissen.
enum HistoryStatus { open, active, handedOver, done, dropped }

/// Ein Vorgang in der Historie – das Rückgrat der App.
///
/// Jedes Feature startet mit einem Historie-Check gegen diese Einträge, bevor
/// der User etwas eingeben muss.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.feature,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.contact,
    this.closedAt,
    this.followUpCount = 0,
    this.lastFollowUpAt,
  });

  final String id;
  final HistoryFeature feature;

  /// Worum es geht – „Termin beim Optiker", „Mail an die Krankenkasse".
  final String title;

  /// Ansprechpartner, sofern bekannt.
  final String? contact;

  final HistoryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? closedAt;

  /// Wie oft schon sanft nachgefragt wurde. Bei [maxFollowUps] ist Schluss –
  /// kein Endlos-Gebettel (Konzept, Abschnitt 10).
  final int followUpCount;
  final DateTime? lastFollowUpAt;

  /// Obergrenze für Nachfragen. Danach bleibt der Vorgang still liegen.
  static const int maxFollowUps = 3;

  bool get isOpen =>
      status == HistoryStatus.open ||
      status == HistoryStatus.active ||
      status == HistoryStatus.handedOver;

  /// Ob überhaupt noch nachgefragt werden darf.
  bool get mayFollowUp => isOpen && followUpCount < maxFollowUps;

  HistoryEntry copyWith({
    String? title,
    String? contact,
    HistoryStatus? status,
    DateTime? updatedAt,
    DateTime? closedAt,
    int? followUpCount,
    DateTime? lastFollowUpAt,
    bool clearClosedAt = false,
  }) {
    return HistoryEntry(
      id: id,
      feature: feature,
      title: title ?? this.title,
      contact: contact ?? this.contact,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      closedAt: clearClosedAt ? null : (closedAt ?? this.closedAt),
      followUpCount: followUpCount ?? this.followUpCount,
      lastFollowUpAt: lastFollowUpAt ?? this.lastFollowUpAt,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'feature': feature.name,
      'title': title,
      'contact': contact,
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'closed_at': closedAt?.millisecondsSinceEpoch,
      'follow_up_count': followUpCount,
      'last_follow_up_at': lastFollowUpAt?.millisecondsSinceEpoch,
    };
  }

  static HistoryEntry fromRow(Map<String, Object?> row) {
    return HistoryEntry(
      id: row['id']! as String,
      feature: _enumByName(HistoryFeature.values, row['feature']! as String),
      title: row['title']! as String,
      contact: row['contact'] as String?,
      status: _enumByName(HistoryStatus.values, row['status']! as String),
      createdAt: _date(row['created_at'])!,
      updatedAt: _date(row['updated_at'])!,
      closedAt: _date(row['closed_at']),
      followUpCount: (row['follow_up_count'] as int?) ?? 0,
      lastFollowUpAt: _date(row['last_follow_up_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value as int);

  static T _enumByName<T extends Enum>(List<T> values, String name) {
    return values.firstWhere((value) => value.name == name);
  }
}
