import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/history/domain/history_event.dart';
import 'package:neurohelp/features/appointments/domain/appointment.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_book_page.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_route_page.dart';
import 'package:neurohelp/features/calls/presentation/call_active_page.dart';
import 'package:neurohelp/features/history/presentation/history_detail_page.dart';
import 'package:neurohelp/features/tasks/presentation/task_focus_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Die Unterseiten – auf dem Telefon und bei großer Schrift.
///
/// Die Einstiege sind in `phone_layout_test.dart` und `text_scale_test.dart`
/// abgedeckt. Der Test meldete aber „viele Untermenüs in den einzelnen
/// Teilfunktionen teilweise defekt", und die liegen eine Ebene tiefer: der
/// Fokus-Modus, das Buchen, der laufende Anruf, ein Eintrag in der Historie.
///
/// Ein Überlauf lässt einen Widget-Test von selbst scheitern.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    services = AppServices.from(database);
  });

  tearDown(() => database.close());

  void useAPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> show(WidgetTester tester, Widget page, double scale) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: page,
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  // Lange Texte, wie sie die KI liefert – nicht die kurzen aus den
  // Ablauf-Tests. Genau daran ist die Aufgaben-Seite gescheitert.
  const longStep =
      'Einen Satz notieren, mit dem du starten willst, zum Beispiel: '
      '"Hallo, hier ist [Name] aus der [Adresse], ich wollte fragen, ob '
      'jemand vorbeikommen kann"';

  for (final scale in [1.0, 1.6, 2.0]) {
    testWidgets('Fokus-Modus mit langem Schritt bei $scale', (tester) async {
      useAPhone(tester);
      final entryId = await services.tasks.createTask('Hausverwaltung');
      await services.tasks.addSteps(entryId, titles: [longStep]);

      await show(
        tester,
        TaskFocusPage(entryId: entryId, title: 'Hausverwaltung'),
        scale,
      );
    });

    testWidgets('Buchungsweg bei $scale', (tester) async {
      useAPhone(tester);
      final appointment = await services.appointments.create(
        'Sehtest beim Optiker, möglichst nachmittags',
      );

      await show(
        tester,
        AppointmentRoutePage(appointmentId: appointment.id),
        scale,
      );
    });

    testWidgets('Termin eintragen bei $scale', (tester) async {
      useAPhone(tester);
      final appointment = await services.appointments.create('Sehtest');
      await services.appointments.chooseRoute(
        appointment.id,
        BookingRoute.phone,
      );

      await show(
        tester,
        AppointmentBookPage(appointmentId: appointment.id),
        scale,
      );
    });

    testWidgets('Laufender Anruf mit langen Stichpunkten bei $scale', (
      tester,
    ) async {
      useAPhone(tester);
      final plan = await services.calls.create(category: 'Arzt');
      await services.calls.save(
        plan.copyWith(
          goal: 'Termin für einen Sehtest, möglichst noch diese Woche',
          contactNumber: '030 1234567',
          talkingPoints: [longStep, longStep, longStep],
        ),
      );

      await show(tester, CallActivePage(planId: plan.id), scale);
    });

    testWidgets('Historie-Eintrag bei $scale', (tester) async {
      useAPhone(tester);
      final entry = await services.history.startEntry(
        feature: HistoryFeature.task,
        title: 'Hausverwaltung anrufen wegen der kaputten Heizung',
      );
      await services.history.logEvent(
        entry.id,
        HistoryEventKind.stepAdded,
        note: longStep,
      );

      await show(tester, HistoryDetailPage(entryId: entry.id), scale);
    });
  }
}
