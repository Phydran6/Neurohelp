import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prüft die Vorschaltung vor den Einstellungen (Konzept, Abschnitt 4).
///
/// Die Frage „Ich weiß, was ich tue" oder „Ich hab keinen Plan" ist der
/// ganze Punkt des Umbaus: Dieselben Möglichkeiten, zwei Sprachen. Was hier
/// zählt, ist, dass die Wahl **hängen bleibt** und sich **zurücknehmen**
/// lässt – eine Einbahnstraße wäre schlimmer als gar keine Frage.
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

  Future<void> pumpSettings(WidgetTester tester) async {
    // Hoher Bildschirm: Die Einstellungen sind eine ListView, und was nicht
    // sichtbar ist, wird auch nicht gebaut.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
  }

  testWidgets('fragt beim ersten Öffnen, wie ausführlich es sein soll', (
    tester,
  ) async {
    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('settings_gate_question')));

    expect(find.byKey(const Key('settings_gate_guided')), findsOneWidget);
    expect(find.byKey(const Key('settings_gate_expert')), findsOneWidget);

    // Kein Urteil: Beide Antworten stehen gleichwertig nebeneinander.
    expect(find.text('Ich hab keinen Plan'), findsOneWidget);
    expect(find.text('Ich weiß, was ich tue'), findsOneWidget);
  });

  testWidgets('„Ich weiß, was ich tue" führt zu allen Schaltern', (
    tester,
  ) async {
    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('settings_gate_expert')));

    await tester.tap(find.byKey(const Key('settings_gate_expert')));
    await pumpUntil(tester, find.byKey(const Key('settings_ai')));

    // Die Dinge, die es nur im Expertenweg gibt.
    expect(find.byKey(const Key('settings_custom_ai')), findsNothing);
    expect(find.byKey(const Key('settings_backup')), findsOneWidget);
    expect(find.byKey(const Key('theme_dark')), findsOneWidget);

    expect((await services.settings.load()).settingsMode, SettingsMode.expert);
  });

  testWidgets('„Ich hab keinen Plan" führt zu Entscheidungen statt Schaltern', (
    tester,
  ) async {
    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('settings_gate_guided')));

    await tester.tap(find.byKey(const Key('settings_gate_guided')));
    await pumpUntil(tester, find.byKey(const Key('guided_ai')));

    expect(find.byKey(const Key('guided_backup_auto')), findsOneWidget);
    expect(find.byKey(const Key('guided_theme_dark')), findsOneWidget);

    // Kein Wort, das jemand nachschlagen müsste.
    expect(find.textContaining('OpenRouter'), findsNothing);
    expect(find.textContaining('API'), findsNothing);

    expect((await services.settings.load()).settingsMode, SettingsMode.guided);
  });

  testWidgets('die Wahl bleibt beim nächsten Öffnen stehen', (tester) async {
    await services.settings.setSettingsMode(SettingsMode.guided);

    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('guided_ai')));

    expect(find.byKey(const Key('settings_gate_question')), findsNothing);
  });

  testWidgets('und lässt sich jederzeit zurücknehmen', (tester) async {
    await services.settings.setSettingsMode(SettingsMode.expert);

    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('settings_ai')));

    await tester.tap(find.byKey(const Key('settings_switch_mode')));
    await pumpUntil(tester, find.byKey(const Key('settings_gate_question')));

    expect((await services.settings.load()).settingsMode, SettingsMode.unset);
  });

  testWidgets('dunkel lässt sich im Expertenweg fest einstellen', (
    tester,
  ) async {
    await services.settings.setSettingsMode(SettingsMode.expert);

    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('theme_dark')));

    await tester.tap(find.byKey(const Key('theme_dark')));
    await tester.pumpAndSettle();

    expect((await services.settings.load()).themeChoice, AppThemeChoice.dark);
  });

  testWidgets('und genauso im geführten Weg', (tester) async {
    await services.settings.setSettingsMode(SettingsMode.guided);

    await pumpSettings(tester);
    await pumpUntil(tester, find.byKey(const Key('guided_theme_dark')));

    await tester.tap(find.byKey(const Key('guided_theme_dark')));
    await tester.pumpAndSettle();

    expect((await services.settings.load()).themeChoice, AppThemeChoice.dark);
  });
}
