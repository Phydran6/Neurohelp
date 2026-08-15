import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/features/onboarding/domain/intro_slides.dart';
import 'package:neurohelp/features/onboarding/domain/onboarding_flow.dart';

void main() {
  group('Erklärbildschirme', () {
    test('es bleiben genau zwei', () {
      // Die Obergrenze ist die eigentliche Anforderung: Wer hier einen
      // dritten Bildschirm anhängt, baut wieder ein Tutorial.
      expect(IntroSlides.all, hasLength(2));
    });

    test('für jeden Erklärschritt im Ablauf gibt es einen Bildschirm', () {
      final erklaerschritte = OnboardingStep.values
          .where(
            (step) =>
                step == OnboardingStep.welcome ||
                step == OnboardingStep.howItWorks,
          )
          .length;

      expect(IntroSlides.all, hasLength(erklaerschritte));
    });

    test('jeder Bildschirm ist vollständig ausgefüllt', () {
      for (final slide in IntroSlides.all) {
        expect(slide.id, isNotEmpty, reason: slide.id);
        expect(slide.title, isNotEmpty, reason: slide.id);
        expect(slide.lead, isNotEmpty, reason: slide.id);
        expect(slide.action, isNotEmpty, reason: slide.id);
        expect(slide.points, isNotEmpty, reason: slide.id);

        for (final point in slide.points) {
          expect(point.id, isNotEmpty, reason: '${slide.id}/${point.id}');
          expect(point.label, isNotEmpty, reason: '${slide.id}/${point.id}');
          expect(point.text, isNotEmpty, reason: '${slide.id}/${point.id}');
        }
      }
    });

    test('die Schlüssel sind eindeutig', () {
      final slideIds = IntroSlides.all.map((slide) => slide.id).toList();
      expect(slideIds.toSet(), hasLength(slideIds.length));

      // Beide Bildschirme stehen im Hilfe-Bereich untereinander auf einer
      // Seite. Doppelte Punkt-Schlüssel gäben dort doppelte Widget-Keys.
      final pointIds = [
        for (final slide in IntroSlides.all)
          for (final point in slide.points) point.id,
      ];
      expect(pointIds.toSet(), hasLength(pointIds.length));
    });

    test('der erste Bildschirm nennt die vier Features', () {
      final ids = IntroSlides.whatItDoes.points.map((p) => p.id).toList();

      expect(ids, containsAll(['anruf', 'termin', 'nachricht', 'aufgabe']));
    });

    test('der zweite Bildschirm sagt, wo die Daten bleiben', () {
      final lokal = IntroSlides.howItWorks.points.firstWhere(
        (point) => point.id == 'lokal',
      );

      // Das Versprechen …
      expect('${lokal.label} ${lokal.text}', contains('Gerät'));
      // … und die Ausnahme davon, die dazugehört. Ohne sie wäre der Satz
      // schöner als die Wahrheit.
      expect(lokal.text, contains('KI'));
    });
  });
}
