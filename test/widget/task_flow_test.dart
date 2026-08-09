import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/tasks/presentation/task_start_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Ohne eigenen Isolate: In Widget-Tests läuft die Zeit simuliert, und
    // ein Future, der über eine Isolate-Grenze zurückkommt, wird dort nie
    // eingelöst. Die In-Process-Variante löst auf einer Microtask auf, die
    // der Test-Zeitgeber mitnimmt.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    services = AppServices.from(database);
  });

  tearDown(() => database.close());

  /// Pumpt, bis [finder] etwas findet.
  ///
  /// `pumpAndSettle` allein genügt nicht: Es wartet auf Animationen, nicht
  /// auf Futures, und die Seiten laden ihre Daten aus der Datenbank.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int tries = 40,
  }) async {
    for (var attempt = 0; attempt < tries; attempt++) {
      if (finder.evaluate().isNotEmpty) {
        // Vorhanden heißt noch nicht bedienbar: Beim Seitenwechsel schiebt
        // sich die neue Seite erst herein. Wer zu früh tippt, trifft daneben.
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
        child: const MaterialApp(home: TaskStartPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('task_new')));
  }

  testWidgets('legt eine Aufgabe an und führt in den Fokus-Modus', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('task_new')));
    await pumpUntil(tester, find.byKey(const Key('task_title_field')));

    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Umzug organisieren',
    );
    await tester.enterText(
      find.byKey(const Key('task_step_field')),
      'Kartons besorgen',
    );
    await tester.tap(find.byKey(const Key('task_step_add')));
    // Auf den Listeneintrag warten, nicht auf den Text: Der steht sonst
    // auch noch im Eingabefeld und der Test wäre grün, ohne dass etwas
    // hinzugefügt wurde.
    await pumpUntil(tester, find.byKey(const Key('task_step_0')));

    await tester.enterText(
      find.byKey(const Key('task_step_field')),
      'Kündigung schreiben',
    );
    await tester.tap(find.byKey(const Key('task_step_add')));
    await pumpUntil(tester, find.byKey(const Key('task_step_1')));

    await tester.tap(find.byKey(const Key('task_start')));
    await pumpUntil(tester, find.byKey(const Key('focus_step')));

    // Fokus-Modus: nur der erste Schritt ist zu sehen, nicht der Berg.
    expect(find.text('Kartons besorgen'), findsOneWidget);
    expect(find.text('Kündigung schreiben'), findsNothing);
  });

  testWidgets('zeigt nach dem Abhaken den nächsten Schritt', (tester) async {
    final entryId = await services.tasks.createTask('Steuer');
    await services.tasks.addSteps(
      entryId,
      titles: ['Lohnbescheinigung suchen', 'Belege sortieren'],
    );

    await pumpApp(tester);

    // Historie-Check: der offene Vorgang steht da, ohne dass der User
    // etwas eingeben musste.
    expect(find.byKey(const Key('task_open_title')), findsOneWidget);
    await tester.tap(find.byKey(Key('task_open_$entryId')));
    await pumpUntil(tester, find.text('Lohnbescheinigung suchen'));

    await tester.tap(find.byKey(const Key('focus_complete')));
    await pumpUntil(tester, find.text('Belege sortieren'));

    expect(find.text('Lohnbescheinigung suchen'), findsNothing);
  });

  testWidgets('sagt am Ende schlicht Bescheid, ohne Lob', (tester) async {
    final entryId = await services.tasks.createTask('Wäsche');
    await services.tasks.addSteps(entryId, titles: ['Waschen']);

    await pumpApp(tester);
    await tester.tap(find.byKey(Key('task_open_$entryId')));
    await pumpUntil(tester, find.byKey(const Key('focus_complete')));

    await tester.tap(find.byKey(const Key('focus_complete')));
    await pumpUntil(tester, find.byKey(const Key('focus_done')));

    // Kein Lob, keine Gamification – nur eine Feststellung.
    expect(find.text('Alles abgehakt.'), findsOneWidget);
  });

  testWidgets('ohne Titel oder Schritte bleibt der Knopf aus', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('task_new')));
    await pumpUntil(tester, find.byKey(const Key('task_start')));

    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('task_start')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });
}
