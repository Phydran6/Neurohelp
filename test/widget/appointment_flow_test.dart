import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/features/appointments/domain/appointment.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_book_page.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_route_page.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_start_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  // Feste Uhr: Die Nachverfolgung hängt an Tagesgrenzen und Uhrzeiten.
  // Mit der echten Zeit wäre der Test je nach Tageszeit mal grün, mal rot.
  var now = DateTime(2026, 8, 10, 12);
  final termin = DateTime(2026, 8, 20, 10);

  late AppDatabase database;
  late AppServices services;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    now = DateTime(2026, 8, 10, 12);
    services = AppServices.from(database, clock: () => now);
  });

  tearDown(() => database.close());

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int tries = 40,
  }) async {
    for (var attempt = 0; attempt < tries; attempt++) {
      if (finder.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.pump(const Duration(milliseconds: 32));
    }
    fail('Nicht gefunden: $finder');
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: AppointmentStartPage()),
      ),
    );
    // Der Einstieg fragt zuerst, ob man es noch weiß – das Feld kommt danach.
    await pumpUntil(tester, find.byKey(const Key('appt_know')));
  }

  /// „Ich weiß es" antippen, damit das Titelfeld dasteht.
  Future<void> knowIt(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('appt_know')));
    await pumpUntil(tester, find.byKey(const Key('appt_title')));
  }

  /// Legt einen gebuchten Termin an, ohne durch die Oberfläche zu gehen.
  Future<Appointment> booked({
    required DateTime startsAt,
    List<String> checklist = const [],
  }) async {
    final appointment = await services.appointments.create('Sehtest');
    await services.appointments.chooseRoute(appointment.id, BookingRoute.phone);
    return services.appointments.markBooked(
      appointment.id,
      startsAt: startsAt,
      location: 'Hauptstraße 5',
      checklist: checklist,
    );
  }

  group('Buchungsweg', () {
    testWidgets('bietet alle vier Wege an', (tester) async {
      final appointment = await services.appointments.create('Sehtest');

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            home: AppointmentRoutePage(appointmentId: appointment.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final option in AppointmentRoutePage.options) {
        expect(
          find.byKey(Key('appt_route_${option.route.name}')),
          findsOneWidget,
          reason: option.label,
        );
      }
    });
  });

  group('Nachverfolgung', () {
    testWidgets('meldet nach der Buchung, dass der Termin steht', (
      tester,
    ) async {
      await booked(startsAt: termin);

      await pumpApp(tester);

      final text = tester.widget<Text>(
        find.byKey(const Key('appt_phase_text')),
      );
      expect(text.data, 'Der Termin ist gespeichert.');
    });

    testWidgets('meldet jede Phase höchstens einmal', (tester) async {
      final appointment = await booked(startsAt: termin);

      await pumpApp(tester);
      expect(find.byKey(Key('appt_phase_${appointment.id}')), findsOneWidget);

      await tester.tap(find.byKey(Key('appt_ack_${appointment.id}')));
      await tester.pumpAndSettle();

      // Zur Kenntnis genommen heißt: kommt nicht wieder.
      expect(find.byKey(Key('appt_phase_${appointment.id}')), findsNothing);
    });

    testWidgets('zeigt am Vortag die Checkliste', (tester) async {
      final appointment = await booked(
        startsAt: termin,
        checklist: const ['Versichertenkarte', 'Alte Brille'],
      );
      // Vortag, 18:30 Uhr - da ist die Erinnerung faellig.
      now = DateTime(2026, 8, 19, 18, 30);

      await services.appointments.markPhaseNotified(
        appointment.id,
        FollowUpPhase.booked,
      );

      await pumpApp(tester);

      expect(find.text('Versichertenkarte'), findsNothing);
      expect(find.text('· Versichertenkarte'), findsOneWidget);
      expect(find.text('· Alte Brille'), findsOneWidget);
    });

    testWidgets('fragt danach, ob der Termin gelaufen ist', (tester) async {
      // Nach dem Termin.
      now = DateTime(2026, 8, 20, 14);

      final appointment = await booked(startsAt: termin);
      await services.appointments.markPhaseNotified(
        appointment.id,
        FollowUpPhase.booked,
      );

      await pumpApp(tester);

      final text = tester.widget<Text>(
        find.byKey(const Key('appt_phase_text')),
      );
      expect(text.data, 'Ist der Termin gelaufen?');

      await tester.tap(find.byKey(Key('appt_went_well_${appointment.id}')));
      await tester.pumpAndSettle();

      final entry = await services.history.entryById(appointment.entryId);
      expect(entry!.status, HistoryStatus.done);
    });

    testWidgets('offene Punkte lassen den Vorgang liegen', (tester) async {
      now = DateTime(2026, 8, 20, 14);

      final appointment = await booked(startsAt: termin);
      await services.appointments.markPhaseNotified(
        appointment.id,
        FollowUpPhase.booked,
      );

      await pumpApp(tester);
      await tester.tap(find.byKey(Key('appt_open_points_${appointment.id}')));
      await tester.pumpAndSettle();

      final entry = await services.history.entryById(appointment.entryId);
      expect(entry!.status, HistoryStatus.open);
      expect(entry.isOpen, isTrue);
    });
  });

  group('Weitermachen', () {
    testWidgets('ein abgebrochener Anruf lässt sich wieder aufnehmen', (
      tester,
    ) async {
      final appointment = await services.appointments.create('Sehtest');
      // Weg gewählt, Telefonat abgebrochen – gebucht ist nichts.
      await services.appointments.chooseRoute(
        appointment.id,
        BookingRoute.phone,
      );

      await pumpApp(tester);
      await tester.tap(find.byKey(Key('appt_unbooked_${appointment.id}')));
      await pumpUntil(tester, find.byKey(const Key('appt_route_title')));

      // Vorher ging es von hier direkt ins Eintragen und der Anruf war
      // nicht mehr erreichbar.
      expect(find.byKey(const Key('appt_route_again')), findsOneWidget);
      expect(find.byKey(const Key('appt_route_phone')), findsOneWidget);

      final badge = tester.widget<Text>(
        find.byKey(const Key('appt_route_badge_phone')),
      );
      expect(badge.data, 'Zuletzt gewählt');
    });

    testWidgets('wer den Termin schon hat, überspringt den Weg', (
      tester,
    ) async {
      final appointment = await services.appointments.create('Sehtest');

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            home: AppointmentRoutePage(appointmentId: appointment.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('appt_route_skip')));
      await pumpUntil(tester, find.byKey(const Key('appt_pick_time')));
    });
  });

  group('Nachbessern', () {
    testWidgets('ein Termin, der steht, bleibt in der Liste', (tester) async {
      final appointment = await booked(startsAt: termin);
      // Die Bestätigung ist zur Kenntnis genommen – jetzt zählt die Liste.
      await services.appointments.markPhaseNotified(
        appointment.id,
        FollowUpPhase.booked,
      );

      await pumpApp(tester);

      expect(find.byKey(const Key('appt_upcoming_title')), findsOneWidget);
      expect(
        find.byKey(Key('appt_upcoming_${appointment.id}')),
        findsOneWidget,
      );
      expect(find.text('Do, 20.08.2026, 10:00 Uhr'), findsOneWidget);
    });

    testWidgets('aus der Erinnerung heraus etwas nachtragen', (tester) async {
      final appointment = await booked(startsAt: termin);

      await pumpApp(tester);

      // Die Karte fragt nach dem Termin – genau hier fällt einem ein, was
      // noch fehlt.
      await tester.tap(find.byKey(Key('appt_edit_${appointment.id}')));
      await pumpUntil(tester, find.byKey(const Key('appt_edit_hint')));

      expect(find.text('Änderungen speichern'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('appt_item_field')),
        'Überweisung',
      );
      await tester.pump();

      // Der Knopf steht unter dem Feld und kann aus dem Bild gerutscht
      // sein – auf dem Testschirm wie auf einem kleinen Telefon.
      await tester.ensureVisible(find.byKey(const Key('appt_item_add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('appt_item_add')));
      await tester.pumpAndSettle();

      expect(find.text('Überweisung'), findsOneWidget);

      await tester.tap(find.byKey(const Key('appt_save')));
      await tester.pumpAndSettle();

      final gespeichert = await services.appointments.byId(appointment.id);
      expect(gespeichert!.checklist, contains('Überweisung'));
      // Nachtragen ist kein neuer Termin: Er bleibt gebucht.
      expect(gespeichert.bookedAt, appointment.bookedAt);
    });

    testWidgets('ohne Text bleibt der Knopf zum Hinzufügen aus', (
      tester,
    ) async {
      final appointment = await booked(startsAt: termin);

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            home: AppointmentBookPage(appointmentId: appointment.id),
          ),
        ),
      );
      await pumpUntil(tester, find.byKey(const Key('appt_item_field')));

      final aus = tester.widget<TextButton>(
        find.byKey(const Key('appt_item_add')),
      );
      expect(aus.onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('appt_item_field')),
        'Versichertenkarte',
      );
      await tester.pump();

      final an = tester.widget<TextButton>(
        find.byKey(const Key('appt_item_add')),
      );
      expect(an.onPressed, isNotNull);
    });
  });

  group('Anlegen', () {
    testWidgets('ohne Thema bleibt der Knopf aus', (tester) async {
      await pumpApp(tester);
      await knowIt(tester);

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('appt_new')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('wer es nicht mehr weiß, kommt trotzdem weiter', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('appt_recall')));
      await pumpUntil(tester, find.byKey(const Key('appt_nudges')));

      // Ohne Fund führt die App anders heran – und der Weg bleibt offen.
      await tester.tap(find.byKey(const Key('appt_new')));
      await pumpUntil(tester, find.byKey(const Key('appt_route_title')));
    });

    testWidgets('führt vom Thema zur Wahl des Buchungswegs', (tester) async {
      await pumpApp(tester);
      await knowIt(tester);

      await tester.enterText(
        find.byKey(const Key('appt_title')),
        'Sehtest beim Optiker',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('appt_new')));
      await pumpUntil(tester, find.byKey(const Key('appt_route_title')));

      expect(find.text('Wie kommst du an den Termin?'), findsOneWidget);
    });
  });
}
