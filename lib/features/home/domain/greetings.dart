/// Die wechselnden Sprüche auf der Startseite (Konzept, Abschnitt 6).
///
/// Ton: locker, kumpelhaft – wie ein Freund bei WhatsApp. Was hier **nicht**
/// steht: Motivationssprüche, Aufforderungen, Fragen nach dem Befinden und
/// alles, was nach Leistung klingt. Der Spruch begrüßt, er fordert nicht.
abstract final class Greetings {
  static const List<String> lines = [
    'Hey, schön dass du da bist. Was steht an?',
    'Hi. Womit fangen wir an?',
    'Da bist du ja. Was liegt an?',
    'Moin. Was können wir zusammen wegräumen?',
    'Hey. Sag einfach, worum es geht.',
    'Schön, dass du vorbeischaust. Was ist dran?',
    'Hi. Eins nach dem anderen – womit los?',
  ];

  /// Wählt einen Spruch anhand von [seed].
  ///
  /// Bewusst nicht zufällig, sondern ableitbar: Beim selben Öffnen bleibt der
  /// Spruch stehen und wechselt nicht mitten im Blick. Üblicherweise wird der
  /// Tag als Seed genutzt.
  static String forSeed(int seed) => lines[seed.abs() % lines.length];

  /// Der Spruch für einen Tag. Wechselt täglich, nicht bei jedem Tippen.
  static String forDate(DateTime date) =>
      forSeed(date.year * 372 + date.month * 31 + date.day);
}
