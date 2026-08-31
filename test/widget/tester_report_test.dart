import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/calls/presentation/call_start_page.dart';
import 'package:neurohelp/features/tasks/presentation/task_start_page.dart';
import 'package:neurohelp/features/tasks/presentation/task_steps_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Die Rückmeldungen aus dem Gerätetest – jede als Test festgehalten.
///
/// Alle vier hingen an derselben Ursache: Die Seite wurde für ein breites
/// Blatt gebaut und auf einem Telefon benutzt. Deshalb läuft hier **alles**
/// auf Telefonmaß. Ein Überlauf ist in Widget-Tests ein Fehler und lässt den
/// Test von selbst scheitern – das ist hier der halbe Zweck.
class _ScriptedAi implements AiClient {
  _ScriptedAi({required this.answer});

  final String answer;
  bool enabled = true;

  @override
  bool get isEnabled => enabled;

  @override
  void setEnabled({required bool enabled}) => this.enabled = enabled;

  @override
  Future<void> probe() async {}

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async => answer;
}

/// Sechs Vorschläge wie im gemeldeten Fall – nicht zwei, die überall passen.
const _sixSuggestions =
    'Handy schnappen und Nummer der Hausverwaltung raussuchen\n'
    'Kurz aufschreiben, worum es geht: was ist kaputt\n'
    'Einen Satz notieren, mit dem du starten willst\n'
    'Zettel und Stift neben dich legen für Termin oder Rückmeldung\n'
    'Anrufen\n'
    'Falls niemand rangeht: kurz notieren, wann du es versucht hast';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() => database.close());

  /// Ein Telefon, kein Tablet. Auf 800x600 (der Vorgabe im Test) passte alles
  /// – genau deshalb fiel keiner der Fehler je im Test auf.
  void useAPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int tries = 60,
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

  Future<AppServices> withAi(String answer) async {
    final services = AppServices.from(
      database,
      ai: _ScriptedAi(answer: answer),
    );
    await services.settings.setAiEnabled(enabled: true);
    return services;
  }

  Future<void> openNewTask(WidgetTester tester, AppServices services) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: TaskStepsPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('task_know')));
    await tester.tap(find.byKey(const Key('task_know')));
    await pumpUntil(tester, find.byKey(const Key('task_title_field')));
  }

  group('Aufgabe auf dem Telefon', () {
    testWidgets('„da lässt sich nichts übernehmen": der Schritt kommt an', (
      tester,
    ) async {
      useAPhone(tester);
      final services = await withAi(_sixSuggestions);
      await openNewTask(tester, services);

      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'HA anrufen ob vorbeikommen',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai_ask')));
      await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

      await tester.ensureVisible(find.byKey(const Key('ai_suggestion_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai_suggestion_0')));
      await tester.pumpAndSettle();

      // Die Kachel sagt selbst Bescheid – vorher war der einzige Hinweis
      // eine Liste, die auf dem Telefon außerhalb des Bildes lag.
      expect(find.byKey(const Key('ai_suggestion_taken_0')), findsOneWidget);
      // Und der Schritt steht wirklich in der eigenen Liste.
      expect(find.byKey(const Key('task_step_0')), findsOneWidget);
    });

    testWidgets('„nach unten scrollen kann ich auch nicht": die Seite rollt', (
      tester,
    ) async {
      useAPhone(tester);
      final services = await withAi(_sixSuggestions);
      await openNewTask(tester, services);

      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'HA anrufen ob vorbeikommen',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai_ask')));
      await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

      // Der sechste Vorschlag liegt unter dem Blattrand. Er muss erreichbar
      // sein – vorher gab es auf dieser Seite gar keinen Scrollbereich.
      await tester.ensureVisible(find.byKey(const Key('ai_suggestion_5')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_suggestion_5')), findsOneWidget);
    });

    testWidgets('„Alle übernehmen" ist auf Telefonbreite ganz zu sehen', (
      tester,
    ) async {
      useAPhone(tester);
      final services = await withAi(_sixSuggestions);
      await openNewTask(tester, services);

      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'HA anrufen ob vorbeikommen',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('ai_ask')));
      await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

      await tester.ensureVisible(find.byKey(const Key('ai_accept_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai_accept_all')));
      await tester.pumpAndSettle();

      // Alle sechs sind in der Liste gelandet.
      expect(find.byKey(const Key('task_step_5')), findsOneWidget);
    });
  });

  group('„Was gehört dazu" ist freiwillig', () {
    testWidgets('ein Titel allein genügt für „Los geht’s"', (tester) async {
      useAPhone(tester);
      final services = AppServices.from(database);
      await openNewTask(tester, services);

      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'kardiologe anrufen',
      );
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('task_start')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('ohne Schritt wird die Aufgabe selbst zum Schritt', (
      tester,
    ) async {
      useAPhone(tester);
      final services = AppServices.from(database);

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: const MaterialApp(home: TaskStartPage()),
        ),
      );
      await pumpUntil(tester, find.byKey(const Key('task_new')));
      await tester.tap(find.byKey(const Key('task_new')));
      await pumpUntil(tester, find.byKey(const Key('task_know')));
      await tester.tap(find.byKey(const Key('task_know')));
      await pumpUntil(tester, find.byKey(const Key('task_title_field')));

      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'kardiologe anrufen',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task_start')));
      await pumpUntil(tester, find.byKey(const Key('focus_step')));

      // Nicht „alles erledigt": Es gibt genau eine Sache zu tun, und das ist
      // die Aufgabe selbst. (Der Titel steht zusätzlich in der Kopfzeile –
      // deshalb über den Schlüssel prüfen, nicht über den Text.)
      expect(find.byKey(const Key('focus_done')), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('focus_step'))).data,
        'kardiologe anrufen',
      );
    });

    testWidgets('ohne Thema und ohne Schritt: Herausfinden ist der Schritt', (
      tester,
    ) async {
      useAPhone(tester);
      final services = AppServices.from(database);

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: const MaterialApp(home: TaskStartPage()),
        ),
      );
      await pumpUntil(tester, find.byKey(const Key('task_new')));
      await tester.tap(find.byKey(const Key('task_new')));
      // Der andere Weg: „Ich weiß es nicht mehr."
      await pumpUntil(tester, find.byKey(const Key('task_recall')));
      await tester.tap(find.byKey(const Key('task_recall')));
      await pumpUntil(tester, find.byKey(const Key('task_start')));

      await tester.tap(find.byKey(const Key('task_start')));
      await pumpUntil(tester, find.byKey(const Key('focus_step')));

      // „Noch ohne Thema" ist ein Platzhalter für die Historie, keine
      // Sache, die jemand tun kann.
      expect(
        tester.widget<Text>(find.byKey(const Key('focus_step'))).data,
        'Herausfinden, worum es geht',
      );
    });

    testWidgets('ein getippter Schritt geht ohne „+" nicht verloren', (
      tester,
    ) async {
      useAPhone(tester);
      final services = AppServices.from(database);

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: const MaterialApp(home: TaskStartPage()),
        ),
      );
      await pumpUntil(tester, find.byKey(const Key('task_new')));
      await tester.tap(find.byKey(const Key('task_new')));
      await pumpUntil(tester, find.byKey(const Key('task_know')));
      await tester.tap(find.byKey(const Key('task_know')));
      await pumpUntil(tester, find.byKey(const Key('task_title_field')));

      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'kardiologe anrufen',
      );
      // Genau der gemeldete Fall: getippt, aber nie auf „+" gedrückt.
      await tester.enterText(
        find.byKey(const Key('task_step_field')),
        'termin nach hinten verschieben',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task_start')));
      await pumpUntil(tester, find.byKey(const Key('focus_step')));

      expect(find.text('termin nach hinten verschieben'), findsOneWidget);
    });
  });

  group('Anruf auf dem Telefon', () {
    testWidgets('ein getippter Stichpunkt geht ohne „+" nicht verloren', (
      tester,
    ) async {
      useAPhone(tester);
      final services = AppServices.from(database);

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: const MaterialApp(home: CallStartPage()),
        ),
      );
      await pumpUntil(tester, find.byKey(const Key('call_title')));
      await tester.tap(find.byKey(const Key('call_category_Arzt')));
      await pumpUntil(tester, find.byKey(const Key('call_know')));
      await tester.tap(find.byKey(const Key('call_know')));
      await pumpUntil(tester, find.byKey(const Key('call_number')));

      await tester.enterText(
        find.byKey(const Key('call_number')),
        '0301234567',
      );
      await tester.enterText(
        find.byKey(const Key('call_point_field')),
        'Termin absagen',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('call_ready')));
      await pumpUntil(tester, find.byKey(const Key('call_active_point_0')));

      expect(find.text('Termin absagen'), findsOneWidget);
    });
  });
}
