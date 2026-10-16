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

/// Hell, dunkel oder wie das Gerät.
///
/// Bis hierher richtete sich die App immer nach dem System. Das ist als
/// Vorgabe richtig und als einzige Möglichkeit falsch: Wer bei Reizempfind-
/// lichkeit dauerhaft dunkel braucht, soll das einstellen können, ohne das
/// ganze Gerät umzustellen.
enum AppThemeChoice { system, light, dark }

/// Welcher Weg durch die Einstellungen gewählt wurde.
///
/// Der Kern des Umbaus (Konzept, Abschnitt 4 – DAU-Prinzip): Dieselben
/// Einstellungen in zwei Sprachen. Wer weiß, was er tut, bekommt alle
/// Schalter. Wer nicht, bekommt Entscheidungen statt Schalter – und nichts,
/// was man kaputtmachen kann.
enum SettingsMode {
  /// Noch nicht gefragt. Beim Öffnen kommt die Auswahl.
  unset,

  /// „Ich hab keinen Plan." Wenige, große Entscheidungen.
  guided,

  /// „Ich weiß, was ich tue." Alles selbst.
  expert,
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
    this.mfaHintShown = false,
    this.themeChoice = AppThemeChoice.system,
    this.settingsMode = SettingsMode.unset,
    this.autoBackup = true,
    this.lastBackupAt,
    this.restoreOffered = false,
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

  /// Ob der Hinweis auf die noch fehlende Zwei-Faktor-Anmeldung schon einmal
  /// zu sehen war.
  ///
  /// Er kommt **genau einmal** – danach nie wieder. Ein Hinweis, der bei
  /// jedem Start erneut aufpoppt, ist Druck (Konzept, Abschnitt 4).
  final bool mfaHintShown;

  final AppThemeChoice themeChoice;

  /// Welcher Einstellungs-Weg gewählt wurde. Jederzeit umschaltbar.
  final SettingsMode settingsMode;

  /// Ob die App von selbst eine Sicherung am Standardplatz anlegt.
  ///
  /// Standardmäßig an. Eine Sicherung, die nur auf Zuruf entsteht, gibt es
  /// bei denen nie, die sie am nötigsten brauchen.
  final bool autoBackup;

  /// Wann zuletzt gesichert wurde – egal auf welchem Weg.
  final DateTime? lastBackupAt;

  /// Ob beim ersten Start schon einmal nach einer alten Sicherung gefragt
  /// wurde. Die Frage kommt genau einmal.
  final bool restoreOffered;

  /// Ob die App beim Start gesperrt ist.
  bool get isLocked => lockMethod != LockMethod.none;

  /// Ob beim Entsperren zuerst Fingerabdruck bzw. Gesicht versucht wird.
  bool get usesBiometrics => lockMethod == LockMethod.biometric;

  AppSettings copyWith({
    bool? onboardingCompleted,
    bool? aiEnabled,
    AiTone? tone,
    LockMethod? lockMethod,
    CompanionStyle? companionStyle,
    bool? mfaHintShown,
    AppThemeChoice? themeChoice,
    SettingsMode? settingsMode,
    bool? autoBackup,
    DateTime? lastBackupAt,
    bool? restoreOffered,
  }) {
    return AppSettings(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      tone: tone ?? this.tone,
      lockMethod: lockMethod ?? this.lockMethod,
      companionStyle: companionStyle ?? this.companionStyle,
      mfaHintShown: mfaHintShown ?? this.mfaHintShown,
      themeChoice: themeChoice ?? this.themeChoice,
      settingsMode: settingsMode ?? this.settingsMode,
      autoBackup: autoBackup ?? this.autoBackup,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      restoreOffered: restoreOffered ?? this.restoreOffered,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.onboardingCompleted == onboardingCompleted &&
      other.aiEnabled == aiEnabled &&
      other.tone == tone &&
      other.lockMethod == lockMethod &&
      other.companionStyle == companionStyle &&
      other.mfaHintShown == mfaHintShown &&
      other.themeChoice == themeChoice &&
      other.settingsMode == settingsMode &&
      other.autoBackup == autoBackup &&
      other.lastBackupAt == lastBackupAt &&
      other.restoreOffered == restoreOffered;

  @override
  int get hashCode => Object.hash(
    onboardingCompleted,
    aiEnabled,
    tone,
    lockMethod,
    companionStyle,
    mfaHintShown,
    themeChoice,
    settingsMode,
    autoBackup,
    lastBackupAt,
    restoreOffered,
  );
}
