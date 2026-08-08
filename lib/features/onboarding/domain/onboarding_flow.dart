import '../../../core/ai/ai_client.dart';
import '../../../core/settings/app_settings.dart';

/// Die Schritte des Onboardings (Konzept, Abschnitt 16).
///
/// Reihenfolge steht fest, der Feinschliff der Texte kommt laut Konzept
/// bewusst nach der ersten Bauphase.
enum OnboardingStep {
  /// Konto anlegen: Benutzername, E-Mail, Passwort. Pflicht.
  account,

  /// KI ja oder nein. Pflichtentscheidung, mit ruhigem Hinweis darauf,
  /// welche Vorteile ohne KI wegfallen.
  aiChoice,

  /// App-Sperre: Biometrie und/oder PIN. Pflicht.
  security,

  /// MFA, Security Key, Wiederherstellungs-Code. Freiwillig.
  extraSecurity,

  /// Tonfall: locker, neutral oder sachlich.
  tone;

  /// Ob der Schritt übersprungen werden darf.
  bool get isOptional => this == OnboardingStep.extraSecurity;
}

/// Zustand des Onboardings – reine Logik, ohne UI und ohne Speicher.
///
/// Der Ablauf ist bewusst linear: ein Schritt, eine Entscheidung. Kein
/// Fortschrittsbalken, der Druck macht.
class OnboardingFlow {
  const OnboardingFlow({
    this.step = OnboardingStep.account,
    this.accountCreated = false,
    this.aiEnabled,
    this.lockMethod,
    this.tone,
  });

  final OnboardingStep step;

  final bool accountCreated;

  /// `null`, solange der User sich nicht entschieden hat.
  final bool? aiEnabled;

  /// `null` bzw. [LockMethod.none], solange nichts eingerichtet ist.
  final LockMethod? lockMethod;

  final AiTone? tone;

  static const List<OnboardingStep> _order = OnboardingStep.values;

  /// Ob der aktuelle Schritt abgeschlossen ist und weitergegangen werden darf.
  bool get canAdvance => _isSatisfied(step);

  /// Ob alle Pflichtschritte erledigt sind.
  bool get isComplete => _order.every(_isSatisfied);

  /// Der nächste Schritt, oder `null`, wenn das Onboarding fertig ist.
  OnboardingStep? get nextStep {
    final index = _order.indexOf(step);
    return index + 1 < _order.length ? _order[index + 1] : null;
  }

  /// Geht einen Schritt weiter.
  ///
  /// Wirft [StateError], wenn der aktuelle Schritt noch offen ist – die UI
  /// muss den Weiter-Knopf so lange gesperrt lassen.
  OnboardingFlow advance() {
    if (!canAdvance) {
      throw StateError('Schritt $step ist noch nicht abgeschlossen.');
    }

    final next = nextStep;
    if (next == null) return this;

    return _copyWith(step: next);
  }

  /// Geht einen Schritt zurück. Am Anfang passiert nichts.
  OnboardingFlow back() {
    final index = _order.indexOf(step);
    if (index == 0) return this;
    return _copyWith(step: _order[index - 1]);
  }

  /// Überspringt einen freiwilligen Schritt.
  ///
  /// Wirft [StateError] bei Pflichtschritten – kein stiller Ausweg an einer
  /// Pflichtentscheidung vorbei.
  OnboardingFlow skip() {
    if (!step.isOptional) {
      throw StateError('Schritt $step ist Pflicht und nicht überspringbar.');
    }
    return _copyWith(step: nextStep ?? step);
  }

  OnboardingFlow withAccountCreated() => _copyWith(accountCreated: true);

  OnboardingFlow withAiChoice({required bool enabled}) =>
      _copyWith(aiEnabled: enabled);

  OnboardingFlow withLockMethod(LockMethod method) =>
      _copyWith(lockMethod: method);

  OnboardingFlow withTone(AiTone value) => _copyWith(tone: value);

  /// Die Einstellungen, die am Ende gespeichert werden.
  ///
  /// Wirft [StateError], solange das Onboarding nicht vollständig ist.
  AppSettings toSettings() {
    if (!isComplete) {
      throw StateError('Onboarding ist noch nicht abgeschlossen.');
    }

    return AppSettings(
      onboardingCompleted: true,
      aiEnabled: aiEnabled!,
      tone: tone!,
      lockMethod: lockMethod!,
    );
  }

  bool _isSatisfied(OnboardingStep value) => switch (value) {
    OnboardingStep.account => accountCreated,
    OnboardingStep.aiChoice => aiEnabled != null,
    OnboardingStep.security =>
      lockMethod != null && lockMethod != LockMethod.none,
    OnboardingStep.extraSecurity => true,
    OnboardingStep.tone => tone != null,
  };

  OnboardingFlow _copyWith({
    OnboardingStep? step,
    bool? accountCreated,
    bool? aiEnabled,
    LockMethod? lockMethod,
    AiTone? tone,
  }) {
    return OnboardingFlow(
      step: step ?? this.step,
      accountCreated: accountCreated ?? this.accountCreated,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      lockMethod: lockMethod ?? this.lockMethod,
      tone: tone ?? this.tone,
    );
  }
}
