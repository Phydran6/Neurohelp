import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/help/presentation/help_page.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(home: page),
      ),
    );
  }

  group('Einstellungen', () {
    testWidgets('KI ist zunächst aus und die App läuft lokal', (tester) async {
      await pump(tester, const SettingsPage());
      await pumpUntil(tester, find.byKey(const Key('settings_ai')));

      final ai = tester.widget<SwitchListTile>(
        find.byKey(const Key('settings_ai')),
      );
      expect(ai.value, isFalse);

      final note = tester.widget<Text>(
        find.byKey(const Key('settings_ai_note')),
      );
      expect(note.data, contains('vollständig auf deinem Gerät'));
    });

    testWidgets('KI lässt sich ein- und wieder ausschalten', (tester) async {
      await pump(tester, const SettingsPage());
      await pumpUntil(tester, find.byKey(const Key('settings_ai')));

      await tester.tap(find.byKey(const Key('settings_ai')));
      await pumpUntil(tester, find.byKey(const Key('settings_ai')));
      expect((await services.settings.load()).aiEnabled, isTrue);

      await tester.tap(find.byKey(const Key('settings_ai')));
      await pumpUntil(tester, find.byKey(const Key('settings_ai')));
      expect((await services.settings.load()).aiEnabled, isFalse);
    });

    testWidgets('der Ton lässt sich umstellen und bleibt erhalten', (
      tester,
    ) async {
      await pump(tester, const SettingsPage());
      await pumpUntil(tester, find.byKey(const Key('tone_sachlich')));

      await tester.tap(find.byKey(const Key('tone_sachlich')));
      await tester.pumpAndSettle();

      expect((await services.settings.load()).tone, AiTone.sachlich);
    });
  });

  group('Hilfe & Info', () {
    testWidgets('zeigt die festen Antworten ohne Nachfragen', (tester) async {
      await pump(tester, const HelpPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('faq_wo-liegen-meine-daten')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('faq_ohne-ki')), findsOneWidget);
    });

    testWidgets('beantwortet eine Frage aus dem Katalog, ohne KI', (
      tester,
    ) async {
      await pump(tester, const HelpPage());
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('help_field')), 'Daten');
      await tester.tap(find.byKey(const Key('help_ask')));
      await pumpUntil(tester, find.byKey(const Key('help_answer')));

      final answer = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('help_answer')),
          matching: find.byType(Text),
        ),
      );
      expect(answer.data, contains('Auf deinem Gerät'));
    });

    testWidgets('der Datenhinweis steht sichtbar im Info-Bereich', (
      tester,
    ) async {
      await pump(tester, const HelpPage());
      await tester.pumpAndSettle();

      // Der Hinweis steht weiter unten und wird erst beim Scrollen gebaut.
      // scrollable muss angegeben werden: Die aufklappbaren FAQ-Einträge
      // bringen je einen eigenen Scrollbereich mit.
      await tester.scrollUntilVisible(
        find.byKey(const Key('about_data_notice')),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.byKey(const Key('about_data_notice')), findsOneWidget);
    });
  });
}
