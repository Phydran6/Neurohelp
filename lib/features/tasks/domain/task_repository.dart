import 'task_node.dart';

/// Zugriff auf zerlegte Aufgaben.
///
/// Jede Änderung schreibt sich in die Historie mit – das lückenlose Logging
/// ist keine Aufgabe der Oberfläche (Konzept, Abschnitt 11, Schritt 4).
abstract interface class TaskRepository {
  /// Legt eine neue Aufgabe an und eröffnet dafür einen Historien-Vorgang.
  ///
  /// Liefert die Id des Vorgangs – darüber läuft alles Weitere.
  Future<String> createTask(String title);

  /// Hängt einen Unterpunkt an. [parentId] `null` heißt: oberste Ebene.
  Future<TaskNode> addStep(
    String entryId, {
    required String title,
    String? parentId,
    String? note,
  });

  /// Legt mehrere Unterpunkte auf einmal an – der Weg, auf dem ein
  /// KI-Vorschlag übernommen wird, nachdem der User ihn bestätigt hat.
  Future<List<TaskNode>> addSteps(
    String entryId, {
    required List<String> titles,
    String? parentId,
  });

  Future<TaskTree> loadTree(String entryId);

  /// Der nächste offene Schritt, oder `null`, wenn alles erledigt ist.
  Future<TaskNode?> nextStep(String entryId);

  /// Hakt einen Schritt ab. **Endgültig** – es gibt bewusst kein Zurück.
  ///
  /// Schließt den Historien-Vorgang automatisch ab, sobald nichts mehr offen
  /// ist. Wirft [StateError], wenn der Schritt schon erledigt ist.
  Future<TaskTree> completeStep(String entryId, String nodeId);

  Future<TaskNode> editStep(String nodeId, {String? title, String? note});

  /// Entfernt einen Punkt samt seiner Unterpunkte.
  Future<void> removeStep(String entryId, String nodeId);
}
