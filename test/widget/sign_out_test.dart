import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/app/app.dart';
import 'package:neurohelp/core/account/data/unconfigured_account_repository.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/config/app_config.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/security/data/device_app_lock.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// **Anlass:** Nach „Abmelden" in den Einstellungen verschwand nur der
/// Knopf. Die App lief weiter wie vorher, und es sah aus, als wäre man noch
/// angemeldet – einen Weg zurück zur Anmeldung gab es nicht.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late LocalAccountRepository account;

  setUp(() async {
    AppConfig.overrideForTesting(
      const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
    );
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    account = LocalAccountRepository();
    services = AppServices.from(
      database,
      account: account,
      lock: InMemoryAppLock(),
    );

    await account.signUp(
      username: 'philipp',
      email: 'philipp@example.test',
      password: 'geheim123',
    );
    await services.settings.setOnboardingCompleted(completed: true);
    await services.settings.setSettingsMode(SettingsMode.expert);
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
    // Hoher Ausschnitt: Die Einstellungen sind eine lange Liste.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(services: services, child: const NeurohelpApp()),
    );
    await pumpUntil(tester, find.byKey(const Key('start_logo')));
  }

  Future<void> signOut(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('start_settings')));
    await pumpUntil(tester, find.byKey(const Key('settings_sign_out')));
    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await pumpUntil(tester, find.byKey(const Key('entry_sign_in')));
  }

  testWidgets('Abmelden führt zur Anmeldung statt in die App', (tester) async {
    await pumpApp(tester);
    await signOut(tester);

    expect(await account.currentAccount(), isNull);
    expect(find.byKey(const Key('start_logo')), findsNothing);
    expect(find.byKey(const Key('settings_sign_out')), findsNothing);
    // Gleich beim Anmelden, nicht beim Anlegen eines neuen Kontos.
    expect(find.byKey(const Key('onb_sign_in')), findsOneWidget);
  });

  testWidgets('wieder angemeldet geht es ohne neues Onboarding weiter', (
    tester,
  ) async {
    await services.settings.setTone(AiTone.sachlich);
    await pumpApp(tester);
    await signOut(tester);

    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim123');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_sign_in')));
    await pumpUntil(tester, find.byKey(const Key('start_logo')));

    expect(await account.currentAccount(), isNotNull);
    // Die Einstellungen aus dem Onboarding sind nicht überschrieben.
    expect(services.settings.current.tone, AiTone.sachlich);
    expect(services.settings.current.onboardingCompleted, isTrue);
  });
}
