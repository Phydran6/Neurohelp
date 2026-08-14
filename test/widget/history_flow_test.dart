import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/history/domain/history_event.dart';
import 'package:neurohelp/features/history/presentation/history_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  Future<void> pumpHistory(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('history_summary')));
  }

  /// Legt einen Vorgang an, wie ihn ein Feature anlegen würde.
  Future<HistoryEntry> seed(
    HistoryFeature feature,
    String title, {
    String? contact,
    bool done = false,
  }) async {
    final entry = await services.history.startEntry(
      feature: feature,
      title: title,
      contact: contact,
    );
    if (done) await services.history.closeEntry(entry.id);
    return entry;
  }

  testWidgets('sagt Bescheid, wenn noch gar nichts da ist', (tester) async {
    await pumpHistory(tester);

    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    expect(find.textContaining('Noch ist nichts da'), findsOneWidget);
  });

  testWidgets('zeigt Vorgänge aus allen Features', (tester) async {
    await seed(HistoryFeature.call, 'Optiker anrufen');
    await seed(HistoryFeature.task, 'Umzug organisieren');
    await seed(HistoryFeature.message, 'Mail an die Krankenkasse', done: true);

    await pumpHistory(tester);

    // Erledigtes gehört dazu: Die Historie ist ein Verlauf, keine Aufgabenliste.
    expect(find.text('Optiker anrufen'), findsOneWidget);
    expect(find.text('Umzug organisieren'), findsOneWidget);
    expect(find.text('Mail an die Krankenkasse'), findsOneWidget);
  });

  testWidgets('filtert auf ein einzelnes Feature', (tester) async {
    await seed(HistoryFeature.call, 'Optiker anrufen');
    await seed(HistoryFeature.task, 'Umzug organisieren');

    await pumpHistory(tester);
    await tester.tap(find.byKey(const Key('history_filter_call')));
    await tester.pumpAndSettle();

    expect(find.text('Optiker anrufen'), findsOneWidget);
    expect(find.text('Umzug organisieren'), findsNothing);
  });

  testWidgets('findet auch, was längst erledigt ist', (tester) async {
    await seed(
      HistoryFeature.call,
      'Sehtest beim Optiker',
      contact: 'Optik Meyer',
      done: true,
    );
    await seed(HistoryFeature.task, 'Steuer sortieren');

    await pumpHistory(tester);

    // „Ich weiß nur, dass da was war" – zuerst gräbt die App.
    await tester.enterText(find.byKey(const Key('history_search')), 'optik');
    await tester.pumpAndSettle();

    expect(find.text('Sehtest beim Optiker'), findsOneWidget);
    expect(find.text('Steuer sortieren'), findsNothing);
  });

  testWidgets('nur offene blendet Erledigtes aus', (tester) async {
    await seed(HistoryFeature.task, 'Läuft noch');
    await seed(HistoryFeature.task, 'Ist durch', done: true);

    await pumpHistory(tester);
    await tester.tap(find.byKey(const Key('history_open_only')));
    await tester.pumpAndSettle();

    expect(find.text('Läuft noch'), findsOneWidget);
    expect(find.text('Ist durch'), findsNothing);
  });

  testWidgets('zeigt das Protokoll eines Vorgangs', (tester) async {
    final entry = await seed(HistoryFeature.task, 'Umzug organisieren');
    await services.history.logEvent(
      entry.id,
      HistoryEventKind.stepDone,
      note: 'Kartons besorgt',
    );

    await pumpHistory(tester);
    await tester.tap(find.byKey(Key('history_item_${entry.id}')));
    await pumpUntil(tester, find.byKey(const Key('history_detail_title')));

    // Designprinzip 9: Alles wird geloggt – und jetzt auch gezeigt.
    expect(find.text('Schritt erledigt'), findsOneWidget);
    expect(find.text('Kartons besorgt'), findsOneWidget);
    expect(find.text('Angefangen'), findsOneWidget);
  });

  testWidgets('ein Vorgang lässt sich von Hand abhaken', (tester) async {
    final entry = await seed(HistoryFeature.call, 'Nebenbei erledigt');

    await pumpHistory(tester);
    await tester.tap(find.byKey(Key('history_item_${entry.id}')));
    await pumpUntil(tester, find.byKey(const Key('history_toggle_status')));

    await tester.tap(find.byKey(const Key('history_toggle_status')));
    await tester.pumpAndSettle();

    final updated = await services.history.entryById(entry.id);
    expect(updated!.status, HistoryStatus.done);
  });

  testWidgets('löschen räumt auch das Protokoll weg', (tester) async {
    final entry = await seed(HistoryFeature.task, 'Weg damit');
    await services.history.logEvent(entry.id, HistoryEventKind.stepAdded);

    await pumpHistory(tester);
    await tester.tap(find.byKey(Key('history_item_${entry.id}')));
    await pumpUntil(tester, find.byKey(const Key('history_delete')));

    await tester.tap(find.byKey(const Key('history_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_delete_confirm')));
    await tester.pumpAndSettle();

    expect(await services.history.entryById(entry.id), isNull);
    expect(await services.history.eventsFor(entry.id), isEmpty);
  });
}
