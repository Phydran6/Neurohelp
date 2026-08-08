/// Ein einzelner Punkt in einer zerlegten Aufgabe.
///
/// Beliebig tief verschachtelbar (Konzept, Abschnitt 11, Weg B). Jeder Punkt
/// ist ausführbar und trägt eine Notiz, was konkret zu tun ist.
class TaskNode {
  const TaskNode({
    required this.id,
    required this.entryId,
    required this.title,
    required this.position,
    required this.createdAt,
    this.parentId,
    this.note,
    this.doneAt,
  });

  final String id;

  /// Der Historien-Vorgang, zu dem dieser Baum gehört.
  final String entryId;

  /// `null` bei der obersten Aufgabe.
  final String? parentId;

  final String title;

  /// Was konkret zu tun ist. Der Titel allein reicht oft nicht.
  final String? note;

  /// Reihenfolge unter den Geschwistern.
  final int position;

  final DateTime createdAt;

  /// Wann abgehakt. Abgehakt heißt **endgültig erledigt** – es gibt bewusst
  /// kein Zurück (Konzept, Abschnitt 11).
  final DateTime? doneAt;

  bool get isDone => doneAt != null;

  Map<String, Object?> toRow() => {
    'id': id,
    'entry_id': entryId,
    'parent_id': parentId,
    'title': title,
    'note': note,
    'position': position,
    'created_at': createdAt.millisecondsSinceEpoch,
    'done_at': doneAt?.millisecondsSinceEpoch,
  };

  static TaskNode fromRow(Map<String, Object?> row) => TaskNode(
    id: row['id']! as String,
    entryId: row['entry_id']! as String,
    parentId: row['parent_id'] as String?,
    title: row['title']! as String,
    note: row['note'] as String?,
    position: row['position']! as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
    doneAt: row['done_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row['done_at']! as int),
  );
}

/// Die zerlegte Aufgabe als Baum.
///
/// Wichtig für den Fokus-Modus (Konzept, Abschnitt 11, Schritt 3): Der Baum
/// wird dem User **nicht** am Stück gezeigt. Er liefert immer nur den
/// nächsten Schritt – der Berg bleibt unsichtbar.
class TaskTree {
  TaskTree._(this._nodes, this._childrenOf, this.roots);

  final Map<String, TaskNode> _nodes;
  final Map<String?, List<TaskNode>> _childrenOf;

  /// Die obersten Punkte, nach Position sortiert.
  final List<TaskNode> roots;

  /// Baut den Baum aus einer flachen Liste.
  ///
  /// Punkte, deren Elternteil fehlt, werden als Wurzel behandelt – lieber
  /// ein schiefer Baum als eine verschwundene Aufgabe.
  factory TaskTree.fromNodes(Iterable<TaskNode> nodes) {
    final byId = {for (final node in nodes) node.id: node};
    final children = <String?, List<TaskNode>>{};

    for (final node in byId.values) {
      final parent = node.parentId != null && byId.containsKey(node.parentId)
          ? node.parentId
          : null;
      children.putIfAbsent(parent, () => []).add(node);
    }

    for (final list in children.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }

    return TaskTree._(byId, children, List.unmodifiable(children[null] ?? []));
  }

  bool get isEmpty => _nodes.isEmpty;

  TaskNode? nodeById(String id) => _nodes[id];

  /// Direkte Unterpunkte, nach Position sortiert.
  List<TaskNode> childrenOf(String id) =>
      List.unmodifiable(_childrenOf[id] ?? const []);

  /// Alle Punkte ohne Unterpunkte – nur die sind wirklich ausführbar.
  List<TaskNode> get steps {
    final result = <TaskNode>[];
    void walk(List<TaskNode> level) {
      for (final node in level) {
        final children = _childrenOf[node.id];
        if (children == null || children.isEmpty) {
          result.add(node);
        } else {
          walk(children);
        }
      }
    }

    walk(roots);
    return List.unmodifiable(result);
  }

  /// Der nächste offene Schritt, oder `null`, wenn alles erledigt ist.
  ///
  /// Das ist die Grundfunktion des Fokus-Modus: eine Sache fertig, die
  /// nächste erscheint.
  TaskNode? get nextStep {
    for (final step in steps) {
      if (!step.isDone) return step;
    }
    return null;
  }

  /// Ob ein Punkt erledigt ist. Ein Punkt mit Unterpunkten gilt als erledigt,
  /// sobald alle seine Unterpunkte erledigt sind.
  bool isDone(String id) {
    final children = _childrenOf[id];
    if (children == null || children.isEmpty) {
      return _nodes[id]?.isDone ?? false;
    }
    return children.every((child) => isDone(child.id));
  }

  bool get isComplete => steps.isNotEmpty && steps.every((step) => step.isDone);

  /// Erledigte von insgesamt – für die Historie, nicht für einen
  /// Fortschrittsbalken. Der würde nur Druck machen.
  ({int done, int total}) get progress {
    final all = steps;
    return (done: all.where((step) => step.isDone).length, total: all.length);
  }

  /// Der Pfad von der obersten Aufgabe bis zu [id].
  List<TaskNode> pathTo(String id) {
    final path = <TaskNode>[];
    var current = _nodes[id];

    while (current != null) {
      path.insert(0, current);
      final parentId = current.parentId;
      current = parentId == null ? null : _nodes[parentId];
    }
    return List.unmodifiable(path);
  }
}
