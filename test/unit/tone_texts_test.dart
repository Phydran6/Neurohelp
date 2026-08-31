import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/companion/tone_texts.dart';
import 'package:neurohelp/features/home/domain/greetings.dart';

/// Der gewählte Ton muss sich auch auswirken.
///
/// Anlass: Die Frage „Wie soll ich mit dir reden?" kam im Onboarding, die
/// Antwort wurde gespeichert – und danach klang die App überall gleich.
void main() {
  group('Tonfall', () {
    test('jeder Ton hat eigene Sprüche', () {
      final sets = AiTone.values.map(Greetings.linesFor).toList();

      for (final lines in sets) {
        expect(lines, isNotEmpty);
      }
      // Keine zwei Töne dürfen denselben Katalog benutzen, sonst merkt
      // niemand den Unterschied.
      expect(sets[0], isNot(equals(sets[1])));
      expect(sets[1], isNot(equals(sets[2])));
    });

    test('der Spruch bleibt am selben Tag derselbe', () {
      final date = DateTime(2026, 8, 10);

      expect(
        Greetings.forDate(date, tone: AiTone.neutral),
        Greetings.forDate(date, tone: AiTone.neutral),
      );
    });

    test('der Spruch wechselt mit dem Ton', () {
      final date = DateTime(2026, 8, 10);

      expect(
        Greetings.forDate(date, tone: AiTone.locker),
        isNot(Greetings.forDate(date, tone: AiTone.sachlich)),
      );
    });

    test('die Beschriftungen unterscheiden sich', () {
      const locker = ToneTexts(AiTone.locker);
      const sachlich = ToneTexts(AiTone.sachlich);

      expect(locker.startButton, isNot(sachlich.startButton));
      expect(locker.menuTitle, isNot(sachlich.menuTitle));
      expect(locker.allDone, isNot(sachlich.allDone));
      expect(locker.historyEmpty, isNot(sachlich.historyEmpty));
    });

    test('kein Ton bleibt irgendwo leer', () {
      for (final tone in AiTone.values) {
        final texts = ToneTexts(tone);

        for (final text in [
          texts.startButton,
          texts.menuTitle,
          texts.nextStepLabel,
          texts.allDone,
          texts.historyFound,
          texts.historyEmpty,
          texts.askAi,
          texts.aiOffer,
          texts.aiWorking,
          texts.aiResultTitle,
        ]) {
          expect(text.trim(), isNotEmpty, reason: tone.name);
        }
      }
    });

    test('Überschrift und Knopf im KI-Block sagen nicht dasselbe', () {
      // Gemeldet aus dem Gerätetest: „Soll ich was vorschlagen?" stand als
      // Überschrift da und gleich darunter nochmal auf dem Knopf.
      for (final tone in AiTone.values) {
        final texts = ToneTexts(tone);

        expect(texts.aiOffer, isNot(texts.askAi), reason: tone.name);
      }
    });
  });

  group('KI-Antworten zerlegen', () {
    test('Nummerierung und Spiegelstriche fliegen raus', () {
      final lines = AiSuggestions.linesOf(
        '1. Kartons besorgen\n'
        '- Kündigung schreiben\n'
        '\n'
        '• Nachsendeauftrag stellen\n'
        '2) Strom ummelden',
      );

      expect(lines, [
        'Kartons besorgen',
        'Kündigung schreiben',
        'Nachsendeauftrag stellen',
        'Strom ummelden',
      ]);
    });

    test('leere Antwort ergibt keine Vorschläge', () {
      expect(AiSuggestions.linesOf('   \n\n  '), isEmpty);
    });
  });
}
