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
  ///
  /// Zieht dabei den Historien-Vorgang nach: Der entsteht beim Anlegen mit
  /// leerem Titel, weil der Betreff da noch nicht getippt ist. Ohne dieses
  /// Nachziehen hieße **jede** Nachricht in der Historie „Ohne Titel".
  Future<MessageDraft> save(MessageDraft draft) async {
    await _db.update(
      DbSchema.tableMessages,
      draft.toRow(),
      where: 'id = ?',
      whereArgs: [draft.id],
    );

    final subject = draft.subject.trim();
    if (subject.isNotEmpty) {
      await _history.rename(
        draft.entryId,
        subject,
        contact: draft.recipient ?? draft.recipientType,
      );
    }

    if (draft.recipient != null) {
      await _history.logEvent(
        draft.entryId,
        HistoryEventKind.noteAdded,
        note: draft.recipient,
      );
    }
    return draft;
  }

  /// Wirft einen Entwurf weg, aus dem nie etwas wurde.
  ///
  /// Der Vorgang entsteht beim Antippen von „Neue Nachricht", nicht erst beim
  /// Tippen. Wer es sich sofort anders überlegt, soll dafür keinen leeren
  /// Eintrag in seiner Historie behalten.
  Future<void> discardIfEmpty(String id) async {
    final draft = await byId(id);
    if (draft == null) return;
    if (draft.subject.trim().isNotEmpty || draft.body.trim().isNotEmpty) return;
    if (draft.state != MessageState.draft) return;

    await _db.delete(DbSchema.tableMessages, where: 'id = ?', whereArgs: [id]);
    await _history.deleteEntry(draft.entryId);
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

  /// Angefangene Nachrichten, die noch nicht raus sind.
  ///
  /// Das ist der Historie-Check am Anfang des Features: Wer neulich etwas
  /// angefangen und weggelegt hat, findet es hier wieder, ohne sich den
  /// Betreff gemerkt zu haben. Nachrichten ohne Betreff sind Fehlstarts und
  /// bleiben draußen.
  Future<List<MessageDraft>> unfinished({int limit = 10}) async {
    final rows = await _db.query(
      DbSchema.tableMessages,
      where: "state in (?, ?) and trim(subject) <> ''",
      whereArgs: [MessageState.draft.name, MessageState.notSent.name],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(MessageDraft.fromRow).toList();
  }

  /// Nachrichten, bei denen offen ist, ob sie rausgingen – und bei denen die
  /// App noch fragen **darf**.
  ///
  /// Konzept, Abschnitt 10, Schritt 7: höchstens drei Nachfragen insgesamt,
  /// ruhig verteilt, danach hört die App von selbst auf. Vorher hing die
  /// Karte allein am Zustand `handedOver` – wer nie „Ja" oder „Nein" gedrückt
  /// hat, bekam sie bei **jedem** Öffnen wieder. Genau das Endlos-Gebettel,
  /// das das Konzept ausschließt.
  Future<List<MessageDraft>> awaitingConfirmation() async {
    final due = await _history.entriesDueForFollowUp(
      feature: HistoryFeature.message,
      limit: 50,
    );
    if (due.isEmpty) return const [];

    final dueIds = {for (final entry in due) entry.id};
    final rows = await _db.query(
      DbSchema.tableMessages,
      where: 'state = ?',
      whereArgs: [MessageState.handedOver.name],
      orderBy: 'handed_over_at ASC',
    );

    return rows
        .map(MessageDraft.fromRow)
        .where((draft) => dueIds.contains(draft.entryId))
        .toList();
  }

  /// Vermerkt, dass die App zu dieser Nachricht nachgefragt hat.
  ///
  /// Erhöht den Zähler in der Historie. Nach [HistoryEntry.maxFollowUps]
  /// kommt die Frage nicht wieder; der Vorgang bleibt als offene Aufgabe
  /// liegen, ohne Schuld und ohne Erinnerung.
  Future<void> registerAsked(MessageDraft draft) =>
      _history.registerFollowUp(draft.entryId);

  Future<MessageDraft> _require(String id) async {
    final draft = await byId(id);
    if (draft == null) {
      throw StateError('Keine Nachricht mit der Id $id');
    }
    return draft;
  }
}
