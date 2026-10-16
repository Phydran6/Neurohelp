import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/features/history/presentation/history_detail_page.dart';
import 'package:neurohelp/features/history/presentation/history_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prüft den Weg aus der Historie zurück in den Ablauf (Konzept,
/// Abschnitt 12).
///
/// **Das war die Lücke.** Die Historie konnte einen Vorgang zeigen und
/// seinen Zustand ändern – mehr nicht. Wer dort seine angefangene Aufgabe
/// wiederfand, stand vor einem Protokoll und musste den Ablauf von vorn
/// suchen. Für eine App, deren ganzer Sinn „du musst dir nichts merken"
/// ist, war das der falsche Weg.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Siehe CLAUDE.md: In Widget-Tests kommt ein Future über eine
    // Isolate-Grenze nie an.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    services = AppServices.from(database);
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

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(home: page),
      ),
    );
  }

  /// Eine Aufgabe mit Schritten – der Normalfall, an dem man weiterarbeitet.
  Future<String> seedTask(String title, {bool withSteps = true}) async {
    final entryId = await services.tasks.createTask(title);
    if (withSteps) {
      await services.tasks.addSteps(entryId, titles: ['Kartons besorgen']);
    }
    return entryId;
  }

  group('In der Liste', () {
    testWidgets('steht an offenen Vorgängen der kurze Weg zurück', (
      tester,
    ) async {
      final entryId = await seedTask('Umzug organisieren');

      await pumpPage(tester, const HistoryPage());
      await pumpUntil(tester, find.byKey(Key('history_item_$entryId')));

      expect(find.byKey(Key('history_resume_$entryId')), findsOneWidget);
    });

    testWidgets('an erledigten nicht – da gibt es nichts fortzusetzen', (
      tester,
    ) async {
      final entryId = await seedTask('Schon erledigt');
      await services.history.closeEntry(entryId);

      await pumpPage(tester, const HistoryPage());
      await pumpUntil(tester, find.byKey(Key('history_item_$entryId')));

      expect(find.byKey(Key('history_resume_$entryId')), findsNothing);
    });

    testWidgets('und der Knopf führt in den Fokus, nicht ins Protokoll', (
      tester,
    ) async {
      final entryId = await seedTask('Umzug organisieren');

      await pumpPage(tester, const HistoryPage());
      await pumpUntil(tester, find.byKey(Key('history_resume_$entryId')));

      await tester.tap(find.byKey(Key('history_resume_$entryId')));
      await pumpUntil(tester, find.byKey(const Key('focus_step')));

      expect(find.text('Kartons besorgen'), findsOneWidget);
    });
  });

  group('Im Detail', () {
    testWidgets('steht der Knopf mit dem Verb des Ablaufs', (tester) async {
      final entryId = await seedTask('Umzug organisieren');

      await pumpPage(tester, HistoryDetailPage(entryId: entryId));
      await pumpUntil(tester, find.byKey(const Key('history_resume')));

      expect(find.text('Weiter an der Aufgabe'), findsOneWidget);
    });

    testWidgets('bei einem erledigten Vorgang fehlt er', (tester) async {
      final entryId = await seedTask('Schon erledigt');
      await services.history.closeEntry(entryId);

      await pumpPage(tester, HistoryDetailPage(entryId: entryId));
      await pumpUntil(tester, find.byKey(const Key('history_detail_title')));

      expect(find.byKey(const Key('history_resume')), findsNothing);
      // Der Weg zurück bleibt trotzdem offen – über „Wieder öffnen".
      expect(find.byKey(const Key('history_toggle_status')), findsOneWidget);
    });

    testWidgets('eine Aufgabe ohne Schritte geht ans Zerlegen', (tester) async {
      // Beim Anlegen abgebrochen: Im Fokus-Modus gäbe es nichts zu zeigen.
      final entryId = await seedTask(
        'Angefangen, nie zerlegt',
        withSteps: false,
      );

      await pumpPage(tester, HistoryDetailPage(entryId: entryId));
      await pumpUntil(tester, find.byKey(const Key('history_resume')));

      await tester.tap(find.byKey(const Key('history_resume')));
      await pumpUntil(tester, find.byKey(const Key('task_step_field')));

      expect(find.text('Aufgabe weiter zerlegen'), findsOneWidget);
      // Der Titel steht schon da – er muss nicht neu getippt werden.
      final title = tester.widget<TextField>(
        find.byKey(const Key('task_title_field')),
      );
      expect(title.controller?.text, 'Angefangen, nie zerlegt');
    });

    testWidgets('und das Zerlegen legt keinen zweiten Vorgang an', (
      tester,
    ) async {
      final entryId = await seedTask('Nur einmal', withSteps: false);

      await pumpPage(tester, HistoryDetailPage(entryId: entryId));
      await pumpUntil(tester, find.byKey(const Key('history_resume')));
      await tester.tap(find.byKey(const Key('history_resume')));
      await pumpUntil(tester, find.byKey(const Key('task_step_field')));

      await tester.enterText(
        find.byKey(const Key('task_step_field')),
        'Erster Schritt',
      );
      await tester.tap(find.byKey(const Key('task_step_add')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task_start')));
      await pumpUntil(tester, find.byKey(const Key('focus_step')));

      final entries = await services.history.recentEntries(
        feature: HistoryFeature.task,
      );
      expect(entries, hasLength(1));
      expect(entries.single.id, entryId);
      expect((await services.tasks.loadTree(entryId)).steps, hasLength(1));
    });

    testWidgets('ein Vorgang ohne Ablauf sagt, warum es nicht weitergeht', (
      tester,
    ) async {
      // Eine Nachricht, deren Entwurf es nicht mehr gibt: Der Vorgang steht
      // in der Historie, aber dahinter liegt nichts.
      final entry = await services.history.startEntry(
        feature: HistoryFeature.message,
        title: 'Verwaister Vorgang',
      );

      await pumpPage(tester, HistoryDetailPage(entryId: entry.id));
      await pumpUntil(tester, find.byKey(const Key('history_resume')));

      await tester.tap(find.byKey(const Key('history_resume')));
      await pumpUntil(tester, find.byKey(const Key('history_resume_blocked')));

      // Kein stummer Knopf: Es steht da, was stattdessen gilt.
      expect(find.textContaining('nur noch das Protokoll'), findsOneWidget);
    });
  });
}
