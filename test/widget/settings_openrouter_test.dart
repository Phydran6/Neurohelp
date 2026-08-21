import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_account.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_api.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_key.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_key_store.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_login.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ein Browser, der wahlweise zurückkommt oder abbricht.
class _FakeLogin implements OpenRouterLogin {
  _FakeLogin(this.callback);

  Uri? callback;
  int opened = 0;

  @override
  Future<Uri?> authorize(Uri url, {required String callbackScheme}) async {
    opened++;
    return callback;
  }
}

/// KI, die immer erreichbar ist – der Schalter soll hier nicht im Weg stehen.
class _ReachableAi implements AiClient {
  bool enabled = false;

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
  }) async => 'egal';
}

MockClient _openRouter({String key = 'sk-or-v1-frisch'}) {
  return MockClient((request) async {
    final body = request.url.path.endsWith('/auth/keys')
        ? {'key': key}
        : {'data': <String, Object?>{}};
    return http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    );
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late _FakeLogin login;
  late InMemoryOpenRouterKeyStore store;

  Future<void> start({OpenRouterKey? stored}) async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    login = _FakeLogin(Uri.parse('neurohelp://openrouter?code=DER-CODE'));
    store = InMemoryOpenRouterKeyStore(stored);

    final account = OpenRouterAccount(
      store: store,
      api: OpenRouterApi(client: _openRouter()),
      login: login,
    );
    await account.load();

    services = AppServices.from(
      database,
      ai: _ReachableAi(),
      openRouter: account,
    );
    // Das Angebot erscheint nur, wenn KI überhaupt an ist.
    await services.settings.setAiEnabled(enabled: true);
  }

  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

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

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible hört auf, sobald etwas vom Widget zu sehen ist –
    // sein Mittelpunkt kann dabei noch unter dem Rand liegen, und ein Tap
    // geht dann ins Leere.
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('das Angebot steht in den Einstellungen, nicht im Onboarding', (
    tester,
  ) async {
    await start();
    await pump(tester);
    await reveal(tester, find.byKey(const Key('settings_openrouter')));

    expect(
      find.byKey(const Key('settings_openrouter_connect')),
      findsOneWidget,
    );
    // Der ehrliche Hinweis gehört sichtbar dazu, nicht ins Kleingedruckte:
    // In Neurohelp geht es oft um Arzt- und Kassenthemen.
    expect(
      find.byKey(const Key('settings_openrouter_privacy')),
      findsOneWidget,
    );
  });

  testWidgets('ohne KI-Schalter gibt es das Angebot gar nicht', (tester) async {
    await start();
    await services.settings.setAiEnabled(enabled: false);
    await pump(tester);

    expect(find.byKey(const Key('settings_openrouter')), findsNothing);
  });

  testWidgets('ein Tap verbindet – und der Schlüssel bleibt unsichtbar', (
    tester,
  ) async {
    await start();
    await pump(tester);
    await reveal(tester, find.byKey(const Key('settings_openrouter_connect')));

    await tester.tap(find.byKey(const Key('settings_openrouter_connect')));
    await pumpUntil(
      tester,
      find.byKey(const Key('settings_openrouter_status')),
    );

    expect(login.opened, 1);
    expect(services.openRouter.isConnected, isTrue);
    expect((await store.read())!.value, 'sk-or-v1-frisch');

    // Nirgends auf dem Bildschirm steht der Schlüssel.
    expect(find.textContaining('sk-or-v1'), findsNothing);
  });

  testWidgets('ein Abbruch hinterlässt keine Meldung', (tester) async {
    await start();
    login.callback = null;
    await pump(tester);
    await reveal(tester, find.byKey(const Key('settings_openrouter_connect')));

    await tester.tap(find.byKey(const Key('settings_openrouter_connect')));
    await tester.pumpAndSettle();

    expect(services.openRouter.isConnected, isFalse);
    expect(find.byKey(const Key('settings_ai_status')), findsNothing);
  });

  testWidgets('ein verbundener Zugang lässt sich wieder trennen', (
    tester,
  ) async {
    await start(
      stored: const OpenRouterKey(
        value: 'sk-or-v1-alt',
        origin: OpenRouterKeyOrigin.login,
      ),
    );
    await pump(tester);
    await reveal(
      tester,
      find.byKey(const Key('settings_openrouter_disconnect')),
    );

    await tester.tap(find.byKey(const Key('settings_openrouter_disconnect')));
    await tester.pumpAndSettle();

    expect(services.openRouter.isConnected, isFalse);
    expect(await store.read(), isNull);
    expect(
      find.byKey(const Key('settings_openrouter_connect')),
      findsOneWidget,
    );
  });

  testWidgets('ein abgelehnter Zugang bietet einen neuen Login an', (
    tester,
  ) async {
    await start(
      stored: const OpenRouterKey(
        value: 'sk-or-v1-alt',
        origin: OpenRouterKeyOrigin.login,
      ),
    );
    services.openRouter.markRejected();
    await pump(tester);
    await reveal(
      tester,
      find.byKey(const Key('settings_openrouter_reconnect')),
    );

    // Kein Drama, kein technischer Text – ein Knopf und ein ruhiger Satz.
    expect(
      find.byKey(const Key('settings_openrouter_reconnect')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('settings_openrouter_reconnect')));
    await tester.pumpAndSettle();

    expect(services.openRouter.needsReconnect, isFalse);
    expect(services.openRouter.key!.value, 'sk-or-v1-frisch');
  });

  testWidgets('der eigene Schlüssel liegt versteckt darunter', (tester) async {
    await start();
    await pump(tester);
    await reveal(tester, find.byKey(const Key('settings_openrouter_byok')));

    // Zu ist zu: Im Standardweg taucht kein Schlüsselfeld auf.
    expect(
      find.byKey(const Key('settings_openrouter_byok_open')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('settings_openrouter_byok')));
    await tester.pumpAndSettle();

    await reveal(
      tester,
      find.byKey(const Key('settings_openrouter_byok_open')),
    );
    await tester.tap(find.byKey(const Key('settings_openrouter_byok_open')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('settings_openrouter_byok_field')),
      'sk-or-v1-eigen',
    );
    await tester.tap(find.byKey(const Key('settings_openrouter_byok_save')));
    await pumpUntil(
      tester,
      find.byKey(const Key('settings_openrouter_status')),
    );

    expect((await store.read())!.value, 'sk-or-v1-eigen');
    expect(services.openRouter.key!.origin, OpenRouterKeyOrigin.manual);
  });

  testWidgets('Konto löschen nimmt auch den eigenen KI-Zugang mit', (
    tester,
  ) async {
    await start(
      stored: const OpenRouterKey(
        value: 'sk-or-v1-alt',
        origin: OpenRouterKeyOrigin.login,
      ),
    );

    await services.wipeLocalData();

    expect(services.openRouter.isConnected, isFalse);
    expect(await store.read(), isNull);
  });
}
