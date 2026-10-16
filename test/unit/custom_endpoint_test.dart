import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/ai/custom/custom_endpoint.dart';
import 'package:neurohelp/core/ai/custom/custom_endpoint_account.dart';
import 'package:neurohelp/core/ai/custom/custom_endpoint_store.dart';
import 'package:neurohelp/core/ai/data/custom_endpoint_ai_client.dart';

/// Prüft den selbst eingetragenen KI-Zugang (Konzept, Abschnitt 17a).
///
/// Zwei Dinge stehen hier auf dem Spiel. Erstens: Die Adresse, die jemand
/// einträgt, muss auch dann funktionieren, wenn sie aus einer Anleitung
/// kopiert wurde – mit Schrägstrich, ohne, oder gleich mit dem Aufruf dran.
/// Zweitens: Ein Fehler muss **unterscheidbar** sein. „Geht nicht" schickt
/// niemanden irgendwohin.
void main() {
  const openAi = CustomAiEndpoint(
    kind: CustomEndpointKind.openAiCompatible,
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
    apiKey: 'sk-test-1234',
  );

  const anthropic = CustomAiEndpoint(
    kind: CustomEndpointKind.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    model: 'claude-haiku-4-5-20251001',
    apiKey: 'sk-ant-abcd',
  );

  group('Adresse', () {
    test('hängt den Aufruf an', () {
      expect(
        openAi.completionUrl.toString(),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(
        anthropic.completionUrl.toString(),
        'https://api.anthropic.com/v1/messages',
      );
    });

    test('verträgt einen Schrägstrich am Ende', () {
      const withSlash = CustomAiEndpoint(
        kind: CustomEndpointKind.openAiCompatible,
        baseUrl: 'https://beispiel.de/api/',
        model: 'llama3.1',
      );
      expect(
        withSlash.completionUrl.toString(),
        'https://beispiel.de/api/chat/completions',
      );
    });

    test('verdoppelt den Aufruf nicht, wenn er schon dransteht', () {
      // Der häufigste Kopierfehler: die volle Adresse aus einer Anleitung.
      const full = CustomAiEndpoint(
        kind: CustomEndpointKind.openAiCompatible,
        baseUrl: 'https://beispiel.de/v1/chat/completions',
        model: 'llama3.1',
      );
      expect(
        full.completionUrl.toString(),
        'https://beispiel.de/v1/chat/completions',
      );
    });
  });

  group('Vorabprüfung', () {
    test('nimmt einen vollständigen Eintrag an', () {
      expect(openAi.problem, isNull);
      expect(anthropic.problem, isNull);
    });

    test('merkt, wenn die Adresse keine ist', () {
      const broken = CustomAiEndpoint(
        kind: CustomEndpointKind.openAiCompatible,
        baseUrl: 'api.openai.com',
        model: 'gpt-4o-mini',
      );
      expect(broken.problem, contains('https://'));
    });

    test('merkt, wenn der Modellname fehlt', () {
      expect(openAi.copyWith(model: '  ').problem, contains('Modellnamen'));
    });

    test('ein eigener Server darf ohne Schlüssel laufen', () {
      // Ollama im Heimnetz verlangt meist keinen – das ist kein Fehler.
      const local = CustomAiEndpoint(
        kind: CustomEndpointKind.openAiCompatible,
        baseUrl: 'http://192.168.1.10:11434/v1',
        model: 'llama3.1',
      );
      expect(local.problem, isNull);
      expect(local.keyHint, 'ohne Schlüssel');
    });

    test('Anthropic ohne Schlüssel wird vorher abgefangen', () {
      expect(anthropic.copyWith(apiKey: '').problem, contains('sk-ant-'));
    });
  });

  group('Anfrage', () {
    test('OpenAI bekommt System- und Nutzernachricht', () {
      final body = openAi.requestBody(system: 'Sei kurz.', input: 'Hallo');
      expect(body['model'], 'gpt-4o-mini');
      expect(body['messages'], [
        {'role': 'system', 'content': 'Sei kurz.'},
        {'role': 'user', 'content': 'Hallo'},
      ]);
      expect(openAi.headers['Authorization'], 'Bearer sk-test-1234');
    });

    test('Anthropic bekommt system getrennt und max_tokens', () {
      final body = anthropic.requestBody(system: 'Sei kurz.', input: 'Hallo');
      expect(body['system'], 'Sei kurz.');
      expect(body['max_tokens'], isA<int>());
      expect(anthropic.headers['x-api-key'], 'sk-ant-abcd');
      // Pflichtfeld bei Anthropic. Ohne das kommt 400 zurück, und die
      // Meldung liest sich wie ein falscher Schlüssel.
      expect(anthropic.headers['anthropic-version'], isNotEmpty);
    });

    test('der Schlüssel taucht nie vollständig in der Anzeige auf', () {
      expect(openAi.keyHint, '••••1234');
      expect(openAi.keyHint, isNot(contains('sk-test')));
    });
  });

  group('Verbinden', () {
    CustomEndpointAccount accountWith(
      Future<http.Response> Function(http.Request request) handler,
    ) => CustomEndpointAccount(
      store: InMemoryCustomEndpointStore(),
      client: MockClient(handler),
    );

    test('speichert erst, wenn der Server wirklich geantwortet hat', () async {
      final account = accountWith(
        (_) async => http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Da.'},
              },
            ],
          }),
          200,
        ),
      );

      await account.connect(openAi);
      expect(account.isConnected, isTrue);
      expect(account.endpoint!.model, 'gpt-4o-mini');
    });

    test('speichert nichts, wenn der Schlüssel abgelehnt wird', () async {
      final account = accountWith(
        (_) async => http.Response('{"error":"bad key"}', 401),
      );

      await expectLater(
        () => account.connect(openAi),
        throwsA(
          isA<CustomEndpointException>().having(
            (error) => error.failure,
            'failure',
            CustomEndpointFailure.unauthorized,
          ),
        ),
      );
      expect(account.isConnected, isFalse);
    });

    test('schickt bei 404 zur Adresse, nicht zum Schlüssel', () async {
      final account = accountWith((_) async => http.Response('nope', 404));

      await expectLater(
        () => account.connect(openAi),
        throwsA(
          isA<CustomEndpointException>()
              .having(
                (error) => error.failure,
                'failure',
                CustomEndpointFailure.modelUnknown,
              )
              .having((error) => error.reason, 'reason', contains('/v1')),
        ),
      );
    });

    test('ein unbekanntes Modell wird als solches benannt', () async {
      final account = accountWith(
        (_) async => http.Response(
          '{"error":{"message":"The model `quatsch` does not exist"}}',
          400,
        ),
      );

      await expectLater(
        () => account.connect(openAi.copyWith(model: 'quatsch')),
        throwsA(
          isA<CustomEndpointException>().having(
            (error) => error.reason,
            'reason',
            contains('quatsch'),
          ),
        ),
      );
    });

    test('ein kaputter Eintrag geht gar nicht erst ins Netz', () async {
      var calls = 0;
      final account = accountWith((_) async {
        calls++;
        return http.Response('{}', 200);
      });

      await expectLater(
        () => account.connect(openAi.copyWith(baseUrl: 'kein-url')),
        throwsA(isA<CustomEndpointException>()),
      );
      expect(calls, 0);
    });

    test('liest die Antwort von Anthropic aus ihren Blöcken', () async {
      final account = accountWith(
        (_) async => http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Erste Zeile'},
              {'type': 'text', 'text': 'Zweite Zeile'},
            ],
          }),
          200,
        ),
      );

      final text = await account.complete(anthropic, system: 'x', input: 'y');
      expect(text, 'Erste Zeile\nZweite Zeile');
    });
  });

  group('Als KI-Stufe', () {
    test('ist aus, solange kein Server eingetragen ist', () {
      final client = CustomEndpointAiClient(
        account: CustomEndpointAccount(store: InMemoryCustomEndpointStore()),
        enabled: true,
      );
      expect(client.isEnabled, isFalse);
    });

    test('antwortet über den eingetragenen Server', () async {
      final account = CustomEndpointAccount(
        store: InMemoryCustomEndpointStore(openAi),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': 'Kartons besorgen'},
                },
              ],
            }),
            200,
          ),
        ),
      );
      await account.load();

      final client = CustomEndpointAiClient(account: account, enabled: true);
      expect(client.isEnabled, isTrue);
      expect(
        await client.run(AiTask.splitTask, input: 'Umzug'),
        'Kartons besorgen',
      );
    });

    test('ein Ausfall kommt als KI-Grund an, nicht als Absturz', () async {
      // Ein Server im Heimnetz ist unterwegs nicht erreichbar. Die Stufe
      // meldet das als gewöhnliche KI-Unverfügbarkeit – dann geht die
      // Schicht darüber still eine Stufe tiefer, statt den Ablauf
      // abzubrechen.
      final account = CustomEndpointAccount(
        store: InMemoryCustomEndpointStore(openAi),
        client: MockClient((_) async => http.Response('weg', 500)),
      );
      await account.load();

      final client = CustomEndpointAiClient(account: account, enabled: true);

      await expectLater(
        () => client.run(AiTask.splitTask, input: 'Umzug'),
        throwsA(isA<AiUnavailableException>()),
      );
      // Der Zugang bleibt stehen: Wegwerfen wäre die schlechtere Überraschung.
      expect(account.isConnected, isTrue);
    });

    test('ein ausgeschalteter Schalter steht über allem', () async {
      final account = CustomEndpointAccount(
        store: InMemoryCustomEndpointStore(openAi),
        client: MockClient((_) async => fail('Da darf nichts rausgehen.')),
      );
      await account.load();

      final client = CustomEndpointAiClient(account: account, enabled: false);
      expect(client.isEnabled, isFalse);
      await expectLater(
        () => client.run(AiTask.splitTask, input: 'Umzug'),
        throwsA(isA<AiUnavailableException>()),
      );
    });
  });
}
