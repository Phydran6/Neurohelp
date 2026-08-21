import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/ai/data/openrouter_ai_client.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_account.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_api.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_key.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_key_store.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_login.dart';

class _NoLogin implements OpenRouterLogin {
  const _NoLogin();

  @override
  Future<Uri?> authorize(Uri url, {required String callbackScheme}) async =>
      null;
}

/// Ein OpenRouter, das man vorher einstellt: welche Modelle es gibt und wie
/// jedes einzelne antwortet.
class _FakeOpenRouter {
  _FakeOpenRouter({required this.models, required this.answers});

  /// Modell-Kennungen, die im Verzeichnis stehen.
  final List<String> models;

  /// Je Modell: der Antworttext, oder ein HTTP-Status als Fehler.
  final Map<String, Object> answers;

  final List<String> asked = [];
  int catalogCalls = 0;

  MockClient get client => MockClient((request) async {
    if (request.url.path.endsWith('/models')) {
      catalogCalls++;
      return _json({
        'data': [
          for (final id in models)
            {
              'id': id,
              'context_length': 100000 - models.indexOf(id),
              'pricing': {'prompt': '0', 'completion': '0'},
            },
        ],
      });
    }

    if (request.url.path.endsWith('/key')) {
      return _json({'data': <String, Object?>{}});
    }

    final model =
        (jsonDecode(request.body) as Map<String, Object?>)['model']! as String;
    asked.add(model);

    final answer = answers[model];
    if (answer is int) return _json({'error': 'weg'}, status: answer);

    return _json({
      'choices': [
        {
          'message': {'content': answer},
        },
      ],
    });
  });

  static http.Response _json(Object? body, {int status = 200}) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );
}

Future<OpenRouterAiClient> _clientFor(
  _FakeOpenRouter backend, {
  bool rejected = false,
}) async {
  final api = OpenRouterApi(client: backend.client);
  final account = OpenRouterAccount(
    store: InMemoryOpenRouterKeyStore(
      const OpenRouterKey(
        value: 'sk-or-v1-test',
        origin: OpenRouterKeyOrigin.login,
      ),
    ),
    api: api,
    login: const _NoLogin(),
  );
  await account.load();
  if (rejected) account.markRejected();

  return OpenRouterAiClient(account: account, api: api, enabled: true);
}

void main() {
  test('holt das Verzeichnis und fragt das beste Modell', () async {
    final backend = _FakeOpenRouter(
      models: ['a/gross:free', 'b/klein:free'],
      answers: {'a/gross:free': 'Ein Vorschlag'},
    );

    final client = await _clientFor(backend);
    final answer = await client.run(AiTask.splitTask, input: 'Steuer machen');

    expect(answer, 'Ein Vorschlag');
    expect(backend.asked, ['a/gross:free']);
  });

  test('geht still zum nächsten Modell, wenn eins am Limit hängt', () async {
    final backend = _FakeOpenRouter(
      models: ['a/gross:free', 'b/klein:free'],
      answers: {
        // 429: Ratenlimit. Bei kostenlosen Modellen der Normalfall, kein
        // Grund für eine Fehlermeldung.
        'a/gross:free': 429,
        'b/klein:free': 'Doch eine Antwort',
      },
    );

    final client = await _clientFor(backend);
    final answer = await client.run(AiTask.composeMessage, input: 'Absage');

    expect(answer, 'Doch eine Antwort');
    expect(backend.asked, ['a/gross:free', 'b/klein:free']);
  });

  test('ein verschwundenes Modell macht das Verzeichnis ungültig', () async {
    final backend = _FakeOpenRouter(
      models: ['a/weg:free', 'b/da:free'],
      answers: {'a/weg:free': 404, 'b/da:free': 'Antwort'},
    );

    final client = await _clientFor(backend);
    await client.run(AiTask.answerHelp, input: 'Frage');
    await client.run(AiTask.answerHelp, input: 'Noch eine Frage');

    // Beim zweiten Mal wird neu nachgeschlagen, statt auf dem veralteten
    // Stand sitzen zu bleiben.
    expect(backend.catalogCalls, greaterThan(1));
  });

  test('das Verzeichnis wird nicht bei jeder Anfrage neu geholt', () async {
    final backend = _FakeOpenRouter(
      models: ['a/gross:free'],
      answers: {'a/gross:free': 'Antwort'},
    );

    final client = await _clientFor(backend);
    await client.run(AiTask.answerHelp, input: 'Eins');
    await client.run(AiTask.answerHelp, input: 'Zwei');

    expect(backend.catalogCalls, 1);
  });

  test('hilft kein Modell, ist das ein ruhiger Ausfall', () async {
    final backend = _FakeOpenRouter(
      models: ['a/eins:free', 'b/zwei:free'],
      answers: {'a/eins:free': 429, 'b/zwei:free': 429},
    );

    final client = await _clientFor(backend);

    await expectLater(
      client.run(AiTask.splitTask, input: 'Irgendwas'),
      throwsA(isA<AiUnavailableException>()),
    );
  });

  test('ein zurückgewiesener Zugang schaltet die Stufe ab', () async {
    final backend = _FakeOpenRouter(
      models: ['a/eins:free'],
      answers: {'a/eins:free': 401},
    );

    final client = await _clientFor(backend);
    expect(client.isEnabled, isTrue);

    await expectLater(
      client.run(AiTask.splitTask, input: 'Irgendwas'),
      throwsA(isA<AiUnavailableException>()),
    );

    // Danach fragt die App diesen Weg nicht mehr, sondern fällt eine Stufe
    // tiefer – bis der User neu verbunden hat.
    expect(client.isEnabled, isFalse);
    expect(backend.asked, ['a/eins:free']);
  });

  test('ohne verbundenen Zugang ist die Stufe aus', () async {
    final backend = _FakeOpenRouter(models: const [], answers: const {});
    final client = await _clientFor(backend, rejected: true);

    expect(client.isEnabled, isFalse);
  });

  test('der KI-Schalter steht über allem', () async {
    final backend = _FakeOpenRouter(
      models: ['a/eins:free'],
      answers: {'a/eins:free': 'Antwort'},
    );

    final client = await _clientFor(backend);
    client.setEnabled(enabled: false);

    expect(client.isEnabled, isFalse);
    await expectLater(
      client.run(AiTask.splitTask, input: 'Irgendwas'),
      throwsA(isA<AiUnavailableException>()),
    );
    expect(backend.asked, isEmpty);
  });
}
