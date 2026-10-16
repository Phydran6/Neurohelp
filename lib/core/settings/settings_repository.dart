import '../ai/ai_client.dart';
import '../companion/companion_style.dart';
import 'app_settings.dart';

/// Zugriff auf die lokal gespeicherten Einstellungen.
abstract interface class SettingsRepository {
  /// Liest den aktuellen Stand. Fehlende Werte fallen auf die Standards
  /// aus [AppSettings] zurück.
  Future<AppSettings> load();

  Future<AppSettings> setOnboardingCompleted({required bool completed});

  /// Setzt den KI-Toggle. `false` heißt: die App läuft vollständig lokal.
  Future<AppSettings> setAiEnabled({required bool enabled});

  Future<AppSettings> setTone(AiTone tone);

  Future<AppSettings> setLockMethod(LockMethod method);

  /// Merkt sich die einmalige Wahl der Anrufbegleitung.
  Future<AppSettings> setCompanionStyle(CompanionStyle style);

  /// Merkt sich, dass der Hinweis auf die Zwei-Faktor-Anmeldung zu sehen war.
  /// Er kommt danach nicht wieder.
  Future<AppSettings> setMfaHintShown({required bool shown});

  /// Hell, dunkel oder wie das Gerät.
  Future<AppSettings> setThemeChoice(AppThemeChoice choice);

  /// Merkt sich, welcher Weg durch die Einstellungen gewählt wurde.
  Future<AppSettings> setSettingsMode(SettingsMode mode);

  /// Schaltet die Sicherung am Standardplatz an oder aus.
  Future<AppSettings> setAutoBackup({required bool enabled});

  /// Hält fest, wann zuletzt gesichert wurde.
  Future<AppSettings> setLastBackupAt(DateTime moment);

  /// Merkt sich, dass beim Start nach einer alten Sicherung gefragt wurde.
  Future<AppSettings> setRestoreOffered({required bool offered});
}
