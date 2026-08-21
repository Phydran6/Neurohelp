import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/ai/data/layered_ai_client.dart';

/// Eine Stufe, die man vorher einstellt.
class _Stage implements AiClient {
  _Stage(this.label, {this.answer, this.failWith, bool enabled = true})
    : _enabled = enabled;

  final String label;
  final String? answer;
  final String? failWith;

  bool _enabled;
  int calls = 0;

  @override
  bool get isEnabled => _enabled;

  @override
  void setEnabled({required bool enabled}) => _enabled = enabled;

  @override
  Future<void> probe() async {
    await run(AiTask.answerHelp, input: 'test');
  }

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async {
    calls++;
    final reason = failWith;
    if (reason != null) throw AiUnavailableException(reason);
    return answer!;
  }
}

/// Der Merksatz aus dem Konzept: **Fehler fallen weich.** Statt einer
/// Fehlermeldung geht es eine Stufe tiefer.
void main() {
  test(
    'die oberste Stufe antwortet, die anderen bleiben unangetastet',
    () async {
      final eigen = _Stage('eigener Zugang', answer: 'Von oben');
      final standard = _Stage('Standard', answer: 'Von unten');

      final client = LayeredAiClient([eigen, standard], enabled: true);

      expect(await client.run(AiTask.splitTask, input: 'x'), 'Von oben');
      expect(standard.calls, 0);
    },
  );

  test('fällt die obere Stufe aus, übernimmt die nächste – lautlos', () async {
    final eigen = _Stage('eigener Zugang', failWith: 'Limit erreicht');
    final standard = _Stage('Standard', answer: 'Von unten');

    final client = LayeredAiClient([eigen, standard], enabled: true);

    expect(await client.run(AiTask.splitTask, input: 'x'), 'Von unten');
    expect(eigen.calls, 1);
    expect(standard.calls, 1);
  });

  test('eine abgeschaltete Stufe wird übersprungen, nicht versucht', () async {
    final aus = _Stage('aus', answer: 'nie', enabled: false);
    final standard = _Stage('Standard', answer: 'Von unten');

    final client = LayeredAiClient([aus, standard], enabled: true);

    await client.run(AiTask.splitTask, input: 'x');
    expect(aus.calls, 0);
  });

  test('fällt alles aus, kommt der Grund der letzten Stufe', () async {
    final eigen = _Stage('eigener Zugang', failWith: 'Limit erreicht');
    final standard = _Stage('Standard', failWith: 'Backend antwortet nicht');

    final client = LayeredAiClient([eigen, standard], enabled: true);

    await expectLater(
      client.run(AiTask.splitTask, input: 'x'),
      throwsA(
        isA<AiUnavailableException>().having(
          (e) => e.reason,
          'reason',
          'Backend antwortet nicht',
        ),
      ),
    );
  });

  test('der KI-Schalter schaltet alle Stufen', () {
    final eigen = _Stage('eigener Zugang', answer: 'a');
    final standard = _Stage('Standard', answer: 'b');

    final client = LayeredAiClient([eigen, standard], enabled: true)
      ..setEnabled(enabled: false);

    expect(client.isEnabled, isFalse);
    expect(eigen.isEnabled, isFalse);
    expect(standard.isEnabled, isFalse);
  });

  test('aus heißt aus – auch wenn eine Stufe könnte', () async {
    final standard = _Stage('Standard', answer: 'b');
    final client = LayeredAiClient([standard]);

    await expectLater(
      client.run(AiTask.splitTask, input: 'x'),
      throwsA(
        isA<AiUnavailableException>().having(
          (e) => e.reason,
          'reason',
          contains('Einstellungen'),
        ),
      ),
    );
    expect(standard.calls, 0);
  });

  test('an, aber nichts hinterlegt: das sagt die App ehrlich', () async {
    final client = LayeredAiClient([
      _Stage('nichts', answer: 'x', enabled: false),
    ], enabled: true);

    expect(client.isEnabled, isFalse);
    await expectLater(
      client.probe(),
      throwsA(
        isA<AiUnavailableException>().having(
          (e) => e.reason,
          'reason',
          contains('kein KI-Zugang'),
        ),
      ),
    );
  });
}
