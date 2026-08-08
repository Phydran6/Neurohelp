/// Ergebnis eines Entsperrversuchs.
enum UnlockResult {
  /// Entsperrt – ab hier ist alles frei nutzbar.
  success,

  /// Falsche PIN bzw. Biometrie nicht erkannt. Erneut versuchbar.
  failed,

  /// Der User hat abgebrochen.
  cancelled,

  /// Biometrie ist auf diesem Gerät nicht verfügbar oder nicht eingerichtet.
  /// Der Aufrufer fällt auf die PIN zurück.
  unavailable,
}

/// Die App-Sperre beim Start (Konzept, Abschnitt 13).
///
/// **Eine Hürde, nicht sieben:** Es wird einmal beim Öffnen authentifiziert.
/// Diese Schnittstelle kennt keine Plattform – Android BiometricPrompt und
/// iOS LocalAuthentication liegen in der jeweiligen Implementierung.
abstract interface class AppLock {
  /// Ob das Gerät Biometrie anbietet und der User sie eingerichtet hat.
  Future<bool> get isBiometricAvailable;

  /// Fragt die Biometrie ab.
  ///
  /// Liefert [UnlockResult.unavailable], wenn keine Biometrie nutzbar ist –
  /// dann greift die PIN-Rückfallebene.
  Future<UnlockResult> unlockWithBiometrics();

  /// Prüft eine eingegebene PIN gegen die hinterlegte.
  Future<UnlockResult> unlockWithPin(String pin);

  /// Legt eine PIN an oder ersetzt sie.
  Future<void> setPin(String pin);

  /// Entfernt die PIN. Nur zulässig, wenn die App-Sperre abgeschaltet wird.
  Future<void> clearPin();

  /// Ob überhaupt eine PIN hinterlegt ist.
  Future<bool> get hasPin;
}
