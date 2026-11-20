import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/calendar/calendar_service.dart';
import 'package:neurohelp/core/calendar/ics.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/history/data/sqlite_history_repository.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/features/appointments/data/sqlite_appointment_repository.dart';
import 'package:neurohelp/features/appointments/domain/appointment.dart';
import 'package:neurohelp/features/appointments/domain/follow_up_schedule.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // Termin: Donnerstag, 20.08.2026, 10:00 Uhr.
  final termin = DateTime(2026, 8, 20, 10);

  late AppDatabase database;
  late SqliteHistoryRepository history;
  late SqliteAppointmentRepository appointments;
  late DateTime now;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    now = DateTime(2026, 8, 8, 12);
    var counter = 0;
    String nextId() => 'id-${++counter}';

    history = SqliteHistoryRepository(database.raw, idGenerator: nextId);
    appointments = SqliteAppointmentRepository(
      database.raw,
      history,
      clock: () => now,
      idGenerator: nextId,
    );
  });

  tearDown(() => database.close());

  Future<Appointment> gebucht() async {
    final termin0 = await appointments.create('Sehtest beim Optiker');
    await appointments.chooseRoute(termin0.id, BookingRoute.phone);
    return appointments.markBooked(
      termin0.id,
      startsAt: termin,
      location: 'Hauptstraße 5',
      checklist: const ['Versichertenkarte', 'Alte Brille'],
    );
  }

  group('Buchungsweg', () {
    test('Telefon übergibt an das Anruf-Feature', () async {
      final a = await appointments.create('Sehtest');
      final updated = await appointments.chooseRoute(a.id, BookingRoute.phone);

      expect(updated.delegatesToCall, isTrue);
      expect(updated.delegatesToMessage, isFalse);
    });

    test('Mail und Formular übergeben an das Nachricht-Feature', () async {
      for (final route in [BookingRoute.mail, BookingRoute.webForm]) {
        final a = await appointments.create('Termin');
        final updated = await appointments.chooseRoute(a.id, route);

        expect(updated.delegatesToMessage, isTrue, reason: '$route');
        expect(updated.delegatesToCall, isFalse, reason: '$route');
      }
    });

    test('der User kann den KI-Vorschlag überstimmen', () async {
      final a = await appointments.create('Termin');
      await appointments.chooseRoute(
        a.id,
        BookingRoute.online,
        suggestedByAi: true,
      );
      final korrigiert = await appointments.chooseRoute(
        a.id,
        BookingRoute.phone,
      );

      expect(korrigiert.route, BookingRoute.phone);
      expect(korrigiert.routeSuggestedByAi, isFalse);
    });
  });

  group('Nachverfolgung', () {
    test('nicht gebucht heißt keine Nachverfolgung', () async {
      final a = await appointments.create('Termin');

      expect(FollowUpSchedule.duePhase(a, now), isNull);
    });

    test('durchläuft die vier Phasen in der richtigen Reihenfolge', () async {
      final a = await gebucht();

      // Direkt nach der Buchung.
      expect(FollowUpSchedule.duePhase(a, now), FollowUpPhase.booked);

      final nachPhase1 = a.copyWith(notifiedPhases: {FollowUpPhase.booked});

      // Am Vortag, 18 Uhr.
      expect(
        FollowUpSchedule.duePhase(nachPhase1, DateTime(2026, 8, 19, 18)),
        FollowUpPhase.dayBefore,
      );

      final nachPhase2 = nachPhase1.copyWith(
        notifiedPhases: {FollowUpPhase.booked, FollowUpPhase.dayBefore},
      );

      // Am Terminmorgen, 8 Uhr.
      expect(
        FollowUpSchedule.duePhase(nachPhase2, DateTime(2026, 8, 20, 8)),
        FollowUpPhase.dayOf,
      );

      final nachPhase3 = nachPhase2.copyWith(
        notifiedPhases: {
          FollowUpPhase.booked,
          FollowUpPhase.dayBefore,
          FollowUpPhase.dayOf,
        },
      );

      // Nach dem Termin.
      expect(
        FollowUpSchedule.duePhase(nachPhase3, DateTime(2026, 8, 20, 12)),
        FollowUpPhase.after,
      );
    });

    test('meldet jede Phase höchstens einmal', () async {
      final a = await gebucht();

      expect(await appointments.duePhase(a.id), FollowUpPhase.booked);

      await appointments.markPhaseNotified(a.id, FollowUpPhase.booked);

      expect(await appointments.duePhase(a.id), isNull);
    });

    test('holt eine verpasste Erinnerung nicht nach', () async {
      final a = await gebucht();
      final nachPhase1 = a.copyWith(notifiedPhases: {FollowUpPhase.booked});

      // Der User schaut erst nach dem Termin wieder rein. Die Erinnerung
      // vom Vortag ist verfallen – keine Schuldmechanik.
      final phase = FollowUpSchedule.duePhase(
        nachPhase1,
        DateTime(2026, 8, 20, 14),
      );

      expect(phase, FollowUpPhase.after);
    });

    test('listet fällige Benachrichtigungen', () async {
      await gebucht();

      final faellig = await appointments.pendingNotifications();

      expect(faellig, hasLength(1));
      expect(faellig.single.phase, FollowUpPhase.booked);
    });

    test('Ja schließt den Vorgang ab, Nein lässt ihn offen', () async {
      final a = await gebucht();
      await appointments.finish(a.id, wentWell: true);
      expect((await history.entryById(a.entryId))!.status, HistoryStatus.done);

      final b = await gebucht();
      await appointments.finish(b.id, wentWell: false);
      expect((await history.entryById(b.entryId))!.status, HistoryStatus.open);
    });
  });

  group('Nachbessern', () {
    test('ein gebuchter Termin lässt sich noch ändern', () async {
      final a = await gebucht();

      final geaendert = await appointments.updateBooking(
        a.id,
        startsAt: termin,
        location: 'Hauptstraße 5',
        checklist: const ['Versichertenkarte', 'Alte Brille', 'Überweisung'],
      );

      expect(geaendert.checklist, contains('Überweisung'));
      // Er bleibt gebucht: Nachtragen ist kein neuer Termin.
      expect(geaendert.isBooked, isTrue);
      expect(geaendert.bookedAt, a.bookedAt);
    });

    test('der Ort lässt sich auch wieder leeren', () async {
      final a = await gebucht();
      expect(a.location, 'Hauptstraße 5');

      final geaendert = await appointments.updateBooking(
        a.id,
        startsAt: termin,
      );

      expect(geaendert.location, isNull);
    });

    test('verschiebt sich der Termin, gelten die Erinnerungen neu', () async {
      final a = await gebucht();
      await appointments.markPhaseNotified(a.id, FollowUpPhase.booked);
      await appointments.markPhaseNotified(a.id, FollowUpPhase.dayBefore);

      final geaendert = await appointments.updateBooking(
        a.id,
        startsAt: termin.add(const Duration(days: 7)),
      );

      // Die Bestätigung war für die Buchung, die bleibt. Die Erinnerung am
      // Vortag gehörte zum alten Datum.
      expect(geaendert.notifiedPhases, {FollowUpPhase.booked});
    });

    test(
      'bleibt der Termin liegen, bleiben die Erinnerungen gemeldet',
      () async {
        final a = await gebucht();
        await appointments.markPhaseNotified(a.id, FollowUpPhase.booked);

        final geaendert = await appointments.updateBooking(
          a.id,
          startsAt: termin,
          checklist: const ['Versichertenkarte'],
        );

        expect(geaendert.notifiedPhases, {FollowUpPhase.booked});
      },
    );

    test('gebuchte Termine bleiben auffindbar', () async {
      final a = await gebucht();

      final liste = await appointments.upcoming();
      expect(liste.map((e) => e.id), [a.id]);
    });

    test('was noch nicht gebucht ist, steht nicht bei den Terminen', () async {
      final offen = await appointments.create('Zahnarzt');
      await appointments.chooseRoute(offen.id, BookingRoute.phone);

      expect(await appointments.upcoming(), isEmpty);
      expect((await appointments.unbooked()).map((e) => e.id), [offen.id]);
    });

    test('vergangene Termine fallen aus der Liste', () async {
      await gebucht();
      // Zwei Tage nach dem Termin.
      now = termin.add(const Duration(days: 2));

      expect(await appointments.upcoming(), isEmpty);
    });

    test('ein Termin von heute Morgen zählt noch zu heute', () async {
      await gebucht();
      // Terminmorgen, der Termin selbst war um 10 Uhr.
      now = DateTime(2026, 8, 20, 14);

      expect(await appointments.upcoming(), hasLength(1));
    });
  });

  group('Kalender', () {
    test('erkennt eine Überschneidung', () {
      const stunde = Duration(hours: 1);
      final a = CalendarEvent(
        title: 'Optiker',
        start: termin,
        end: termin.add(stunde),
      );
      final ueberschneidung = CalendarEvent(
        title: 'Zahnarzt',
        start: termin.add(const Duration(minutes: 30)),
        end: termin.add(const Duration(minutes: 90)),
      );
      final direktDanach = CalendarEvent(
        title: 'Einkauf',
        start: termin.add(stunde),
        end: termin.add(const Duration(hours: 2)),
      );

      expect(a.overlaps(ueberschneidung), isTrue);
      // Direkt anschließende Termine sind keine Kollision.
      expect(a.overlaps(direktDanach), isFalse);
    });

    test('baut aus dem Termin einen Kalendereintrag', () async {
      final a = await gebucht();
      final event = appointments.asCalendarEvent(a);

      expect(event!.title, 'Sehtest beim Optiker');
      expect(event.location, 'Hauptstraße 5');
      expect(event.description, contains('Versichertenkarte'));
    });

    test('exportiert eine gültige ICS-Datei', () {
      final event = CalendarEvent(
        title: 'Sehtest, Optiker',
        start: DateTime.utc(2026, 8, 20, 10),
        end: DateTime.utc(2026, 8, 20, 11),
        location: 'Hauptstraße 5',
      );

      final ics = IcsExporter.export(
        event,
        uid: 'test@neurohelp',
        stamp: DateTime.utc(2026, 8, 8, 12),
      );

      expect(ics, startsWith('BEGIN:VCALENDAR'));
      expect(ics, endsWith('END:VCALENDAR'));
      expect(ics, contains('DTSTART:20260820T100000Z'));
      expect(ics, contains('DTEND:20260820T110000Z'));
      // Komma im Titel muss maskiert sein, sonst zerreißt es die Datei.
      expect(ics, contains(r'SUMMARY:Sehtest\, Optiker'));
      expect(ics, contains('\r\n'));
    });
  });
}
