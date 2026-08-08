import 'dart:convert';

/// Art eines protokollierten Ereignisses.
///
/// „Alles wird geloggt" ist Designprinzip 9 – damit die App sagen kann:
/// *„Du warst hier stehen geblieben."*
enum HistoryEventKind {
  created,
  stepDone,
  stepAdded,
  noteAdded,
  statusChanged,
  handedOver,
  followUpAsked,
  followUpAnswered,
  closed,
}

/// Ein einzelner Eintrag im lückenlosen Protokoll eines Vorgangs.
class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.entryId,
    required this.kind,
    required this.createdAt,
    this.note,
    this.data = const {},
  });

  final String id;
  final String entryId;
  final HistoryEventKind kind;
  final DateTime createdAt;

  /// Kurze, für den User lesbare Notiz.
  final String? note;

  /// Feature-spezifische Zusatzdaten.
  final Map<String, Object?> data;

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'entry_id': entryId,
      'kind': kind.name,
      'note': note,
      'data': data.isEmpty ? null : jsonEncode(data),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  static HistoryEvent fromRow(Map<String, Object?> row) {
    final rawData = row['data'] as String?;

    return HistoryEvent(
      id: row['id']! as String,
      entryId: row['entry_id']! as String,
      kind: HistoryEventKind.values.firstWhere(
        (value) => value.name == row['kind'],
      ),
      note: row['note'] as String?,
      data: rawData == null
          ? const {}
          : (jsonDecode(rawData) as Map<String, dynamic>),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    );
  }
}
