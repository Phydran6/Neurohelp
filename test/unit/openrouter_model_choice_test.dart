import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_model.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_model_choice.dart';

OpenRouterModel _model(
  String id, {
  int context = 100000,
  double price = 0,
  List<String> input = const ['text'],
  List<String> output = const ['text'],
}) {
  return OpenRouterModel(
    id: id,
    name: id,
    contextLength: context,
    promptPrice: price,
    completionPrice: price,
    inputModalities: input,
    outputModalities: output,
  );
}

/// Der Merksatz aus dem Konzept: **kein Modell wird fest verdrahtet.** Die
/// Auswahl passiert zur Laufzeit, und diese Regeln entscheiden darüber.
void main() {
  group('OpenRouterModel', () {
    test('liest das Verzeichnisformat von OpenRouter', () {
      final model = OpenRouterModel.fromJson(const {
        'id': 'anbieter/modell:free',
        'name': 'Modell',
        'context_length': 131072,
        // OpenRouter liefert Preise als Zeichenketten, nicht als Zahlen.
        'pricing': {'prompt': '0', 'completion': '0'},
        'architecture': {
          'input_modalities': ['text', 'image'],
          'output_modalities': ['text'],
        },
      });

      expect(model.id, 'anbieter/modell:free');
      expect(model.contextLength, 131072);
      expect(model.isFree, isTrue);
      expect(model.isTextChat, isTrue);
    });

    test('ohne Preisangabe gilt ein Modell nicht als kostenlos', () {
      // Lieber ein Modell auslassen, als dem User unbemerkt Guthaben
      // abzuziehen.
      final model = OpenRouterModel.fromJson(const {
        'id': 'anbieter/ohne-preis',
        'pricing': <String, Object?>{},
      });

      expect(model.isFree, isFalse);
    });
  });

  group('OpenRouterModelChoice', () {
    test('nimmt nur kostenlose Modelle, solange kein Guthaben da ist', () {
      final ranked = OpenRouterModelChoice.rank([
        _model('teuer/gross', price: 0.00001, context: 1000000),
        _model('gratis/klein:free'),
      ]);

      expect(ranked.map((m) => m.id), ['gratis/klein:free']);
    });

    test('mit Guthaben kommen kostenpflichtige dazu – aber erst danach', () {
      final ranked = OpenRouterModelChoice.rank([
        _model('teuer/gross', price: 0.00001, context: 1000000),
        _model('gratis/klein:free', context: 8000),
      ], allowPaid: true);

      // Kostenlos zuerst: Geld wird nur ausgegeben, wenn es nicht anders geht.
      expect(ranked.first.id, 'gratis/klein:free');
      expect(ranked.map((m) => m.id), contains('teuer/gross'));
    });

    test('lässt Klassifizierer und Nicht-Chat-Modelle draußen', () {
      final ranked = OpenRouterModelChoice.rank([
        _model('anbieter/content-safety:free'),
        _model('anbieter/llama-guard:free'),
        _model('anbieter/text-embedding:free'),
        _model('anbieter/reranker:free'),
        _model('anbieter/tts-1:free'),
        _model('anbieter/bildgenerator:free', output: const ['image']),
        _model('anbieter/echtes-modell:free'),
      ]);

      expect(ranked.map((m) => m.id), ['anbieter/echtes-modell:free']);
    });

    test('sortiert nach Kontextlänge und schiebt Winzlinge nach hinten', () {
      final ranked = OpenRouterModelChoice.rank([
        _model('anbieter/nano-modell:free', context: 900000),
        _model('anbieter/mittel:free', context: 60000),
        _model('anbieter/gross:free', context: 500000),
      ]);

      expect(ranked.map((m) => m.id), [
        'anbieter/gross:free',
        'anbieter/mittel:free',
        'anbieter/nano-modell:free',
      ]);
    });

    test('hält mehrere Kandidaten in Reserve, aber nicht endlos viele', () {
      final many = [
        for (var i = 0; i < 20; i++)
          _model('anbieter/modell-$i:free', context: 1000 - i),
      ];

      final ranked = OpenRouterModelChoice.rank(many);

      expect(ranked, hasLength(OpenRouterModelChoice.candidateCount));
      expect(ranked.first.id, 'anbieter/modell-0:free');
    });

    test('die Reihenfolge ist zwischen zwei Läufen gleich', () {
      final models = [
        _model('b/zwei:free'),
        _model('a/eins:free'),
        _model('c/drei:free'),
      ];

      expect(
        OpenRouterModelChoice.rank(models).map((m) => m.id),
        OpenRouterModelChoice.rank(models.reversed.toList()).map((m) => m.id),
      );
    });
  });
}
