import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/schema.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../core/history/domain/history_event.dart';
import '../../../core/history/domain/history_repository.dart';
import '../domain/task_node.dart';
import '../domain/task_repository.dart';

/// SQLite-Umsetzung von „Aufgabe sortieren".
class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository(
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

  @override
  Future<String> createTask(String title) async {
    final entry = await _history.startEntry(
      feature: HistoryFeature.task,
      title: title,
    );
    return entry.id;
  }

  @override
  Future<TaskNode> addStep(
    String entryId, {
    required String title,
    String? parentId,
    String? note,
  }) async {
    final node = TaskNode(
      id: _newId(),
      entryId: entryId,
      parentId: parentId,
      title: title,
      note: note,
      position: await _nextPosition(entryId, parentId),
      createdAt: _now(),
    );

    await _db.insert(DbSchema.tableTaskNodes, node.toRow());
    await _history.logEvent(
      entryId,
      HistoryEventKind.stepAdded,
      note: title,
      data: {'node_id': node.id, 'parent_id': ?parentId},
    );

    return node;
  }

  @override
  Future<List<TaskNode>> addSteps(
    String entryId, {
    required List<String> titles,
    String? parentId,
  }) async {
    final created = <TaskNode>[];
    for (final title in titles) {
      created.add(await addStep(entryId, title: title, parentId: parentId));
    }
    return created;
  }

  @override
  Future<TaskTree> loadTree(String entryId) async {
    final rows = await _db.query(
      DbSchema.tableTaskNodes,
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'position ASC',
    );

    return TaskTree.fromNodes(rows.map(TaskNode.fromRow));
  }

  @override
  Future<TaskNode?> nextStep(String entryId) async =>
      (await loadTree(entryId)).nextStep;

  @override
  Future<TaskTree> completeStep(String entryId, String nodeId) async {
    final tree = await loadTree(entryId);
    final node = tree.nodeById(nodeId);

    if (node == null) {
      throw StateError('Kein Schritt mit der Id $nodeId');
    }
    if (node.isDone) {
      throw StateError('Der Schritt "${node.title}" ist bereits erledigt.');
    }
    if (tree.childrenOf(nodeId).isNotEmpty) {
      throw StateError(
        'Nur ausführbare Punkte ohne Unterpunkte lassen sich abhaken.',
      );
    }

    final now = _now();
    await _db.update(
      DbSchema.tableTaskNodes,
      {'done_at': now.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [nodeId],
    );

    final updated = await loadTree(entryId);
    final progress = updated.progress;

    await _history.logEvent(
      entryId,
      HistoryEventKind.stepDone,
      note: node.title,
      data: {'node_id': nodeId, 'done': progress.done, 'total': progress.total},
    );

    // Alles abgehakt: der Vorgang ist fertig. Kein Nachfassen mehr.
    if (updated.isComplete) {
      await _history.closeEntry(entryId, note: 'Alle Schritte erledigt.');
    }

    return updated;
  }

  @override
  Future<TaskNode> editStep(
    String nodeId, {
    String? title,
    String? note,
  }) async {
    final rows = await _db.query(
      DbSchema.tableTaskNodes,
      where: 'id = ?',
      whereArgs: [nodeId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Kein Schritt mit der Id $nodeId');
    }

    final current = TaskNode.fromRow(rows.first);
    final updated = TaskNode(
      id: current.id,
      entryId: current.entryId,
      parentId: current.parentId,
      title: title ?? current.title,
      note: note ?? current.note,
      position: current.position,
      createdAt: current.createdAt,
      doneAt: current.doneAt,
    );

    await _db.update(
      DbSchema.tableTaskNodes,
      updated.toRow(),
      where: 'id = ?',
      whereArgs: [nodeId],
    );

    return updated;
  }

  @override
  Future<void> removeStep(String entryId, String nodeId) async {
    // ON DELETE CASCADE greift nur mit eingeschalteten Fremdschlüsseln;
    // AppDatabase schaltet sie beim Öffnen ein.
    await _db.delete(
      DbSchema.tableTaskNodes,
      where: 'id = ? AND entry_id = ?',
      whereArgs: [nodeId, entryId],
    );
  }

  Future<int> _nextPosition(String entryId, String? parentId) async {
    final rows = await _db.query(
      DbSchema.tableTaskNodes,
      columns: ['position'],
      where: parentId == null
          ? 'entry_id = ? AND parent_id IS NULL'
          : 'entry_id = ? AND parent_id = ?',
      whereArgs: parentId == null ? [entryId] : [entryId, parentId],
      orderBy: 'position DESC',
      limit: 1,
    );

    if (rows.isEmpty) return 0;
    return (rows.first['position']! as int) + 1;
  }
}
