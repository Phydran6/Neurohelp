import 'appointment.dart';

/// Entscheidet, welche Nachverfolgungs-Phase gerade dran ist.
///
/// Konzept, Abschnitt 9, Schritt 3: vier Phasen, **höchstens eine
/// Benachrichtigung pro Phase, keine Schuldmechanik.** Eine verpasste Phase
/// wird nicht nachgeholt – wer die Erinnerung vom Vortag nicht gesehen hat,
/// bekommt sie nicht am Terminmorgen nachgereicht.
abstract final class FollowUpSchedule {
  /// Die Phase, die zu [now] fällig ist – oder `null`.
  ///
  /// Liefert nur Phasen, die noch nicht gemeldet wurden. Bei mehreren
  /// fälligen Phasen gewinnt die späteste: Wer erst am Terminmorgen
  /// hinschaut, will die Anfahrt sehen, nicht die Erinnerung von gestern.
  static FollowUpPhase? duePhase(Appointment appointment, DateTime now) {
    if (!appointment.isBooked) return null;

    for (final phase in FollowUpPhase.values.reversed) {
      if (appointment.notifiedPhases.contains(phase)) continue;
      if (_isDue(phase, appointment, now)) return phase;
    }
    return null;
  }

  /// Wann eine Phase frühestens gemeldet werden darf.
  static DateTime? dueAt(FollowUpPhase phase, Appointment appointment) {
    final start = appointment.startsAt;
    final booked = appointment.bookedAt;
    if (start == null || booked == null) return null;

    return switch (phase) {
      FollowUpPhase.booked => booked,
      // Am Vortag um 18 Uhr – abends, wenn noch Zeit zum Packen ist.
      FollowUpPhase.dayBefore => _atHour(
        start.subtract(const Duration(days: 1)),
        18,
      ),
      // Am Terminmorgen um 8 Uhr.
      FollowUpPhase.dayOf => _atHour(start, 8),
      // Danach: eine Stunde nach dem Ende, damit nicht mitten im Termin
      // gefragt wird.
      FollowUpPhase.after => (appointment.endsAt ?? start).add(
        const Duration(hours: 1),
      ),
    };
  }

  static bool _isDue(
    FollowUpPhase phase,
    Appointment appointment,
    DateTime now,
  ) {
    final due = dueAt(phase, appointment);
    if (due == null) return false;
    if (now.isBefore(due)) return false;

    // Erinnerungen vor dem Termin verfallen, sobald der Termin läuft –
    // sonst kommt am Tag danach noch „denk ans Mitbringen".
    final start = appointment.startsAt!;
    if (phase != FollowUpPhase.after &&
        phase != FollowUpPhase.booked &&
        !now.isBefore(start)) {
      return false;
    }
    return true;
  }

  static DateTime _atHour(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);
}
