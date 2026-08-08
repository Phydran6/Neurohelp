import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/schema.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../core/history/domain/history_event.dart';
import '../../../core/history/domain/history_repository.dart';
import '../domain/call_plan.dart';

/// Anrufe vorbereiten, durchführen und nachbereiten.
class SqliteCallRepository {
  SqliteCallRepository(
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

  /// Legt einen Anruf an und eröffnet dafür einen Historien-Vorgang.
  Future<CallPlan> create({required String category, String? topic}) async {
    final entry = await _history.startEntry(
      feature: HistoryFeature.call,
      title: topic == null || topic.trim().isEmpty ? category : topic,
      contact: category,
    );

    final plan = CallPlan(
      id: _newId(),
      entryId: entry.id,
      category: category,
      createdAt: _now(),
    );

    await _db.insert(DbSchema.tableCalls, plan.toRow());
    return plan;
  }

  Future<CallPlan?> byId(String id) async {
    final rows = await _db.query(
      DbSchema.tableCalls,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CallPlan.fromRow(rows.first);
  }

  /// Frühere Anrufe derselben Kategorie – die Grundlage für den
  /// Historie-Check: „Geht's um [Thema vom letzten Mal]?"
  Future<List<CallPlan>> previousInCategory(
    String category, {
    int limit = 5,
  }) async {
    final rows = await _db.query(
      DbSchema.tableCalls,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(CallPlan.fromRow).toList();
  }

  Future<CallPlan> save(CallPlan plan) async {
    await _db.update(
      DbSchema.tableCalls,
      plan.toRow(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
    return plan;
  }

  /// Hält fest, dass der Anruf läuft.
  Future<CallPlan> markCalled(String id) async {
    final plan = await _require(id);
    if (!plan.isReadyToCall) {
      throw StateError('Ohne Nummer und Stichpunkte kein Anruf.');
    }

    final updated = await save(plan.copyWith(calledAt: _now()));

    await _history.updateStatus(plan.entryId, HistoryStatus.active);
    await _history.logEvent(
      plan.entryId,
      HistoryEventKind.statusChanged,
      note: plan.goal ?? plan.category,
      data: {'contact': plan.contactName ?? plan.contactNumber},
    );

    return updated;
  }

  /// Die Nachbereitung: eine Frage, zwei Antworten.
  ///
  /// [note] gibt es, weil Notizen auf iOS erst hier erfasst werden können –
  /// eine Live Activity ist nicht frei beschreibbar (Konzept, Abschnitt 8a).
  Future<CallPlan> finish(
    String id, {
    required bool succeeded,
    String? note,
  }) async {
    final plan = await _require(id);

    final updated = await save(
      plan.copyWith(
        outcome: succeeded ? CallOutcome.succeeded : CallOutcome.failed,
        note: note,
      ),
    );

    if (note != null && note.trim().isNotEmpty) {
      await _history.logEvent(
        plan.entryId,
        HistoryEventKind.noteAdded,
        note: note,
      );
    }

    if (succeeded) {
      await _history.closeEntry(plan.entryId, note: 'Anruf hat geklappt.');
    } else {
      // Nicht geklappt: der Vorgang bleibt offen, damit die App später
      // Weiterhilfe anbieten kann. Kein Drängen.
      await _history.updateStatus(
        plan.entryId,
        HistoryStatus.open,
        note: 'Anruf hat nicht geklappt.',
      );
    }

    return updated;
  }

  Future<CallPlan> _require(String id) async {
    final plan = await byId(id);
    if (plan == null) {
      throw StateError('Kein Anruf mit der Id $id');
    }
    return plan;
  }
}
