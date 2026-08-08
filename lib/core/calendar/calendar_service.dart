/// Ein Termin, wie ihn ein Kalender sieht.
class CalendarEvent {
  const CalendarEvent({
    required this.title,
    required this.start,
    required this.end,
    this.location,
    this.description,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final String? location;
  final String? description;

  /// Ob sich dieser Termin mit [other] zeitlich überschneidet.
  ///
  /// Termine, die direkt aneinander anschließen, überschneiden sich nicht.
  bool overlaps(CalendarEvent other) =>
      start.isBefore(other.end) && other.start.isBefore(end);
}

/// Zugriff auf die Kalender des Geräts und verbundene Konten.
///
/// Konzept, Abschnitt 8, Schritt 7: Live-Kollisionsprüfung gegen
/// Gerätekalender, Google und Outlook. Der ICS-Export ist der Weg ohne
/// Kollisionsprüfung – er kennt die anderen Termine nicht.
abstract interface class CalendarService {
  /// Ob der User Kalenderzugriff erlaubt hat.
  Future<bool> get isPermissionGranted;

  Future<bool> requestPermission();

  /// Termine im Zeitraum, über alle verbundenen Kalender.
  Future<List<CalendarEvent>> eventsBetween(DateTime from, DateTime to);

  /// Trägt einen Termin ein.
  Future<void> add(CalendarEvent event);

  /// Termine, die sich mit [candidate] überschneiden.
  ///
  /// Leere Liste heißt: der Zeitpunkt ist frei. Ohne Kalenderzugriff
  /// ebenfalls leer – dann ist eine Kollisionsprüfung schlicht nicht
  /// möglich, und das darf den User nicht blockieren.
  Future<List<CalendarEvent>> collisionsFor(CalendarEvent candidate) async {
    if (!await isPermissionGranted) return const [];

    final sameDay = await eventsBetween(candidate.start, candidate.end);
    return sameDay.where(candidate.overlaps).toList();
  }
}
