import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/data/unconfigured_account_repository.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/config/app_config.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/security/data/device_app_lock.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:neurohelp/features/onboarding/presentation/onboarding_page.dart';
import 'package:neurohelp/features/security/presentation/lock_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late InMemoryAppLock lock;

  setUp(() async {
    AppConfig.overrideForTesting(
      const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
    );
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    lock = InMemoryAppLock();
    services = AppServices.from(
      database,
      account: LocalAccountRepository(),
      lock: lock,
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

  Future<void> pumpOnboarding(WidgetTester tester, {VoidCallback? onDone}) {
    return tester.pumpWidget(
      AppScope(
        services: services,
        child: MaterialApp(home: OnboardingPage(onDone: onDone ?? () {})),
      ),
    );
  }

  /// Die beiden Erklärbildschirme durchtippen.
  ///
  /// Sie stehen vor jedem Konto-Formular; ohne diesen Schritt läuft kein
  /// Test des eigentlichen Onboardings mehr los.
  Future<void> passIntro(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('onb_intro_next')));
    await pumpUntil(tester, find.byKey(const Key('onb_intro_start')));
    await tester.tap(find.byKey(const Key('onb_intro_start')));
    await pumpUntil(tester, find.byKey(const Key('onb_username')));
  }

  Future<void> createAccount(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
    await tester.enterText(
      find.byKey(const Key('onb_email')),
      'philipp@example.test',
    );
    await tester.enterText(find.byKey(const Key('onb_password')), 'geheim1234');
    await tester.tap(find.byKey(const Key('onb_create')));
    await pumpUntil(tester, find.byKey(const Key('onb_ai_yes')));
  }

  group('Onboarding', () {
    testWidgets('erklärt sich selbst, bevor es etwas verlangt', (tester) async {
      await pumpOnboarding(tester);
      await tester.pumpAndSettle();

      // Erster Bildschirm: was die App kann – und noch kein Eingabefeld.
      expect(find.byKey(const Key('onb_intro_was')), findsOneWidget);
      expect(find.text('Das nimmt dir Neurohelp ab'), findsOneWidget);
      expect(find.byKey(const Key('intro_point_anruf')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      // Zweiter Bildschirm: wie es funktioniert.
      await tester.tap(find.byKey(const Key('onb_intro_next')));
      await pumpUntil(tester, find.byKey(const Key('onb_intro_wie')));

      expect(find.text('So läuft das hier'), findsOneWidget);
      expect(find.byKey(const Key('intro_point_lokal')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('lässt zum ersten Erklärbildschirm zurück', (tester) async {
      await pumpOnboarding(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onb_intro_next')));
      await pumpUntil(tester, find.byKey(const Key('onb_intro_back')));

      await tester.tap(find.byKey(const Key('onb_intro_back')));
      await pumpUntil(tester, find.byKey(const Key('onb_intro_was')));

      expect(find.text('Das nimmt dir Neurohelp ab'), findsOneWidget);
    });

    testWidgets('nach zwei Bildschirmen kommt das Konto', (tester) async {
      await pumpOnboarding(tester);
      await tester.pumpAndSettle();
      await passIntro(tester);

      expect(find.text('Erst ein Konto'), findsOneWidget);
      expect(find.byKey(const Key('onb_username')), findsOneWidget);
    });

    testWidgets('sagt ruhig Bescheid, wenn kein Backend da ist', (
      tester,
    ) async {
      services = AppServices.from(database, lock: lock);
      await pumpOnboarding(tester);
      await tester.pumpAndSettle();
      await passIntro(tester);

      await tester.enterText(find.byKey(const Key('onb_username')), 'philipp');
      await tester.enterText(
        find.byKey(const Key('onb_email')),
        'philipp@example.test',
      );
      await tester.enterText(
        find.byKey(const Key('onb_password')),
        'geheim1234',
      );
      await tester.tap(find.byKey(const Key('onb_create')));
      await pumpUntil(tester, find.byKey(const Key('onb_error')));

      // Kein Konto vortäuschen: Die App sagt, dass es noch nicht geht.
      expect(find.textContaining('noch nicht eingerichtet'), findsOneWidget);
    });

    testWidgets('der KI-Toggle ist eine echte Entscheidung', (tester) async {
      await pumpOnboarding(tester);
      await tester.pumpAndSettle();
      await passIntro(tester);
      await createAccount(tester);

      // Zwei gleichwertige Knöpfe, keine Voreinstellung.
      expect(find.byKey(const Key('onb_ai_yes')), findsOneWidget);
      expect(find.byKey(const Key('onb_ai_no')), findsOneWidget);
      expect(find.textContaining('Ohne KI läuft alles'), findsOneWidget);
    });

    testWidgets('läuft bis zum Ende durch und speichert die Wahl', (
      tester,
    ) async {
      var done = false;
      await pumpOnboarding(tester, onDone: () => done = true);
      await tester.pumpAndSettle();

      await passIntro(tester);
      await createAccount(tester);

      await tester.tap(find.byKey(const Key('onb_ai_no')));
      await pumpUntil(tester, find.byKey(const Key('onb_pin')));

      await tester.enterText(find.byKey(const Key('onb_pin')), '4711');
      await tester.pump();
      await tester.tap(find.byKey(const Key('onb_pin_save')));
      await pumpUntil(tester, find.byKey(const Key('onb_extra_skip')));

      // „Später" sagt einmal Bescheid, dass die Zwei-Faktor-Anmeldung
      // offen bleibt – und danach nie wieder.
      await tester.tap(find.byKey(const Key('onb_extra_skip')));
      await pumpUntil(tester, find.byKey(const Key('onb_mfa_hint_ok')));
      await tester.tap(find.byKey(const Key('onb_mfa_hint_ok')));
      await pumpUntil(tester, find.byKey(const Key('onb_tone_sachlich')));

      await tester.tap(find.byKey(const Key('onb_tone_sachlich')));
      await tester.pumpAndSettle();

      expect(done, isTrue);

      final settings = await services.settings.load();
      expect(settings.onboardingCompleted, isTrue);
      expect(settings.aiEnabled, isFalse);
      expect(settings.tone, AiTone.sachlich);
      expect(settings.lockMethod, LockMethod.pin);
      expect(await lock.hasPin, isTrue);
    });
  });

  group('App-Sperre', () {
    testWidgets('entsperrt mit der richtigen PIN', (tester) async {
      await lock.setPin('4711');
      var unlocked = false;

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(
            home: LockScreen(onUnlocked: () => unlocked = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('lock_pin')), '4711');
      await tester.pump();
      await tester.tap(find.byKey(const Key('lock_submit')));
      await tester.pumpAndSettle();

      expect(unlocked, isTrue);
    });

    testWidgets('sagt bei falscher PIN Bescheid, ohne Vorwurf', (tester) async {
      await lock.setPin('4711');

      await tester.pumpWidget(
        AppScope(
          services: services,
          child: MaterialApp(home: LockScreen(onUnlocked: () {})),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('lock_pin')), '0000');
      await tester.pump();
      await tester.tap(find.byKey(const Key('lock_submit')));
      await pumpUntil(tester, find.byKey(const Key('lock_error')));

      final error = tester.widget<Text>(find.byKey(const Key('lock_error')));
      expect(error.data, 'Das war nicht die richtige PIN.');
    });
  });
}
