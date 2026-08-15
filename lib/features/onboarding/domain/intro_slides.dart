/// Die Texte der beiden Erklärbildschirme am Anfang des Onboardings.
///
/// Bewusst reine Daten ohne Flutter: Dadurch bleiben die Texte prüfbar, und
/// dieselbe Erklärung lässt sich später im Hilfe-Bereich noch einmal zeigen,
/// ohne sie ein zweites Mal zu tippen.
///
/// **Zwei Bildschirme, mehr nicht.** Der erste sagt, was die App kann, der
/// zweite, wie sie sich bedienen lässt. Wer mehr wissen will, findet es unter
/// „Hilfe & Info" – aber niemand muss sich durch ein Tutorial arbeiten,
/// bevor er anfangen darf.
library;

/// Ein einzelner Punkt auf einem Erklärbildschirm.
class IntroPoint {
  const IntroPoint({required this.id, required this.label, required this.text});

  /// Stabiler Schlüssel – die Oberfläche hängt daran ihr Symbol auf, und
  /// Tests hängen daran ihre Erwartung.
  final String id;

  /// Die fette Zeile: das Schlagwort.
  final String label;

  /// Der erklärende Satz darunter.
  final String text;
}

/// Ein Erklärbildschirm.
class IntroSlide {
  const IntroSlide({
    required this.id,
    required this.title,
    required this.lead,
    required this.points,
    required this.action,
  });

  final String id;

  final String title;

  /// Der ruhige Satz unter der Überschrift.
  final String lead;

  final List<IntroPoint> points;

  /// Beschriftung des Knopfes, der weiterführt.
  final String action;
}

/// Die feste Abfolge der Erklärbildschirme.
abstract final class IntroSlides {
  /// Was die App kann – die vier Features aus dem Hauptmenü.
  static const IntroSlide whatItDoes = IntroSlide(
    id: 'was',
    title: 'Das nimmt dir Neurohelp ab',
    lead:
        'Vier Sachen, an denen der Alltag am häufigsten hängen bleibt. Du '
        'sagst, was ansteht – durch den Rest gehen wir zusammen.',
    points: [
      IntroPoint(
        id: 'anruf',
        label: 'Anruf erledigen',
        text:
            'Vorher sammelst du in Ruhe, was du sagen willst. Während des '
            'Telefonats hast du deine Stichpunkte vor Augen.',
      ),
      IntroPoint(
        id: 'termin',
        label: 'Termin klären',
        text:
            'Von der Buchung bis zur Nachverfolgung. Du siehst jederzeit, was '
            'schon läuft und was noch offen ist.',
      ),
      IntroPoint(
        id: 'nachricht',
        label: 'Nachricht schreiben',
        text:
            'Erst der Inhalt, dann der Empfänger. Formulieren kannst du '
            'selbst – oder dir dabei helfen lassen.',
      ),
      IntroPoint(
        id: 'aufgabe',
        label: 'Aufgabe sortieren',
        text:
            'Große Aufgaben werden zu einzelnen Schritten. Im Fokus steht '
            'immer nur einer davon.',
      ),
    ],
    action: 'Weiter',
  );

  /// Wie die App funktioniert – die Bedienidee und die Grundregeln.
  static const IntroSlide howItWorks = IntroSlide(
    id: 'wie',
    title: 'So läuft das hier',
    lead:
        'Kein leeres Eingabefeld, das dich anstarrt. Du wählst aus, was '
        'ansteht, und wirst Schritt für Schritt durchgeführt.',
    points: [
      IntroPoint(
        id: 'schritte',
        label: 'Eine Frage nach der anderen',
        text:
            'Nie ein ganzes Formular auf einmal. Jeder Bildschirm will genau '
            'eine Sache von dir.',
      ),
      IntroPoint(
        id: 'historie',
        label: 'Erst nachsehen, dann fragen',
        text:
            'Jedes Feature schaut zuerst, was schon da ist. Du tippst nichts '
            'zweimal ein.',
      ),
      IntroPoint(
        id: 'lokal',
        label: 'Deine Sachen bleiben auf dem Gerät',
        text:
            'Vorgänge, Notizen und Kontakte verlassen dein Handy nicht. Nach '
            'draußen geht nur dein Konto – und KI-Texte, falls du die KI '
            'einschaltest.',
      ),
      IntroPoint(
        id: 'kein-druck',
        label: 'Kein Druck',
        text:
            'Keine Punkte, keine Serien, kein schlechtes Gewissen. Du machst '
            'das in deinem Tempo, und du kannst jederzeit aufhören.',
      ),
    ],
    action: 'Alles klar, los geht\'s',
  );

  /// Beide Bildschirme in ihrer Reihenfolge.
  static const List<IntroSlide> all = [whatItDoes, howItWorks];
}
