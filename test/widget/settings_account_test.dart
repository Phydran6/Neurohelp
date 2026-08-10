import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/data/unconfigured_account_repository.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/security/data/device_app_lock.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Zählt mit, ob das Konto wirklich gelöscht wurde.
class _DeletingAccount extends LocalAccountRepository {
  _DeletingAccount();

  int deleteCalls = 0;

  @override
  Future<bool> deleteAccount() async {
    deleteCalls++;
    await super.deleteAccount();
    // Das Backend hat zusätzlich eine Bestätigung verschickt.
    return true;
  }
}

/// KI, die erreichbar ist und mitzählt, ob nachgefragt wurde.
class _ReachableAi implements AiClient {
  bool enabled = false;
  int probes = 0;

  @override
  bool get isEnabled => enabled;

  @override
  void setEnabled({required bool enabled}) => this.enabled = enabled;

  @override
  Future<void> probe() async => probes++;

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async => 'egal';
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late _DeletingAccount account;
  late _ReachableAi ai;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    account = _DeletingAccount();
    ai = _ReachableAi();
    services = AppServices.from(
      database,
      account: account,
      ai: ai,
      lock: InMemoryAppLock(biometricAvailable: true),
    );
    await services.settings.setLockMethod(LockMethod.biometric);
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
    // Hoher Ausschnitt: Die Einstellungen sind eine lange Liste, und was
    // außerhalb liegt, baut Flutter gar nicht erst. Sonst ist ein Test rot,
    // obwohl die Seite stimmt.
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('settings_ai')));
  }

  testWidgets('der KI-Schalter gibt eine echte Rückmeldung', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_ai')));
    await pumpUntil(tester, find.byKey(const Key('settings_ai_status')));

    // Vorher passierte beim Umlegen sichtbar gar nichts.
    expect(ai.probes, 1);
    expect(find.textContaining('antwortet'), findsOneWidget);
  });

  testWidgets('der Schalter wirkt sofort auf den KI-Zugang', (tester) async {
    await pumpSettings(tester);
    expect(ai.isEnabled, isFalse);

    await tester.tap(find.byKey(const Key('settings_ai')));
    await pumpUntil(tester, find.byKey(const Key('settings_ai_status')));

    // Früher zog der Client seinen Schalter nur beim App-Start.
    expect(ai.isEnabled, isTrue);
  });

  testWidgets('Biometrie lässt sich abschalten, die Sperre bleibt', (
    tester,
  ) async {
    await pumpSettings(tester);

    final before = tester.widget<SwitchListTile>(
      find.byKey(const Key('settings_biometric')),
    );
    expect(before.value, isTrue);

    await tester.tap(find.byKey(const Key('settings_biometric')));
    await pumpUntil(tester, find.byKey(const Key('settings_message')));

    final settings = await services.settings.load();
    expect(settings.usesBiometrics, isFalse);
    expect(settings.isLocked, isTrue);
  });

  testWidgets('das Konto lässt sich löschen – aber erst nach Rückfrage', (
    tester,
  ) async {
    await account.signUp(
      username: 'philipp',
      email: 'philipp@example.test',
      password: 'geheim1234',
    );
    await pumpSettings(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_delete_account')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings_delete_account')));
    await pumpUntil(tester, find.byKey(const Key('settings_delete_cancel')));

    // Abbrechen löscht nichts.
    await tester.tap(find.byKey(const Key('settings_delete_cancel')));
    await tester.pumpAndSettle();
    expect(account.deleteCalls, 0);

    await tester.tap(find.byKey(const Key('settings_delete_account')));
    await pumpUntil(tester, find.byKey(const Key('settings_delete_confirm')));
    await tester.tap(find.byKey(const Key('settings_delete_confirm')));
    await pumpUntil(tester, find.byKey(const Key('settings_message')));

    expect(account.deleteCalls, 1);
    expect(await account.currentAccount(), isNull);
    expect(find.textContaining('Postfach'), findsOneWidget);
  });

  testWidgets('ohne Backend steht das ehrlich da, statt zu fehlen', (
    tester,
  ) async {
    services = AppServices.from(database, lock: InMemoryAppLock());
    await pumpSettings(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_account_unconfigured')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('settings_account_unconfigured')),
      findsOneWidget,
    );
  });

  testWidgets('die Zwei-Faktor-Anmeldung ist von hier erreichbar', (
    tester,
  ) async {
    await account.signUp(
      username: 'philipp',
      email: 'philipp@example.test',
      password: 'geheim1234',
    );
    await pumpSettings(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_mfa')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('settings_mfa')));
    await pumpUntil(tester, find.byKey(const Key('mfa_secret')));

    await tester.enterText(
      find.byKey(const Key('mfa_code')),
      LocalAccountRepository.testCode,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('mfa_confirm')));
    await pumpUntil(tester, find.byKey(const Key('settings_message')));

    expect(await account.hasMfa(), isTrue);
  });
}
