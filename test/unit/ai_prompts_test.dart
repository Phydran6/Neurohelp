import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/ai/ai_prompts.dart';

/// Beim nutzereigenen Zugang geht die Anfrage direkt vom Gerät raus – dann
/// baut die App die Anweisung selbst. Damit gibt es sie zweimal: hier und im
/// Backend. Das ist unvermeidbar und genau deshalb gefährlich: Läuft es
/// auseinander, antwortet die App je nach Stufe unterschiedlich, und niemand
/// findet den Grund.
void main() {
  group('AiPrompts', () {
    test('kennt jede Aufgabe in jedem Ton', () {
      for (final task in AiTask.values) {
        for (final tone in AiTone.values) {
          final system = AiPrompts.systemFor(task, tone);

          expect(system, isNotEmpty, reason: '$task / $tone');
          // Die Leitplanken stehen in jeder Anweisung, nicht nur in manchen.
          expect(system, contains('Neurohelp'), reason: '$task / $tone');
          expect(system, contains('Kein Druck'), reason: '$task / $tone');
        }
      }
    });

    test('der Ton kommt wirklich an', () {
      const task = AiTask.composeMessage;

      expect(AiPrompts.systemFor(task, AiTone.locker), contains('kumpelhaft'));
      expect(AiPrompts.systemFor(task, AiTone.sachlich), contains('sachlich'));
      expect(
        AiPrompts.systemFor(task, AiTone.locker),
        isNot(AiPrompts.systemFor(task, AiTone.neutral)),
      );
    });

    test('Backend und App kennen dieselben Aufgaben', () {
      final backend = File(
        'supabase/functions/ai-proxy/prompts.ts',
      ).readAsStringSync();

      for (final task in AiTask.values) {
        expect(
          backend,
          contains("'${task.wireName}'"),
          reason:
              'Die Aufgabe ${task.wireName} gibt es in der App, aber nicht '
              'im Backend – über den Standardweg käme dafür nur ein Fehler '
              'zurück.',
        );
      }
    });
  });
}
