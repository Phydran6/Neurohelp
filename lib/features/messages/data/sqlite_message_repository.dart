import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/schema.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../core/history/domain/history_event.dart';
import '../../../core/history/domain/history_repository.dart';
import '../domain/message_draft.dart';

/// Nachrichten anlegen, speichern und nachverfolgen.
///
/// Die Nachverfolgung ist der heikle Teil: Sobald der User in der
/// System-Mail-App ist, gibt es **keinen Rückkanal** (Konzept, Abschnitt 10,
/// Schritt 6). Die App kann nur festhalten, dass sie übergeben hat, und
/// später sanft nachfragen.
class SqliteMessageRepository {
  SqliteMessageRepository(
    this._db,
    this._history, {
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _now = clock ?? DateTime.now,
       _newId = idGenerator ?? const Uuid().v4;

  final Database _db;
  final HistoryRepository _history;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Legt eine Nachricht an und eröffnet dafür einen Historien-Vorgang.
  Future<MessageDraft> create({
    required String subject,
    MessageChannel channel = MessageChannel.email,
  }) async {
    final entry = await _history.startEntry(
      feature: HistoryFeature.message,
      title: subject,
    );

    final draft = MessageDraft(
      id: _newId(),
      entryId: entry.id,
      subject: subject,
      channel: channel,
      createdAt: _now(),
    );

    await _db.insert(DbSchema.tableMessages, draft.toRow());
    return draft;
  }

  Future<MessageDraft?> byId(String id) async {
    final rows = await _db.query(
      DbSchema.tableMessages,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : MessageDraft.fromRow(rows.first);
  }

  /// Speichert Zwischenstände. Der Text geht nie verloren.
  Future<MessageDraft> save(MessageDraft draft) async {
    await _db.update(
      DbSchema.tableMessages,
      draft.toRow(),
      where: 'id = ?',
      whereArgs: [draft.id],
    );

    if (draft.recipient != null) {
      await _history.logEvent(
        draft.entryId,
        HistoryEventKind.noteAdded,
        note: draft.recipient,
      );
    }
    return draft;
  }

  /// Übergibt an die System-App.
  ///
  /// Ab hier weiß die App nicht mehr, was passiert. Der Vorgang wandert auf
  /// [HistoryStatus.handedOver] und wird später nachgefragt.
  Future<MessageDraft> handOver(String id) async {
    final draft = await _require(id);
    if (!draft.isReadyToSend) {
      throw StateError('Die Nachricht ist noch nicht fertig.');
    }

    final updated = draft.copyWith(
      state: MessageState.handedOver,
      handedOverAt: _now(),
    );

    await _db.update(
      DbSchema.tableMessages,
      updated.toRow(),
      where: 'id = ?',
      whereArgs: [id],
    );

    await _history.updateStatus(
      draft.entryId,
      HistoryStatus.handedOver,
      note: 'An die System-App übergeben.',
    );
    await _history.logEvent(
      draft.entryId,
      HistoryEventKind.handedOver,
      note: draft.recipient,
      data: {'channel': draft.channel.name},
    );

    return updated;
  }

  /// Antwort auf die sanfte Nachfrage „Hat das geklappt?".
  ///
  /// Bei `false` bleibt der Vorgang als **offene Aufgabe** liegen – kein
  /// Drängen, keine Schuld. Die Obergrenze von drei Nachfragen steckt in der
  /// Historie-Schicht.
  Future<MessageDraft> confirmSent(String id, {required bool sent}) async {
    final draft = await _require(id);

    final updated = draft.copyWith(
      state: sent ? MessageState.confirmed : MessageState.notSent,
    );

    await _db.update(
      DbSchema.tableMessages,
      updated.toRow(),
      where: 'id = ?',
      whereArgs: [id],
    );

    await _history.logEvent(
      draft.entryId,
      HistoryEventKind.followUpAnswered,
      data: {'sent': sent},
    );

    if (sent) {
      await _history.closeEntry(draft.entryId, note: 'Nachricht ist raus.');
    } else {
      await _history.updateStatus(draft.entryId, HistoryStatus.open);
    }

    return updated;
  }

  /// Nachrichten, bei denen offen ist, ob sie rausgingen.
  Future<List<MessageDraft>> awaitingConfirmation() async {
    final rows = await _db.query(
      DbSchema.tableMessages,
      where: 'state = ?',
      whereArgs: [MessageState.handedOver.name],
      orderBy: 'handed_over_at ASC',
    );
    return rows.map(MessageDraft.fromRow).toList();
  }

  Future<MessageDraft> _require(String id) async {
    final draft = await byId(id);
    if (draft == null) {
      throw StateError('Keine Nachricht mit der Id $id');
    }
    return draft;
  }
}
