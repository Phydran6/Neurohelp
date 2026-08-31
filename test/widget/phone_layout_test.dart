import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_start_page.dart';
import 'package:neurohelp/features/calls/presentation/call_start_page.dart';
import 'package:neurohelp/features/help/presentation/help_page.dart';
import 'package:neurohelp/features/history/presentation/history_page.dart';
import 'package:neurohelp/features/home/presentation/main_menu_page.dart';
import 'package:neurohelp/features/home/presentation/start_page.dart';
import 'package:neurohelp/features/messages/presentation/message_start_page.dart';
import 'package:neurohelp/features/onboarding/presentation/onboarding_page.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:neurohelp/features/tasks/presentation/task_start_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Jeder Bereich einmal auf einem echten Telefon – mit offener Tastatur.
///
/// Das war die gemeinsame Wurzel aller Rückmeldungen aus dem Gerätetest: Die
/// Widget-Tests laufen von Haus aus auf 800x600, einem Blatt in Tabletgröße
/// ohne Tastatur. Dort passte alles. Auf einem 390x844-Telefon, von dem die
/// Tastatur die untere Hälfte nimmt, lief der Inhalt aus dem Bild – und was
/// aus dem Bild läuft, ist nicht zu bedienen.
///
/// Ein Überlauf lässt einen Widget-Test von selbst scheitern. Genau darum
/// geht es hier: Die Seiten müssen auf dem kleinen Blatt halten, nicht nur
/// auf dem großen.
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

const _longAnswer =
    'Handy schnappen und Nummer der Hausverwaltung raussuchen\n'
    'Kurz aufschreiben, worum es geht: was ist kaputt oder wofür sollen sie '
    'kommen\n'
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

  /// iPhone-Maß aus dem Gerätetest, dazu die Tastatur.
  void useAPhone(WidgetTester tester, {bool keyboard = true}) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    if (keyboard) {
      // Was die Tastatur auf einem iPhone wegnimmt.
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
    }
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester, {int frames = 40}) async {
    for (var frame = 0; frame < frames; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
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

  /// Holt ein Widget in den Blick, auch wenn die faule Liste es noch gar
  /// nicht gebaut hat. `ensureVisible` allein genügt dafür nicht: Es braucht
  /// ein Element, das es noch nicht gibt.
  Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        120,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<AppServices> aiServices() async {
    final services = AppServices.from(
      database,
      ai: _ScriptedAi(answer: _longAnswer),
    );
    await services.settings.setAiEnabled(enabled: true);
    return services;
  }

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    AppServices? services,
  }) async {
    await tester.pumpWidget(
      AppScope(
        services: services ?? AppServices.from(database),
        child: MaterialApp(home: page),
      ),
    );
    await settle(tester);
  }

  group('Einstiege halten auf dem Telefon', () {
    testWidgets('Startseite', (tester) async {
      useAPhone(tester, keyboard: false);
      await show(tester, const StartPage());
    });

    testWidgets('Hauptmenü', (tester) async {
      useAPhone(tester, keyboard: false);
      await show(tester, const MainMenuPage());
    });

    testWidgets('Aufgabe', (tester) async {
      useAPhone(tester);
      await show(tester, const TaskStartPage());
    });

    testWidgets('Anruf', (tester) async {
      useAPhone(tester);
      await show(tester, const CallStartPage());
    });

    testWidgets('Nachricht', (tester) async {
      useAPhone(tester);
      await show(tester, const MessageStartPage());
    });

    testWidgets('Termin', (tester) async {
      useAPhone(tester);
      await show(tester, const AppointmentStartPage());
    });

    testWidgets('Einstellungen', (tester) async {
      useAPhone(tester, keyboard: false);
      await show(tester, const SettingsPage());
    });

    testWidgets('Hilfe', (tester) async {
      useAPhone(tester, keyboard: false);
      await show(tester, const HelpPage());
    });

    testWidgets('Historie', (tester) async {
      useAPhone(tester, keyboard: false);
      await show(tester, const HistoryPage());
    });

    testWidgets('Onboarding', (tester) async {
      useAPhone(tester);
      await show(tester, OnboardingPage(onDone: () {}));
    });
  });

  group('KI-Block hält auf dem Telefon', () {
    testWidgets('Aufgabe: sechs Vorschläge und Tastatur', (tester) async {
      useAPhone(tester);
      final services = await aiServices();

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
        'HA anrufen ob vorbeikommen',
      );
      await tester.pumpAndSettle();
      await bringIntoView(tester, find.byKey(const Key('ai_ask')));
      await tester.tap(find.byKey(const Key('ai_ask')));
      await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

      // Jeder einzelne Vorschlag muss erreichbar sein – auch der letzte.
      for (var index = 0; index < 6; index++) {
        await bringIntoView(tester, find.byKey(Key('ai_suggestion_$index')));
      }
    });

    testWidgets('Anruf: sechs Vorschläge und Tastatur', (tester) async {
      useAPhone(tester);
      final services = await aiServices();

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

      await bringIntoView(tester, find.byKey(const Key('ai_ask')));
      await tester.tap(find.byKey(const Key('ai_ask')));
      await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

      await bringIntoView(tester, find.byKey(const Key('ai_accept_all')));
    });

    testWidgets('Nachricht: Vorschlag und Tastatur', (tester) async {
      useAPhone(tester);
      final services = AppServices.from(
        database,
        ai: _ScriptedAi(
          answer:
              'Sehr geehrte Damen und Herren, meine Karte ist abgelaufen und '
              'ich bräuchte eine neue. Mit freundlichen Grüßen',
        ),
      );
      await services.settings.setAiEnabled(enabled: true);

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: const MaterialApp(home: MessageStartPage()),
        ),
      );
      await pumpUntil(tester, find.byKey(const Key('msg_new')));
      await tester.tap(find.byKey(const Key('msg_new')));
      await pumpUntil(tester, find.byKey(const Key('msg_know')));
      await tester.tap(find.byKey(const Key('msg_know')));
      await tester.pumpAndSettle();

      Future<void> answer(String text) async {
        await tester.enterText(find.byKey(const Key('msg_field')), text);
        await tester.pump();
        await tester.tap(find.byKey(const Key('msg_next')));
        await tester.pumpAndSettle();
      }

      await answer('Neue Karte');
      await answer('Krankenkasse');
      await answer('service@aok.example');

      await tester.enterText(
        find.byKey(const Key('msg_field')),
        'Karte abgelaufen, brauche eine neue',
      );
      await tester.pumpAndSettle();
      await bringIntoView(tester, find.byKey(const Key('ai_ask')));
      await tester.tap(find.byKey(const Key('ai_ask')));
      await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

      await bringIntoView(tester, find.byKey(const Key('ai_suggestion_0')));
    });
  });
}
