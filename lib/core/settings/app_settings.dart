import '../ai/ai_client.dart';
import '../companion/companion_style.dart';

/// Wie die App beim Start entsperrt wird (Konzept, Abschnitt 13).
///
/// Grundmodell: **eine Hürde, nicht sieben.** Beim Öffnen wird einmal
/// authentifiziert, danach ist alles frei nutzbar.
enum LockMethod {
  /// Noch nichts eingerichtet – nur vor Abschluss des Onboardings gültig.
  none,

  /// Fingerabdruck oder Gesichtsscan, mit PIN als Rückfallebene.
  biometric,

  /// Nur PIN bzw. Passwort.
  pin,
}

/// Alle lokal gespeicherten Einstellungen.
///
/// Liegt ausschließlich auf dem Gerät und verlässt es nie.
class AppSettings {
  const AppSettings({
    this.onboardingCompleted = false,
    this.aiEnabled = false,
    this.tone = AiTone.locker,
    this.lockMethod = LockMethod.none,
    this.companionStyle = CompanionStyle.none,
  });

  /// Ob das Onboarding vollständig durchlaufen wurde.
  final bool onboardingCompleted;

  /// KI-Toggle aus dem Onboarding – Pflichtentscheidung des Users.
  ///
  /// Ist das `false`, läuft die App vollständig lokal.
  final bool aiEnabled;

  /// Tonfall, jederzeit in den Einstellungen änderbar.
  final AiTone tone;

  final LockMethod lockMethod;

  /// Einmalige Wahl der Anrufbegleitung. Wird gemerkt, damit die Frage nicht
  /// bei jedem Anruf neu kommt (Konzept, Abschnitt 8a).
  final CompanionStyle companionStyle;

  /// Ob die App beim Start gesperrt ist.
  bool get isLocked => lockMethod != LockMethod.none;

  AppSettings copyWith({
    bool? onboardingCompleted,
    bool? aiEnabled,
    AiTone? tone,
    LockMethod? lockMethod,
    CompanionStyle? companionStyle,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      tone: tone ?? this.tone,
      lockMethod: lockMethod ?? this.lockMethod,
      companionStyle: companionStyle ?? this.companionStyle,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.aiEnabled == aiEnabled &&
      other.tone == tone &&
      other.lockMethod == lockMethod &&
      other.companionStyle == companionStyle;

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    aiEnabled,
    tone,
    lockMethod,
    companionStyle,
  );
}
