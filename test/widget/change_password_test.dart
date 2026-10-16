import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/account/account_repository.dart';
import 'package:neurohelp/core/account/data/unconfigured_account_repository.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Zählt mit, ob das Passwort wirklich geändert wurde.
class _PasswordAccount extends LocalAccountRepository {
  String? changedTo;

  @override
  Future<Account> changePassword(String newPassword) async {
    final account = await super.changePassword(newPassword);
    changedTo = newPassword;
    return account;
  }
}

/// Prüft „Passwort ändern" in den Einstellungen.
///
/// **Anlass:** Das Passwort ließ sich nur über „Passwort vergessen" im
/// Einstieg ändern – Mail anfordern, Code abtippen, neues Passwort setzen.
/// Wer angemeldet war, kam an diesen Bildschirm gar nicht mehr heran und
/// hätte sich abmelden müssen, um sein Passwort zu ändern. Das war keine
/// Hürde, sondern eine Sackgasse.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Siehe CLAUDE.md: In Widget-Tests kommt ein Future über eine
    // Isolate-Grenze nie an.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late _PasswordAccount account;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    account = _PasswordAccount();
    services = AppServices.from(database, account: account);

    // Angemeldet sein ist die Voraussetzung – genau darum geht es.
    await account.signUp(
      username: 'tester',
      email: 'tester@example.com',
      password: 'altesPasswort',
    );
    await account.confirmSignUp(
      email: 'tester@example.com',
      code: LocalAccountRepository.testCode,
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

  Future<void> pumpSettings(WidgetTester tester, SettingsMode mode) async {
    await services.settings.setSettingsMode(mode);

    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('settings_change_password')));
  }

  Future<void> enterPassword(
    WidgetTester tester,
    String password, {
    String? repeat,
  }) async {
    await tester.enterText(
      find.byKey(const Key('settings_password_field')),
      password,
    );
    await tester.enterText(
      find.byKey(const Key('settings_password_repeat')),
      repeat ?? password,
    );
    await tester.tap(find.byKey(const Key('settings_password_save')));
    await tester.pumpAndSettle();
  }

  testWidgets('steht im Expertenweg zur Verfügung', (tester) async {
    await pumpSettings(tester, SettingsMode.expert);

    await tester.tap(find.byKey(const Key('settings_change_password')));
    await pumpUntil(tester, find.byKey(const Key('settings_password_field')));

    await enterPassword(tester, 'neuesPasswort');

    expect(account.changedTo, 'neuesPasswort');
    expect(find.text('Passwort geändert.'), findsOneWidget);
  });

  testWidgets('und genauso im geführten Weg', (tester) async {
    await pumpSettings(tester, SettingsMode.guided);

    await tester.tap(find.byKey(const Key('settings_change_password')));
    await pumpUntil(tester, find.byKey(const Key('settings_password_field')));

    await enterPassword(tester, 'nochEinPasswort');

    expect(account.changedTo, 'nochEinPasswort');
  });

  testWidgets('ein Vertipper fällt sofort auf, nicht erst beim Anmelden', (
    tester,
  ) async {
    await pumpSettings(tester, SettingsMode.expert);

    await tester.tap(find.byKey(const Key('settings_change_password')));
    await pumpUntil(tester, find.byKey(const Key('settings_password_field')));

    await enterPassword(tester, 'langGenugAber', repeat: 'vertippt');

    expect(find.byKey(const Key('settings_password_problem')), findsOneWidget);
    expect(find.textContaining('stimmen nicht überein'), findsOneWidget);
    expect(account.changedTo, isNull);
  });

  testWidgets('ein zu kurzes Passwort wird gar nicht erst geschickt', (
    tester,
  ) async {
    await pumpSettings(tester, SettingsMode.expert);

    await tester.tap(find.byKey(const Key('settings_change_password')));
    await pumpUntil(tester, find.byKey(const Key('settings_password_field')));

    await enterPassword(tester, 'kurz');

    expect(find.textContaining('8 Zeichen'), findsWidgets);
    expect(account.changedTo, isNull);
  });
}
