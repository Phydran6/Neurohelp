import 'history_entry.dart';
import 'history_event.dart';

/// Zugriff auf die Historie – das Rückgrat der App (Konzept, Abschnitt 12).
///
/// Diese Schnittstelle kennt weder Flutter noch SQLite. Features hängen
/// ausschließlich hier dran, nie an der Implementierung.
abstract interface class HistoryRepository {
  /// Legt einen neuen Vorgang an und protokolliert ihn.
  Future<HistoryEntry> startEntry({
    required HistoryFeature feature,
    required String title,
    String? contact,
  });

  Future<HistoryEntry?> entryById(String id);

  /// Offene Vorgänge – die Grundlage des Historie-Checks am Anfang jedes
  /// Features. [feature] filtert optional auf ein einzelnes Feature.
  Future<List<HistoryEntry>> openEntries({
    HistoryFeature? feature,
    int limit = 20,
  });

  /// Zuletzt berührte Vorgänge, unabhängig vom Status.
  Future<List<HistoryEntry>> recentEntries({
    HistoryFeature? feature,
    int limit = 20,
  });

  /// Volltextsuche über den Titel – für „Ich weiß nur, dass da was war"
  /// (Konzept, Abschnitt 10, Schritt 2).
  Future<List<HistoryEntry>> search(String query, {int limit = 20});

  Future<HistoryEntry> updateStatus(
    String entryId,
    HistoryStatus status, {
    String? note,
  });

  Future<HistoryEntry> rename(String entryId, String title);

  /// Schließt einen Vorgang ab. [status] muss ein Endzustand sein.
  Future<HistoryEntry> closeEntry(
    String entryId, {
    HistoryStatus status = HistoryStatus.done,
    String? note,
  });

  /// Protokolliert ein Ereignis zu einem Vorgang.
  Future<HistoryEvent> logEvent(
    String entryId,
    HistoryEventKind kind, {
    String? note,
    Map<String, Object?> data = const {},
  });

  Future<List<HistoryEvent>> eventsFor(String entryId);

  /// Vorgänge, bei denen die App noch einmal sanft nachfragen darf.
  ///
  /// Liefert nur Einträge, die [HistoryEntry.maxFollowUps] noch nicht erreicht
  /// haben und deren letzte Nachfrage mindestens [minPause] her ist.
  Future<List<HistoryEntry>> entriesDueForFollowUp({
    Duration minPause = const Duration(days: 2),
    int limit = 3,
  });

  /// Vermerkt, dass nachgefragt wurde. Erhöht den Zähler.
  Future<HistoryEntry> registerFollowUp(String entryId);

  /// Löscht einen Vorgang samt Protokoll – nur auf ausdrücklichen Wunsch
  /// des Users.
  Future<void> deleteEntry(String entryId);
}
