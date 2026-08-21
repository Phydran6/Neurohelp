import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_api.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_exception.dart';
import 'package:neurohelp/core/ai/openrouter/pkce.dart';

/// Hält die letzte Anfrage fest, damit der Test hineinschauen kann.
class _Recorder {
  http.Request? last;

  MockClient answering(
    Object? Function(http.Request request) body, {
    int status = 200,
  }) {
    return MockClient((request) async {
      last = request;
      final payload = body(request);
      return http.Response(
        payload is String ? payload : jsonEncode(payload),
        status,
        headers: {'content-type': 'application/json'},
      );
    });
  }
}

void main() {
  late _Recorder recorder;

  setUp(() => recorder = _Recorder());

  group('Login-Link', () {
    test('enthält Rücksprung, Challenge und Verfahren', () {
      final pkce = PkcePair.generate();
      final url = OpenRouterApi.loginUrl(pkce);

      expect(url.host, 'openrouter.ai');
      expect(url.path, '/auth');
      expect(url.queryParameters['callback_url'], OpenRouterApi.callbackUrl);
      expect(url.queryParameters['code_challenge'], pkce.challenge);
      expect(url.queryParameters['code_challenge_method'], 'S256');

      // Der Verifier bleibt in der App. Stünde er im Link, wäre PKCE sinnlos.
      expect(url.toString(), isNot(contains(pkce.verifier)));
    });

    test('das Rücksprung-Schema ist das der App', () {
      // Muss zum Android-Manifest und zur Info.plist passen.
      expect(OpenRouterApi.callbackScheme, 'neurohelp');
      expect(OpenRouterApi.callbackUrl, startsWith('neurohelp://'));
    });
  });

  group('Schlüssel eintauschen', () {
    test('schickt Code und Verifier und liefert den Schlüssel', () async {
      final api = OpenRouterApi(
        client: recorder.answering((_) => {'key': 'sk-or-v1-abc'}),
      );

      final key = await api.exchangeCode(code: 'C0DE', verifier: 'VERIF');

      expect(key, 'sk-or-v1-abc');

      final sent = jsonDecode(recorder.last!.body) as Map<String, Object?>;
      expect(sent['code'], 'C0DE');
      expect(sent['code_verifier'], 'VERIF');
      expect(sent['code_challenge_method'], 'S256');
      expect(recorder.last!.url.path, '/api/v1/auth/keys');
    });

    test(
      'eine Antwort ohne Schlüssel ist ein Fehler, kein leerer Zugang',
      () async {
        final api = OpenRouterApi(
          client: recorder.answering((_) => <String, Object?>{}),
        );

        await expectLater(
          api.exchangeCode(code: 'C0DE', verifier: 'VERIF'),
          throwsA(
            isA<OpenRouterException>().having(
              (e) => e.failure,
              'failure',
              OpenRouterFailure.malformed,
            ),
          ),
        );
      },
    );
  });

  group('Anfrage an ein Modell', () {
    test('setzt Schlüssel und Attribution und liefert den Text', () async {
      final api = OpenRouterApi(
        client: recorder.answering(
          (_) => {
            'choices': [
              {
                'message': {'content': '  Fertiger Text  '},
              },
            ],
          },
        ),
      );

      final text = await api.complete(
        key: 'sk-or-v1-abc',
        model: 'anbieter/modell:free',
        system: 'System',
        input: 'Eingabe',
      );

      expect(text, 'Fertiger Text');

      final request = recorder.last!;
      expect(request.headers['Authorization'], 'Bearer sk-or-v1-abc');
      // Ohne Attribution taucht die App bei OpenRouter nicht auf.
      expect(request.headers['HTTP-Referer'], isNotEmpty);
      expect(request.headers['X-Title'], 'Neurohelp');

      final sent = jsonDecode(request.body) as Map<String, Object?>;
      expect(sent['model'], 'anbieter/modell:free');
      expect(sent['messages'], [
        {'role': 'system', 'content': 'System'},
        {'role': 'user', 'content': 'Eingabe'},
      ]);
    });

    test('eine leere Antwort gilt als unbrauchbar', () async {
      final api = OpenRouterApi(
        client: recorder.answering(
          (_) => {
            'choices': [
              {
                'message': {'content': '   '},
              },
            ],
          },
        ),
      );

      await expectLater(
        api.complete(key: 'k', model: 'm', system: 's', input: 'i'),
        throwsA(isA<OpenRouterException>()),
      );
    });
  });

  group('Fehler einordnen', () {
    Future<OpenRouterFailure> failureFor(int status) async {
      final api = OpenRouterApi(
        client: recorder.answering(
          (_) => {
            'error': {'message': 'kaputt'},
          },
          status: status,
        ),
      );

      try {
        await api.complete(key: 'k', model: 'm', system: 's', input: 'i');
      } on OpenRouterException catch (error) {
        return error.failure;
      }
      fail('Es hätte einen Fehler geben müssen.');
    }

    test('401 heißt: neu verbinden, nicht anderes Modell', () async {
      final failure = await failureFor(401);

      expect(failure, OpenRouterFailure.unauthorized);
      expect(
        const OpenRouterException(
          OpenRouterFailure.unauthorized,
          '',
        ).worthAnotherModel,
        isFalse,
      );
    });

    test('429 und 404 sind einen weiteren Versuch wert', () async {
      expect(await failureFor(429), OpenRouterFailure.rateLimited);
      expect(await failureFor(404), OpenRouterFailure.modelUnavailable);

      for (final failure in [
        OpenRouterFailure.rateLimited,
        OpenRouterFailure.modelUnavailable,
      ]) {
        expect(
          OpenRouterException(failure, '').worthAnotherModel,
          isTrue,
          reason: 'Bei $failure kann das nächste Modell tragen.',
        );
      }
    });

    test('502 ist eine Störung des Dienstes', () async {
      expect(await failureFor(502), OpenRouterFailure.network);
    });

    test('die Meldung des Anbieters landet im technischen Teil', () async {
      final api = OpenRouterApi(
        client: recorder.answering(
          (_) => {
            'error': {'message': 'rate limit exceeded'},
          },
          status: 429,
        ),
      );

      try {
        await api.complete(key: 'k', model: 'm', system: 's', input: 'i');
        fail('Es hätte einen Fehler geben müssen.');
      } on OpenRouterException catch (error) {
        // Der Hauptext bleibt ruhig und deutsch, das Technische steckt
        // separat – so wie überall sonst in der App.
        expect(error.reason, isNot(contains('rate limit')));
        expect(error.technical, 'rate limit exceeded');
      }
    });
  });

  group('Guthaben', () {
    test('is_free_tier false heißt: der User hat aufgeladen', () async {
      final api = OpenRouterApi(
        client: recorder.answering(
          (_) => {
            'data': {'is_free_tier': false, 'limit_remaining': 4.2},
          },
        ),
      );

      final info = await api.keyInfo('sk-or-v1-abc');

      expect(info.hasCredit, isTrue);
      expect(info.remaining, 4.2);
      expect(recorder.last!.headers['Authorization'], 'Bearer sk-or-v1-abc');
    });

    test('ohne Auskunft bleibt es bei kostenlos', () async {
      final api = OpenRouterApi(
        client: recorder.answering((_) => <String, Object?>{}),
      );

      expect((await api.keyInfo('k')).hasCredit, isFalse);
    });
  });

  test('das Modellverzeichnis wird gelesen, nicht geraten', () async {
    final api = OpenRouterApi(
      client: recorder.answering(
        (_) => {
          'data': [
            {
              'id': 'a/eins:free',
              'pricing': {'prompt': '0', 'completion': '0'},
            },
            'kein Objekt',
            {
              'id': 'b/zwei',
              'pricing': {'prompt': '0.001', 'completion': '0.002'},
            },
          ],
        },
      ),
    );

    final models = await api.listModels();

    expect(models.map((m) => m.id), ['a/eins:free', 'b/zwei']);
    expect(models.first.isFree, isTrue);
    expect(models.last.isFree, isFalse);
    expect(recorder.last!.url.path, '/api/v1/models');
  });
}
