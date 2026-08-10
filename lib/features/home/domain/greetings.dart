import '../../../core/ai/ai_client.dart';

/// Die wechselnden Sprüche auf der Startseite (Konzept, Abschnitt 6).
///
/// Ton: locker, kumpelhaft – wie ein Freund bei WhatsApp. Was hier **nicht**
/// steht: Motivationssprüche, Aufforderungen, Fragen nach dem Befinden und
/// alles, was nach Leistung klingt. Der Spruch begrüßt, er fordert nicht.
///
/// Der im Onboarding gewählte Ton entscheidet, aus welchem Satz gezogen wird.
/// Die Frage „Wie soll ich mit dir reden?" muss sich auch danach anfühlen –
/// sonst ist sie nur eine Umfrage ohne Folgen.
abstract final class Greetings {
  /// Locker – die Voreinstellung.
  static const List<String> lines = [
    'Hey, schön dass du da bist. Was steht an?',
    'Hi. Womit fangen wir an?',
    'Da bist du ja. Was liegt an?',
    'Moin. Was können wir zusammen wegräumen?',
    'Hey. Sag einfach, worum es geht.',
    'Schön, dass du vorbeischaust. Was ist dran?',
    'Hi. Eins nach dem anderen – womit los?',
  ];

  static const List<String> _neutral = [
    'Hallo. Womit kann ich helfen?',
    'Guten Tag. Was steht an?',
    'Hallo. Woran arbeiten wir?',
    'Schön, dass du da bist. Was ist zu tun?',
    'Hallo. Was möchtest du angehen?',
    'Guten Tag. Womit fangen wir an?',
    'Hallo. Eins nach dem anderen – was zuerst?',
  ];

  static const List<String> _sachlich = [
    'Auswahl treffen.',
    'Bereit.',
    'Was ist zu tun?',
    'Nächster Vorgang.',
    'Womit weiter?',
    'Offen: siehe Auswahl.',
    'Los.',
  ];

  static List<String> linesFor(AiTone tone) => switch (tone) {
    AiTone.locker => lines,
    AiTone.neutral => _neutral,
    AiTone.sachlich => _sachlich,
  };

  /// Wählt einen Spruch anhand von [seed].
  ///
  /// Bewusst nicht zufällig, sondern ableitbar: Beim selben Öffnen bleibt der
  /// Spruch stehen und wechselt nicht mitten im Blick. Üblicherweise wird der
  /// Tag als Seed genutzt.
  static String forSeed(int seed, {AiTone tone = AiTone.locker}) {
    final catalog = linesFor(tone);
    return catalog[seed.abs() % catalog.length];
  }

  /// Der Spruch für einen Tag. Wechselt täglich, nicht bei jedem Tippen.
  static String forDate(DateTime date, {AiTone tone = AiTone.locker}) =>
      forSeed(date.year * 372 + date.month * 31 + date.day, tone: tone);
}
