import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/features/calls/domain/call_launcher.dart';
import 'package:neurohelp/features/calls/domain/call_plan.dart';
import 'package:neurohelp/features/calls/presentation/call_start_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Merkt sich die Nummer, statt wirklich zu wählen.
class _RecordingDialer implements CallLauncher {
  String? dialled;

  @override
  Future<bool> dial(String number) async {
    dialled = number;
    return true;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late _RecordingDialer dialer;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    dialer = _RecordingDialer();
    services = AppServices.from(database, dialer: dialer);
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
        child: const MaterialApp(home: CallStartPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('call_title')));
  }

  Future<void> prepare(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('call_category_Arzt')));
    // Erst die Eingangsfrage: Ich weiß, was ich erreichen will.
    await pumpUntil(tester, find.byKey(const Key('call_know')));
    await tester.tap(find.byKey(const Key('call_know')));
    await pumpUntil(tester, find.byKey(const Key('call_number')));

    await tester.enterText(
      find.byKey(const Key('call_goal')),
      'Termin für einen Sehtest',
    );
    await tester.enterText(find.byKey(const Key('call_number')), '030 1234567');
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('call_point_field')),
      'Nachmittags passt besser',
    );
    // Der Knopf richtet sich nach dem Feldinhalt – ohne Pump kennt er ihn
    // noch nicht und ist aus.
    await tester.pump();
    await tester.tap(find.byKey(const Key('call_point_add')));
    await pumpUntil(tester, find.byKey(const Key('call_point_0')));
  }

  testWidgets('beginnt mit der Kategorie, nicht mit einem leeren Feld', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Wen rufst du an?'), findsOneWidget);
    for (final category in CallStartPage.categories) {
      expect(find.byKey(Key('call_category_$category')), findsOneWidget);
    }
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('ohne Nummer oder Stichpunkte bleibt der Knopf aus', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('call_category_Arzt')));
    await pumpUntil(tester, find.byKey(const Key('call_know')));
    await tester.tap(find.byKey(const Key('call_know')));
    await pumpUntil(tester, find.byKey(const Key('call_ready')));

    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('call_ready')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('zeigt die Stichpunkte und wählt die Nummer', (tester) async {
    await pumpApp(tester);
    await prepare(tester);

    await tester.tap(find.byKey(const Key('call_ready')));
    await pumpUntil(tester, find.byKey(const Key('call_dial')));

    // Der Leitfaden steht da, bevor gewählt wird.
    expect(find.text('Nachmittags passt besser'), findsOneWidget);
    expect(find.byKey(const Key('call_goal_text')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_dial')));
    await pumpUntil(tester, find.byKey(const Key('call_outcome_question')));

    expect(dialer.dialled, '030 1234567');
    // Nachbereitung: eine Frage, zwei Antworten.
    expect(find.text('Hat es geklappt?'), findsOneWidget);
    expect(find.byKey(const Key('call_yes')), findsOneWidget);
    expect(find.byKey(const Key('call_no')), findsOneWidget);
  });

  testWidgets('Notizen entstehen erst nach dem Anruf', (tester) async {
    await pumpApp(tester);
    await prepare(tester);
    await tester.tap(find.byKey(const Key('call_ready')));
    await pumpUntil(tester, find.byKey(const Key('call_dial')));

    // Vorher gibt es kein Notizfeld – auf iOS wäre es während des
    // Gesprächs ohnehin nicht beschreibbar.
    expect(find.byKey(const Key('call_note')), findsNothing);

    await tester.tap(find.byKey(const Key('call_dial')));
    await pumpUntil(tester, find.byKey(const Key('call_note')));
  });

  testWidgets('Nein lässt den Vorgang offen für Weiterhilfe', (tester) async {
    await pumpApp(tester);
    await prepare(tester);
    await tester.tap(find.byKey(const Key('call_ready')));
    await pumpUntil(tester, find.byKey(const Key('call_dial')));
    await tester.tap(find.byKey(const Key('call_dial')));
    await pumpUntil(tester, find.byKey(const Key('call_no')));

    await tester.tap(find.byKey(const Key('call_no')));
    await tester.pumpAndSettle();

    final calls = await services.calls.previousInCategory('Arzt');
    expect(calls.single.outcome, CallOutcome.failed);

    final entry = await services.history.entryById(calls.single.entryId);
    expect(entry!.status, HistoryStatus.open);
  });

  testWidgets('fragt nach einem früheren Vorgang derselben Kategorie', (
    tester,
  ) async {
    final earlier = await services.calls.create(
      category: 'Arzt',
      topic: 'Rezept',
    );
    await services.calls.save(earlier.copyWith(goal: 'Rezept abholen'));

    await pumpApp(tester);

    // Historie-Check beim Einstieg: Der offene Vorgang steht schon da,
    // bevor eine Kategorie angetippt wurde.
    expect(find.byKey(const Key('history_check_found')), findsOneWidget);
    expect(find.byKey(Key('call_open_${earlier.id}')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call_category_Arzt')));
    await pumpUntil(tester, find.byKey(const Key('call_earlier_title')));

    // „Geht's um das von letztem Mal?" – Konzept, Abschnitt 8, Schritt 2.
    // Auf den Eintrag im Blatt prüfen: Derselbe Text steht auch in der
    // Liste dahinter, und ein findsOneWidget wäre dort schon erfüllt.
    expect(
      find.descendant(
        of: find.byKey(Key('call_earlier_${earlier.id}')),
        matching: find.text('Rezept abholen'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('call_earlier_new')), findsOneWidget);
  });

  testWidgets('sagt auch, wenn die Historie nichts hergibt', (tester) async {
    await pumpApp(tester);

    // Der stumme Fall war der Fehler: Ohne Rückmeldung weiß der User nicht,
    // ob überhaupt gesucht wurde.
    expect(find.byKey(const Key('history_check_empty')), findsOneWidget);
  });
}
