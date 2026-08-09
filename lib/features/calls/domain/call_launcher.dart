/// Startet ein Telefonat über die Telefon-App des Geräts.
///
/// Konzept, Abschnitt 17: Android Intent, iOS URL-Scheme. Dart sieht nur
/// diese Schnittstelle.
abstract interface class CallLauncher {
  /// Öffnet die Telefon-App mit der Nummer.
  ///
  /// Liefert `false`, wenn das nicht geht – dann bleibt die Nummer auf dem
  /// Bildschirm stehen und kann von Hand gewählt werden. Keine Sackgasse.
  Future<bool> dial(String number);
}

/// Ersatz für Tests und Geräte ohne Telefonfunktion.
class NoCallLauncher implements CallLauncher {
  const NoCallLauncher();

  @override
  Future<bool> dial(String number) async => false;
}
