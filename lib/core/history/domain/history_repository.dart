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

  /// Volltextsuche über Titel und Ansprechpartner – für „Ich weiß nur, dass
  /// da was war" (Konzept, Abschnitt 10, Schritt 2).
  Future<List<HistoryEntry>> search(
    String query, {
    HistoryFeature? feature,
    int limit = 20,
  });

  /// Wie viele Vorgänge es je Feature gibt, aufgeteilt in offen und gesamt.
  ///
  /// Grundlage für die Übersicht im Historie-Bereich: Der User soll sehen,
  /// was da ist, ohne jede Liste einzeln aufzuklappen.
  Future<Map<HistoryFeature, ({int open, int total})>> countsByFeature();

  Future<HistoryEntry> updateStatus(
    String entryId,
    HistoryStatus status, {
    String? note,
  });

  /// Benennt einen Vorgang um und hält optional den Ansprechpartner nach.
  ///
  /// Features legen ihren Vorgang an, bevor der User den Titel getippt hat –
  /// sonst stünde der Historie-Check am Anfang vor einer leeren Tabelle.
  /// Damit in der Historie danach nicht „Ohne Titel" steht, muss das Feature
  /// nachziehen, sobald es den Titel kennt.
  Future<HistoryEntry> rename(String entryId, String title, {String? contact});

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
    HistoryFeature? feature,
    Duration minPause = const Duration(days: 2),
    int limit = 3,
  });

  /// Vermerkt, dass nachgefragt wurde. Erhöht den Zähler.
  Future<HistoryEntry> registerFollowUp(String entryId);

  /// Löscht einen Vorgang samt Protokoll – nur auf ausdrücklichen Wunsch
  /// des Users.
  Future<void> deleteEntry(String entryId);
}
