import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/calendar/calendar_service.dart';
import '../../../core/db/schema.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../core/history/domain/history_event.dart';
import '../../../core/history/domain/history_repository.dart';
import '../domain/appointment.dart';
import '../domain/follow_up_schedule.dart';

/// Termine anlegen, buchen und nachverfolgen.
///
/// **V1-Scope:** nur Neuorganisation. Umbuchen und Verschieben sind bewusst
/// nicht dabei (Konzept, Abschnitt 9).
class SqliteAppointmentRepository {
  SqliteAppointmentRepository(
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

  Future<Appointment> create(String title) async {
    final entry = await _history.startEntry(
      feature: HistoryFeature.appointment,
      title: title,
    );

    final appointment = Appointment(
      id: _newId(),
      entryId: entry.id,
      title: title,
      createdAt: _now(),
    );

    await _db.insert(DbSchema.tableAppointments, appointment.toRow());
    return appointment;
  }

  Future<Appointment?> byId(String id) async {
    final rows = await _db.query(
      DbSchema.tableAppointments,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Appointment.fromRow(rows.first);
  }

  Future<Appointment> save(Appointment appointment) async {
    await _db.update(
      DbSchema.tableAppointments,
      appointment.toRow(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
    return appointment;
  }

  /// Legt den Buchungsweg fest.
  ///
  /// [suggestedByAi] hält nur fest, woher der Vorschlag kam – die
  /// Entscheidung liegt immer beim User.
  Future<Appointment> chooseRoute(
    String id,
    BookingRoute route, {
    bool suggestedByAi = false,
  }) async {
    final appointment = await _require(id);
    final updated = await save(
      appointment.copyWith(route: route, routeSuggestedByAi: suggestedByAi),
    );

    await _history.logEvent(
      appointment.entryId,
      HistoryEventKind.statusChanged,
      note: 'Buchungsweg: ${route.name}',
      data: {'route': route.name, 'by_ai': suggestedByAi},
    );

    return updated;
  }

  /// Hält fest, dass der Termin steht. Löst Phase 1 der Nachverfolgung aus.
  Future<Appointment> markBooked(
    String id, {
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    List<String> checklist = const [],
  }) async {
    final appointment = await _require(id);

    final updated = await save(
      appointment.copyWith(
        startsAt: startsAt,
        endsAt: endsAt ?? startsAt.add(const Duration(hours: 1)),
        location: location,
        checklist: checklist,
        bookedAt: _now(),
      ),
    );

    await _history.updateStatus(
      appointment.entryId,
      HistoryStatus.active,
      note: 'Termin gebucht.',
    );

    return updated;
  }

  /// Die Phase, die für diesen Termin jetzt fällig ist – oder `null`.
  Future<FollowUpPhase?> duePhase(String id) async {
    final appointment = await _require(id);
    return FollowUpSchedule.duePhase(appointment, _now());
  }

  /// Vermerkt, dass eine Phase gemeldet wurde.
  ///
  /// Danach kommt sie nicht wieder – höchstens eine Benachrichtigung pro
  /// Phase.
  Future<Appointment> markPhaseNotified(String id, FollowUpPhase phase) async {
    final appointment = await _require(id);
    final updated = await save(
      appointment.copyWith(
        notifiedPhases: {...appointment.notifiedPhases, phase},
      ),
    );

    await _history.logEvent(
      appointment.entryId,
      HistoryEventKind.followUpAsked,
      note: 'Phase ${phase.name}',
      data: {'phase': phase.name},
    );

    return updated;
  }

  /// Antwort auf die Nachfrage nach dem Termin.
  Future<Appointment> finish(String id, {required bool wentWell}) async {
    final appointment = await _require(id);

    await _history.logEvent(
      appointment.entryId,
      HistoryEventKind.followUpAnswered,
      data: {'went_well': wentWell},
    );

    if (wentWell) {
      await _history.closeEntry(appointment.entryId, note: 'Termin gelaufen.');
    } else {
      // Offene Punkte: der Vorgang bleibt liegen, damit die App
      // weiterhelfen kann.
      await _history.updateStatus(appointment.entryId, HistoryStatus.open);
    }

    return appointment;
  }

  /// Angefangene Termine, bei denen die Buchung noch aussteht.
  ///
  /// Das ist der Historie-Check beim Einstieg: Wer den Ablauf abgebrochen
  /// hat, findet ihn hier wieder, statt von vorn anzufangen.
  Future<List<Appointment>> unbooked({int limit = 10}) async {
    final rows = await _db.query(
      DbSchema.tableAppointments,
      where: 'booked_at IS NULL',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(Appointment.fromRow).toList();
  }

  /// Termine, bei denen jetzt eine Phase fällig ist.
  Future<List<({Appointment appointment, FollowUpPhase phase})>>
  pendingNotifications() async {
    final rows = await _db.query(
      DbSchema.tableAppointments,
      where: 'booked_at IS NOT NULL',
      orderBy: 'starts_at ASC',
    );

    final now = _now();
    final result = <({Appointment appointment, FollowUpPhase phase})>[];

    for (final row in rows) {
      final appointment = Appointment.fromRow(row);
      final phase = FollowUpSchedule.duePhase(appointment, now);
      if (phase != null) {
        result.add((appointment: appointment, phase: phase));
      }
    }
    return result;
  }

  /// Der Termin als Kalendereintrag – für die Kollisionsprüfung und den
  /// ICS-Export.
  CalendarEvent? asCalendarEvent(Appointment appointment) {
    final start = appointment.startsAt;
    if (start == null) return null;

    return CalendarEvent(
      title: appointment.title,
      start: start,
      end: appointment.endsAt ?? start.add(const Duration(hours: 1)),
      location: appointment.location,
      description: appointment.checklist.isEmpty
          ? null
          : 'Mitnehmen: ${appointment.checklist.join(', ')}',
    );
  }

  Future<Appointment> _require(String id) async {
    final appointment = await byId(id);
    if (appointment == null) {
      throw StateError('Kein Termin mit der Id $id');
    }
    return appointment;
  }
}
