import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../db/schema.dart';
import '../domain/history_entry.dart';
import '../domain/history_event.dart';
import '../domain/history_repository.dart';

/// SQLite-Umsetzung der Historie.
///
/// Jede schreibende Operation protokolliert sich selbst mit – das lückenlose
/// Logging ist keine Aufgabe der aufrufenden Features.
class SqliteHistoryRepository implements HistoryRepository {
  SqliteHistoryRepository(
    this._db, {
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _now = clock ?? DateTime.now,
       _newId = idGenerator ?? const Uuid().v4;

  final Database _db;
  final DateTime Function() _now;
  final String Function() _newId;

  static const _endStates = {HistoryStatus.done, HistoryStatus.dropped};

  @override
  Future<HistoryEntry> startEntry({
    required HistoryFeature feature,
    required String title,
    String? contact,
  }) async {
    final now = _now();
    final entry = HistoryEntry(
      id: _newId(),
      feature: feature,
      title: title,
      contact: contact,
      status: HistoryStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insert(DbSchema.tableEntries, entry.toRow());
    await logEvent(entry.id, HistoryEventKind.created, note: title);

    return entry;
  }

  @override
  Future<HistoryEntry?> entryById(String id) async {
    final rows = await _db.query(
      DbSchema.tableEntries,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : HistoryEntry.fromRow(rows.first);
  }

  @override
  Future<List<HistoryEntry>> openEntries({
    HistoryFeature? feature,
    int limit = 20,
  }) {
    final openStates = HistoryStatus.values
        .where((status) => !_endStates.contains(status))
        .map((status) => status.name)
        .toList();

    final placeholders = List.filled(openStates.length, '?').join(', ');
    final where = StringBuffer('status IN ($placeholders)');
    final args = <Object?>[...openStates];

    if (feature != null) {
      where.write(' AND feature = ?');
      args.add(feature.name);
    }

    return _queryEntries(where.toString(), args, limit);
  }

  @override
  Future<List<HistoryEntry>> recentEntries({
    HistoryFeature? feature,
    int limit = 20,
  }) {
    if (feature == null) {
      return _queryEntries(null, const [], limit);
    }
    return _queryEntries('feature = ?', [feature.name], limit);
  }

  @override
  Future<List<HistoryEntry>> search(
    String query, {
    HistoryFeature? feature,
    int limit = 20,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Future<List<HistoryEntry>>.value(const []);
    }

    // LIKE-Sonderzeichen entschärfen, damit eine Nutzereingabe wie „100%"
    // nicht alles zurückliefert.
    final escaped = trimmed
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');

    final where = StringBuffer(
      "(title LIKE ? ESCAPE '\\' OR contact LIKE ? ESCAPE '\\')",
    );
    final args = <Object?>['%$escaped%', '%$escaped%'];

    if (feature != null) {
      where.write(' AND feature = ?');
      args.add(feature.name);
    }

    return _queryEntries(where.toString(), args, limit);
  }

  @override
  Future<Map<HistoryFeature, ({int open, int total})>> countsByFeature() async {
    final openStates = HistoryStatus.values
        .where((status) => !_endStates.contains(status))
        .map((status) => status.name)
        .toList();
    final placeholders = List.filled(openStates.length, '?').join(', ');

    final rows = await _db.rawQuery(
      'SELECT feature, '
      'COUNT(*) AS total, '
      'SUM(CASE WHEN status IN ($placeholders) THEN 1 ELSE 0 END) AS open '
      'FROM ${DbSchema.tableEntries} GROUP BY feature',
      openStates,
    );

    final counts = <HistoryFeature, ({int open, int total})>{};
    for (final row in rows) {
      final name = row['feature'] as String?;
      final feature = HistoryFeature.values
          .where((value) => value.name == name)
          .firstOrNull;
      // Ein Feature, das es in dieser Version nicht mehr gibt, wird
      // übersprungen statt die ganze Übersicht zu sprengen.
      if (feature == null) continue;

      counts[feature] = (
        open: (row['open'] as int?) ?? 0,
        total: (row['total'] as int?) ?? 0,
      );
    }
    return counts;
  }

  @override
  Future<HistoryEntry> updateStatus(
    String entryId,
    HistoryStatus status, {
    String? note,
  }) async {
    final entry = await _require(entryId);
    final now = _now();

    final isEndState = _endStates.contains(status);
    final updated = entry.copyWith(
      status: status,
      updatedAt: now,
      closedAt: isEndState ? now : null,
      clearClosedAt: !isEndState,
    );

    await _write(updated);
    await logEvent(
      entryId,
      _endStates.contains(status)
          ? HistoryEventKind.closed
          : HistoryEventKind.statusChanged,
      note: note,
      data: {'from': entry.status.name, 'to': status.name},
    );

    return updated;
  }

  @override
  Future<HistoryEntry> rename(
    String entryId,
    String title, {
    String? contact,
  }) async {
    final entry = await _require(entryId);
    final updated = entry.copyWith(
      title: title,
      contact: contact,
      updatedAt: _now(),
    );

    await _write(updated);
    return updated;
  }

  @override
  Future<HistoryEntry> closeEntry(
    String entryId, {
    HistoryStatus status = HistoryStatus.done,
    String? note,
  }) {
    if (!_endStates.contains(status)) {
      throw ArgumentError.value(
        status,
        'status',
        'closeEntry braucht einen Endzustand (done oder dropped)',
      );
    }
    return updateStatus(entryId, status, note: note);
  }

  @override
  Future<HistoryEvent> logEvent(
    String entryId,
    HistoryEventKind kind, {
    String? note,
    Map<String, Object?> data = const {},
  }) async {
    final event = HistoryEvent(
      id: _newId(),
      entryId: entryId,
      kind: kind,
      note: note,
      data: data,
      createdAt: _now(),
    );

    await _db.insert(DbSchema.tableEvents, event.toRow());
    return event;
  }

  @override
  Future<List<HistoryEvent>> eventsFor(String entryId) async {
    final rows = await _db.query(
      DbSchema.tableEvents,
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'created_at ASC',
    );

    return rows.map(HistoryEvent.fromRow).toList();
  }

  @override
  Future<List<HistoryEntry>> entriesDueForFollowUp({
    HistoryFeature? feature,
    Duration minPause = const Duration(days: 2),
    int limit = 3,
  }) async {
    final cutoff = _now().subtract(minPause).millisecondsSinceEpoch;

    final where = StringBuffer(
      'closed_at IS NULL '
      'AND follow_up_count < ? '
      'AND (last_follow_up_at IS NULL OR last_follow_up_at <= ?)',
    );
    final args = <Object?>[HistoryEntry.maxFollowUps, cutoff];

    if (feature != null) {
      where.write(' AND feature = ?');
      args.add(feature.name);
    }

    final rows = await _db.query(
      DbSchema.tableEntries,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'updated_at ASC',
      limit: limit,
    );

    return rows.map(HistoryEntry.fromRow).toList();
  }

  @override
  Future<HistoryEntry> registerFollowUp(String entryId) async {
    final entry = await _require(entryId);
    final now = _now();

    final updated = entry.copyWith(
      followUpCount: entry.followUpCount + 1,
      lastFollowUpAt: now,
      updatedAt: now,
    );

    await _write(updated);
    await logEvent(
      entryId,
      HistoryEventKind.followUpAsked,
      data: {'count': updated.followUpCount},
    );

    return updated;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    // Das Protokoll ausdrücklich mitlöschen, statt sich auf ON DELETE CASCADE
    // zu verlassen: Die Fremdschlüssel hängen an einem PRAGMA, das pro
    // Verbindung gesetzt wird. Fällt das einmal aus, bleiben sonst
    // verwaiste Ereignisse zu einem Vorgang liegen, den der User gelöscht
    // hat – genau das, was „gelöscht" nicht heißen darf.
    await _db.delete(
      DbSchema.tableEvents,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    await _db.delete(
      DbSchema.tableEntries,
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  Future<List<HistoryEntry>> _queryEntries(
    String? where,
    List<Object?> args,
    int limit,
  ) async {
    final rows = await _db.query(
      DbSchema.tableEntries,
      where: where,
      whereArgs: where == null ? null : args,
      orderBy: 'updated_at DESC',
      limit: limit,
    );

    return rows.map(HistoryEntry.fromRow).toList();
  }

  Future<HistoryEntry> _require(String entryId) async {
    final entry = await entryById(entryId);
    if (entry == null) {
      throw StateError('Kein Historien-Eintrag mit der Id $entryId');
    }
    return entry;
  }

  Future<void> _write(HistoryEntry entry) async {
    await _db.update(
      DbSchema.tableEntries,
      entry.toRow(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }
}
