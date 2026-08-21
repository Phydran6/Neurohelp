import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_account.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_api.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_exception.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_key.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_key_store.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_login.dart';

/// Ein Browser, der immer dasselbe zurückgibt.
class _FakeLogin implements OpenRouterLogin {
  _FakeLogin(this.callback);

  final Uri? callback;
  Uri? openedUrl;
  String? openedScheme;

  @override
  Future<Uri?> authorize(Uri url, {required String callbackScheme}) async {
    openedUrl = url;
    openedScheme = callbackScheme;
    return callback;
  }
}

MockClient _api({
  Object? keys,
  Object? key,
  int keysStatus = 200,
  int keyStatus = 200,
}) {
  return MockClient((request) async {
    final isExchange = request.url.path.endsWith('/auth/keys');
    return http.Response(
      jsonEncode(isExchange ? keys : key),
      isExchange ? keysStatus : keyStatus,
      headers: {'content-type': 'application/json'},
    );
  });
}

void main() {
  group('Verbinden', () {
    test('ein Tap genügt: Login, Code, Schlüssel, sicher abgelegt', () async {
      final login = _FakeLogin(
        Uri.parse('neurohelp://openrouter?code=DER-CODE'),
      );
      final store = InMemoryOpenRouterKeyStore();
      final account = OpenRouterAccount(
        store: store,
        login: login,
        api: OpenRouterApi(
          client: _api(
            keys: {'key': 'sk-or-v1-neu'},
            key: {'data': <String, Object?>{}},
          ),
        ),
      );

      final result = await account.connect();

      expect(result, OpenRouterConnectResult.connected);
      expect(account.isConnected, isTrue);
      expect(account.isUsable, isTrue);
      expect(account.key!.origin, OpenRouterKeyOrigin.login);

      // Der Schlüssel liegt auf dem Gerät, nicht irgendwo sonst.
      expect((await store.read())!.value, 'sk-or-v1-neu');

      // Der Login lief über das eigene Schema.
      expect(login.openedScheme, OpenRouterApi.callbackScheme);
      expect(login.openedUrl!.host, 'openrouter.ai');
    });

    test('ein Abbruch ist kein Fehler', () async {
      final account = OpenRouterAccount(
        store: InMemoryOpenRouterKeyStore(),
        login: _FakeLogin(null),
        api: OpenRouterApi(client: _api()),
      );

      expect(await account.connect(), OpenRouterConnectResult.cancelled);
      expect(account.isConnected, isFalse);
    });

    test('ein abgelehnter Rücksprung ebenfalls nicht', () async {
      final account = OpenRouterAccount(
        store: InMemoryOpenRouterKeyStore(),
        login: _FakeLogin(
          Uri.parse('neurohelp://openrouter?error=access_denied'),
        ),
        api: OpenRouterApi(client: _api()),
      );

      expect(await account.connect(), OpenRouterConnectResult.cancelled);
    });

    test('der Schlüssel verrät sich nicht in der Anzeige', () async {
      const key = OpenRouterKey(
        value: 'sk-or-v1-geheimnisvoll1234',
        origin: OpenRouterKeyOrigin.manual,
      );

      expect(key.hint, '••••1234');
      expect(key.hint, isNot(contains('geheimnisvoll')));
    });
  });

  group('Eigener Schlüssel (die versteckte Option)', () {
    test('wird vor dem Speichern einmal ausprobiert', () async {
      final store = InMemoryOpenRouterKeyStore();
      final account = OpenRouterAccount(
        store: store,
        api: OpenRouterApi(
          client: _api(key: {'error': 'nope'}, keyStatus: 401),
        ),
        login: _FakeLogin(null),
      );

      await expectLater(
        account.connectWithKey('sk-or-v1-falsch'),
        throwsA(
          isA<OpenRouterException>().having(
            (e) => e.failure,
            'failure',
            OpenRouterFailure.unauthorized,
          ),
        ),
      );

      // Ein Schlüssel, der nicht geht, wird nicht abgelegt.
      expect(await store.read(), isNull);
      expect(account.isConnected, isFalse);
    });

    test(
      'ein gültiger Schlüssel landet mit seiner Herkunft im Speicher',
      () async {
        final store = InMemoryOpenRouterKeyStore();
        final account = OpenRouterAccount(
          store: store,
          api: OpenRouterApi(
            client: _api(
              key: {
                'data': {'is_free_tier': false},
              },
            ),
          ),
          login: _FakeLogin(null),
        );

        await account.connectWithKey('  sk-or-v1-eigen  ');

        expect((await store.read())!.value, 'sk-or-v1-eigen');
        expect(account.key!.origin, OpenRouterKeyOrigin.manual);
        expect(account.hasCredit, isTrue);
      },
    );

    test('ein leeres Feld führt zu nichts', () async {
      final account = OpenRouterAccount(
        store: InMemoryOpenRouterKeyStore(),
        api: OpenRouterApi(client: _api()),
        login: _FakeLogin(null),
      );

      await expectLater(
        account.connectWithKey('   '),
        throwsA(isA<OpenRouterException>()),
      );
    });
  });

  group('Zurückgewiesen und getrennt', () {
    test('ein abgelehnter Zugang wird nicht heimlich weggeworfen', () async {
      final store = InMemoryOpenRouterKeyStore(
        const OpenRouterKey(
          value: 'sk-or-v1-alt',
          origin: OpenRouterKeyOrigin.login,
        ),
      );
      final account = OpenRouterAccount(
        store: store,
        api: OpenRouterApi(client: _api(key: {'data': <String, Object?>{}})),
        login: _FakeLogin(null),
      );
      await account.load();

      account.markRejected();

      expect(account.needsReconnect, isTrue);
      // Nicht benutzbar, aber auch nicht spurlos verschwunden: Der User soll
      // sehen, was los ist, statt sich zu wundern.
      expect(account.isUsable, isFalse);
      expect(account.isConnected, isTrue);
      expect(await store.read(), isNotNull);
    });

    test('Trennen räumt den Speicher wirklich leer', () async {
      final store = InMemoryOpenRouterKeyStore(
        const OpenRouterKey(
          value: 'sk-or-v1-alt',
          origin: OpenRouterKeyOrigin.login,
        ),
      );
      final account = OpenRouterAccount(
        store: store,
        api: OpenRouterApi(client: _api(key: {'data': <String, Object?>{}})),
        login: _FakeLogin(null),
      );
      await account.load();

      await account.disconnect();

      expect(account.isConnected, isFalse);
      expect(account.needsReconnect, isFalse);
      expect(await store.read(), isNull);
    });

    test('ein neuer Login hebt die Sperre wieder auf', () async {
      final account = OpenRouterAccount(
        store: InMemoryOpenRouterKeyStore(
          const OpenRouterKey(
            value: 'sk-or-v1-alt',
            origin: OpenRouterKeyOrigin.login,
          ),
        ),
        api: OpenRouterApi(
          client: _api(
            keys: {'key': 'sk-or-v1-frisch'},
            key: {'data': <String, Object?>{}},
          ),
        ),
        login: _FakeLogin(Uri.parse('neurohelp://openrouter?code=NEU')),
      );
      await account.load();
      account.markRejected();

      await account.connect();

      expect(account.needsReconnect, isFalse);
      expect(account.isUsable, isTrue);
      expect(account.key!.value, 'sk-or-v1-frisch');
    });
  });
}
