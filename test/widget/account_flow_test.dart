import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/data/unconfigured_account_repository.dart';
import 'package:neurohelp/core/config/app_config.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/security/data/device_app_lock.dart';
import 'package:neurohelp/features/onboarding/presentation/onboarding_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Die Wege für „ich war schon mal hier".
///
/// Anlass: Beim ersten Start bot die App ausschließlich an, ein neues Konto
/// anzulegen. Wer die App neu installiert hatte oder sein Passwort nicht mehr
/// wusste, saß fest – es gab keinen Knopf dafür.
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
    account = LocalAccountRepository(needsConfirmation: true);
    services = AppServices.from(
      database,
      account: account,
      lock: InMemoryAppLock(),
    );
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

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(home: OnboardingPage(onDone: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('beide Wege stehen gleich auf dem ersten Bildschirm', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    expect(find.byKey(const Key('onb_create')), findsOneWidget);
    expect(find.byKey(const Key('onb_have_account')), findsOneWidget);
    expect(find.byKey(const Key('onb_forgot')), findsOneWidget);
  });

  testWidgets('nach der Registrierung kommt der Code aus der Mail', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_create')));
    await pumpUntil(tester, find.byKey(const Key('onb_code')));

    // Ein Code, kein Link: Der Link landete im Browser und endete dort mit
    // „otp_expired".
    expect(find.byKey(const Key('onb_resend')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('onb_code')),
      LocalAccountRepository.testCode,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_confirm')));
    await pumpUntil(tester, find.byKey(const Key('onb_ai_yes')));
  });

  testWidgets('ohne Code in der Mail geht es über den Link weiter', (
    tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_create')));
    await pumpUntil(tester, find.byKey(const Key('onb_code')));

    // Supabase gibt die Mail-Vorlagen erst mit eigenem SMTP frei; bis dahin
    // steht in der Standard-Mail nur ein Link. Ohne diesen Ausweg säße der
    // User vor einem Code-Feld, das er nicht füllen kann.
    await tester.tap(find.byKey(const Key('onb_confirmed_by_link')));
    await pumpUntil(tester, find.byKey(const Key('onb_ai_yes')));
  });

  testWidgets('ein falscher Code sagt Bescheid, ohne Vorwurf', (tester) async {
    await pumpOnboarding(tester);

    await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_create')));
    await pumpUntil(tester, find.byKey(const Key('onb_code')));

    await tester.enterText(find.byKey(const Key('onb_code')), '000000');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_confirm')));
    await pumpUntil(tester, find.byKey(const Key('onb_error')));

    expect(find.textContaining('nicht gepasst'), findsOneWidget);
  });

  testWidgets('mit vorhandenem Konto geht es über Anmelden weiter', (
    tester,
  ) async {
    await account.signUp(
      username: 'philipp',
      email: 'philipp@example.test',
      password: 'geheim1234',
    );

    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onb_have_account')));
    await pumpUntil(tester, find.byKey(const Key('onb_sign_in')));

    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_sign_in')));
    await pumpUntil(tester, find.byKey(const Key('onb_ai_yes')));
  });

  testWidgets('Passwort vergessen führt über Code zu einem neuen Passwort', (
    tester,
  ) async {
    await pumpOnboarding(tester);
    await tester.tap(find.byKey(const Key('onb_forgot')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_send_reset')));
    await pumpUntil(tester, find.byKey(const Key('onb_new_password')));

    await tester.enterText(
      find.byKey(const Key('onb_code')),
      LocalAccountRepository.testCode,
    );
    await tester.enterText(
      find.byKey(const Key('onb_new_password')),
      'nochgeheimer1',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_reset')));
    await pumpUntil(tester, find.byKey(const Key('onb_ai_yes')));
  });

  testWidgets('eine Störung liefert Details zum Melden mit', (tester) async {
    services = AppServices.from(database, lock: InMemoryAppLock());
    await pumpOnboarding(tester);

    await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_create')));
    await pumpUntil(tester, find.byKey(const Key('onb_error')));

    // Ruhige Meldung oben, Technisches hinter „Details" – vorher endete
    // jede Störung in einem freundlichen Satz ohne jeden Anhaltspunkt.
    expect(find.byKey(const Key('error_details')), findsOneWidget);
    await tester.tap(find.byKey(const Key('error_details')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error_details_text')), findsOneWidget);
  });

  testWidgets('der Zwei-Faktor-Hinweis kommt genau einmal', (tester) async {
    // Erst den Hinweis auslösen …
    await services.settings.load();
    expect(services.settings.current.mfaHintShown, isFalse);

    await services.settings.setMfaHintShown(shown: true);

    await pumpOnboarding(tester);
    await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_create')));
    await pumpUntil(tester, find.byKey(const Key('onb_code')));
    await tester.enterText(
      find.byKey(const Key('onb_code')),
      LocalAccountRepository.testCode,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_confirm')));
    await pumpUntil(tester, find.byKey(const Key('onb_ai_no')));

    await tester.tap(find.byKey(const Key('onb_ai_no')));
    await pumpUntil(tester, find.byKey(const Key('onb_pin')));
    await tester.enterText(find.byKey(const Key('onb_pin')), '4711');
    await tester.pump();
    await tester.tap(find.byKey(const Key('onb_pin_save')));
    await pumpUntil(tester, find.byKey(const Key('onb_extra_skip')));

    await tester.tap(find.byKey(const Key('onb_extra_skip')));
    await pumpUntil(tester, find.byKey(const Key('onb_tone_locker')));

    // … beim zweiten Mal bleibt er weg. Ein Hinweis, der immer wieder kommt,
    // ist Druck.
    expect(find.byKey(const Key('onb_mfa_hint')), findsNothing);
  });
}
