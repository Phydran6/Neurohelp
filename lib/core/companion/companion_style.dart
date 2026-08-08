/// Wie die Begleitung während eines Telefonats oder einer Online-Buchung
/// dargestellt wird (Konzept, Abschnitt 8a).
///
/// Liegt in `core`, weil sowohl das Anruf- als auch das Termin-Feature davon
/// abhängen und die Auswahl in den Einstellungen liegt.
///
/// Auf Android wählt der User **einmalig**, die Auswahl wird gemerkt. Auf
/// iOS gibt es keine Wahl: Apple erlaubt kein Overlay über anderen Apps, der
/// offiziell vorgesehene Weg ist die Live Activity.
enum CompanionStyle {
  /// Noch nicht gewählt.
  none,

  /// Android: kleines Fenster über dem Anruf.
  overlay,

  /// Android: geteilter Bildschirm.
  splitScreen,

  /// iOS: Sperrbildschirm und Dynamic Island.
  liveActivity,
}
