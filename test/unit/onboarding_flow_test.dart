import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:neurohelp/features/onboarding/domain/onboarding_flow.dart';

void main() {
  group('Ablauf', () {
    test('startet beim Konto und lässt ohne Konto nicht weiter', () {
      const flow = OnboardingFlow();

      expect(flow.step, OnboardingStep.account);
      expect(flow.canAdvance, isFalse);
      expect(flow.advance, throwsStateError);
    });

    test('läuft die Pflichtschritte der Reihe nach durch', () {
      final flow = const OnboardingFlow()
          .withAccountCreated()
          .advance()
          .withAiChoice(enabled: true)
          .advance()
          .withLockMethod(LockMethod.biometric)
          .advance();

      expect(flow.step, OnboardingStep.extraSecurity);
    });

    test('back geht zurück, am Anfang passiert nichts', () {
      const start = OnboardingFlow();
      expect(start.back().step, OnboardingStep.account);

      final second = start.withAccountCreated().advance();
      expect(second.back().step, OnboardingStep.account);
    });
  });

  group('Überspringen', () {
    test('freiwilliger Schritt lässt sich überspringen', () {
      final flow = const OnboardingFlow(step: OnboardingStep.extraSecurity);

      expect(flow.step.isOptional, isTrue);
      expect(flow.skip().step, OnboardingStep.tone);
    });

    test('Pflichtschritte lassen sich nicht überspringen', () {
      for (final step in OnboardingStep.values.where((s) => !s.isOptional)) {
        expect(
          OnboardingFlow(step: step).skip,
          throwsStateError,
          reason: '$step',
        );
      }
    });
  });

  group('KI-Toggle', () {
    test('ist eine Pflichtentscheidung, nicht nur ein Ja', () {
      const flow = OnboardingFlow(
        step: OnboardingStep.aiChoice,
        accountCreated: true,
      );

      expect(flow.canAdvance, isFalse);
      expect(flow.withAiChoice(enabled: false).canAdvance, isTrue);
      expect(flow.withAiChoice(enabled: true).canAdvance, isTrue);
    });
  });

  group('Sicherheit', () {
    test('LockMethod.none zählt nicht als eingerichtet', () {
      const flow = OnboardingFlow(step: OnboardingStep.security);

      expect(flow.withLockMethod(LockMethod.none).canAdvance, isFalse);
      expect(flow.withLockMethod(LockMethod.pin).canAdvance, isTrue);
    });
  });

  group('Abschluss', () {
    test('toSettings verlangt einen vollständigen Durchlauf', () {
      const incomplete = OnboardingFlow(accountCreated: true);
      expect(incomplete.isComplete, isFalse);
      expect(incomplete.toSettings, throwsStateError);
    });

    test('übernimmt alle Entscheidungen in die Einstellungen', () {
      final flow = const OnboardingFlow()
          .withAccountCreated()
          .withAiChoice(enabled: false)
          .withLockMethod(LockMethod.pin)
          .withTone(AiTone.sachlich);

      expect(flow.isComplete, isTrue);

      final settings = flow.toSettings();
      expect(settings.onboardingCompleted, isTrue);
      expect(settings.aiEnabled, isFalse);
      expect(settings.lockMethod, LockMethod.pin);
      expect(settings.tone, AiTone.sachlich);
      expect(settings.isLocked, isTrue);
    });
  });
}
