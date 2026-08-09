// Erzeugt die Bildschirmfotos für App Store und Play Store.
//
// Läuft nicht bei `flutter test`, sondern auf einem echten Simulator:
//
//   flutter drive --driver=test_driver/screenshot_driver.dart \
//     --target=integration_test/screenshots_test.dart -d <Gerät>
//
// Die Bildgröße ist die des Simulators. Für den App Store braucht es
// 1320×2868 – das liefert das iPhone 16 Pro Max. Die Prüfung darauf steht in
// .github/workflows/store-screenshots.yml, nicht hier: Ein Test soll nicht an
// der Gerätewahl scheitern.
//
// Die App läuft dabei mit einer leeren Datenbank im Speicher und
// abgeschlossenem Onboarding. Es entstehen keine echten Konten und es geht
// nichts zum Server – die Bilder zeigen erfundene, unverfängliche Beispiele.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neurohelp/app/app.dart';
import 'package:neurohelp/core/config/app_config.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late AppServices services;

  setUp(() async {
    AppConfig.overrideForTesting(
      const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
    );
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    services = AppServices.from(database);

    // Ohne das landet die App im Onboarding statt auf der Startseite.
    await services.settings.setOnboardingCompleted(completed: true);
  });

  tearDown(() => database.close());

  /// Wartet, bis [finder] da ist. `pumpAndSettle` allein genügt nicht: Die
  /// Startseite lädt ihre Historie aus der Datenbank, und darauf wartet
  /// `pumpAndSettle` nicht (siehe CLAUDE.md).
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 80; attempt++) {
      if (finder.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.pump(const Duration(milliseconds: 32));
    }
    fail('Nicht gefunden: $finder');
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    // Vor dem Foto muss die Oberfläche stillstehen, sonst kommt ein halb
    // gezeichnetes Bild heraus.
    await tester.pumpAndSettle();
    await binding.takeScreenshot(name);
  }

  Future<void> startApp(WidgetTester tester) async {
    // Nur Android braucht das: Dort rendert Flutter in eine SurfaceView, die
    // sich nicht auslesen laesst, und muss erst umgestellt werden. Auf iOS
    // kennt das Plugin den Aufruf nicht und wuerde mit
    // MissingPluginException abbrechen.
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }

    await tester.pumpWidget(
      AppScope(services: services, child: const NeurohelpApp()),
    );
    await waitFor(tester, find.byKey(const Key('start_logo')));
  }

  testWidgets('1 – Startseite', (tester) async {
    await startApp(tester);
    await shoot(tester, '01_start');
  });

  testWidgets('2 – Hauptmenü', (tester) async {
    await startApp(tester);

    await tester.tap(find.byKey(const Key('start_button')));
    await waitFor(tester, find.byKey(const Key('menu_title')));

    await shoot(tester, '02_menue');
  });

  testWidgets('3 – Aufgabe in Schritte zerlegen', (tester) async {
    await startApp(tester);

    await tester.tap(find.byKey(const Key('start_button')));
    await waitFor(tester, find.byKey(const Key('menu_title')));

    await tester.tap(find.byKey(const Key('menu_task')));
    await waitFor(tester, find.byKey(const Key('task_new')));

    await tester.tap(find.byKey(const Key('task_new')));
    await waitFor(tester, find.byKey(const Key('task_title_field')));

    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Wäsche wegräumen',
    );
    await tester.pumpAndSettle();

    for (final step in const [
      'Korb ins Zimmer holen',
      'Socken zusammenlegen',
      'Schrank aufmachen',
    ]) {
      await tester.enterText(find.byKey(const Key('task_step_field')), step);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task_step_add')));
      await tester.pumpAndSettle();
    }

    await shoot(tester, '03_aufgabe');
  });

  testWidgets('4 – Fokus: nur der nächste Schritt', (tester) async {
    await startApp(tester);

    await tester.tap(find.byKey(const Key('start_button')));
    await waitFor(tester, find.byKey(const Key('menu_title')));

    await tester.tap(find.byKey(const Key('menu_task')));
    await waitFor(tester, find.byKey(const Key('task_new')));

    await tester.tap(find.byKey(const Key('task_new')));
    await waitFor(tester, find.byKey(const Key('task_title_field')));

    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Wäsche wegräumen',
    );
    await tester.pumpAndSettle();

    for (final step in const [
      'Korb ins Zimmer holen',
      'Socken zusammenlegen',
      'Schrank aufmachen',
    ]) {
      await tester.enterText(find.byKey(const Key('task_step_field')), step);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task_step_add')));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('task_start')));
    await waitFor(tester, find.byKey(const Key('focus_step')));

    await shoot(tester, '04_fokus');
  });

  testWidgets('5 – Anruf vorbereiten', (tester) async {
    await startApp(tester);

    await tester.tap(find.byKey(const Key('start_button')));
    await waitFor(tester, find.byKey(const Key('menu_title')));

    await tester.tap(find.byKey(const Key('menu_call')));
    await waitFor(tester, find.byKey(const Key('call_title')));

    await shoot(tester, '05_anruf');
  });

  testWidgets('6 – Einstellungen: KI ist freiwillig', (tester) async {
    await startApp(tester);

    await tester.tap(find.byKey(const Key('start_settings')));
    await waitFor(tester, find.byKey(const Key('settings_ai')));

    await shoot(tester, '06_einstellungen');
  });
}
