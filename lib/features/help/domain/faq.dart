/// Eine feste Frage-Antwort-Paarung.
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.question,
    required this.answer,
    this.keywords = const [],
  });

  final String id;
  final String question;
  final String answer;

  /// Zusätzliche Wörter, unter denen dieser Eintrag gefunden werden soll.
  final List<String> keywords;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return false;

    if (question.toLowerCase().contains(needle)) return true;
    if (answer.toLowerCase().contains(needle)) return true;
    return keywords.any((word) => word.toLowerCase().contains(needle));
  }
}

/// Die festen FAQ-Antworten.
///
/// Konzept, Abschnitt 15: **ohne KI feste Antworten**, mit KI zusätzlich frei
/// fragbar. Der Katalog ist damit der Weg ohne KI – er muss für sich allein
/// tragen und darf keine Lücke lassen, die nur die KI füllen kann.
abstract final class FaqCatalog {
  static const List<FaqEntry> entries = [
    FaqEntry(
      id: 'was-ist-neurohelp',
      question: 'Was ist Neurohelp?',
      answer:
          'Eine App, die dir im Alltag hilft: beim Telefonieren, beim '
          'Schreiben, beim Sortieren von Aufgaben und beim Klären von '
          'Terminen. Sie nimmt dir nichts weg, sondern hilft dir, es '
          'selbst zu schaffen.',
      keywords: ['app', 'zweck', 'wofür'],
    ),
    FaqEntry(
      id: 'wo-liegen-meine-daten',
      question: 'Wo liegen meine Daten?',
      answer:
          'Auf deinem Gerät. Deine Historie, Notizen, Kontakte, Termine und '
          'Aufgaben verlassen es nicht. Über das Internet laufen nur drei '
          'Dinge: dein Konto, Passwort-Reset-Mails und – falls du KI '
          'eingeschaltet hast – die Texte, die die KI verarbeiten soll.',
      keywords: ['datenschutz', 'daten', 'privat', 'cloud', 'server'],
    ),
    FaqEntry(
      id: 'ohne-ki',
      question: 'Kann ich die App ohne KI benutzen?',
      answer:
          'Ja. Du entscheidest das beim ersten Start und kannst es jederzeit '
          'in den Einstellungen ändern. Ohne KI läuft alles auf deinem '
          'Gerät. Es fällt weg, dass die App Texte für dich formuliert oder '
          'Aufgaben selbst zerlegt – alles andere bleibt.',
      keywords: ['ki', 'ai', 'abschalten', 'ausschalten'],
    ),
    FaqEntry(
      id: 'ki-wieder-abschalten',
      question: 'Wie schalte ich die KI wieder ab?',
      answer:
          'Einstellungen öffnen und den KI-Schalter umlegen. Ab dann geht '
          'kein Text mehr nach draußen.',
      keywords: ['ki', 'einstellungen', 'abschalten'],
    ),
    FaqEntry(
      id: 'app-sperre',
      question: 'Warum fragt die App beim Öffnen nach Fingerabdruck oder PIN?',
      answer:
          'Damit niemand anders deine Vorgänge sieht. Es wird einmal beim '
          'Öffnen gefragt – danach ist alles frei nutzbar. Eine Hürde, '
          'nicht sieben.',
      keywords: ['pin', 'biometrie', 'fingerabdruck', 'sperre', 'passwort'],
    ),
    FaqEntry(
      id: 'pin-vergessen',
      question: 'Ich habe meine PIN vergessen. Was jetzt?',
      answer:
          'Melde dich mit deinem Konto neu an. Über „Passwort vergessen" '
          'bekommst du eine Mail und kannst danach eine neue PIN setzen. '
          'Falls du beim Einrichten einen Wiederherstellungs-Code '
          'gespeichert hast, geht es auch damit.',
      keywords: ['pin', 'vergessen', 'passwort', 'wiederherstellung'],
    ),
    FaqEntry(
      id: 'nachricht-wirklich-gesendet',
      question: 'Woher weiß die App, ob meine Mail rausging?',
      answer:
          'Gar nicht. Sobald deine Mail-App übernimmt, sieht Neurohelp '
          'nichts mehr. Deshalb fragt sie später einmal nach, ob es '
          'geklappt hat – höchstens dreimal, dann ist Ruhe.',
      keywords: ['mail', 'nachricht', 'gesendet', 'nachfrage'],
    ),
    FaqEntry(
      id: 'abgehakt-rueckgaengig',
      question: 'Kann ich einen abgehakten Schritt wieder aufmachen?',
      answer:
          'Nein. Abgehakt heißt erledigt. Wenn doch noch etwas offen ist, '
          'leg einen neuen Schritt an – das ist ehrlicher, als einen alten '
          'wieder aufzumachen.',
      keywords: ['abhaken', 'rückgängig', 'aufgabe', 'schritt'],
    ),
    FaqEntry(
      id: 'anrufbegleitung-ios',
      question: 'Warum sieht die Anrufbegleitung auf iPhone anders aus?',
      answer:
          'Apple erlaubt keine Fenster über anderen Apps. Auf dem iPhone '
          'stehen deine Stichpunkte deshalb auf dem Sperrbildschirm – '
          'einmal hinwischen während des Telefonats. Notizen tippst du dort '
          'nach dem Anruf. Auf Android geht ein kleines Fenster über dem '
          'Gespräch.',
      keywords: ['ios', 'iphone', 'android', 'overlay', 'begleitung'],
    ),
    FaqEntry(
      id: 'daten-loeschen',
      question: 'Wie werde ich alles wieder los?',
      answer:
          'App deinstallieren – die Daten liegen auf deinem Gerät und gehen '
          'damit mit. Dein Konto löschst du in den Einstellungen.',
      keywords: ['löschen', 'deinstallieren', 'konto'],
    ),
  ];

  /// Einträge, die zu [query] passen. Leere Eingabe liefert alles.
  static List<FaqEntry> search(String query) {
    if (query.trim().isEmpty) return entries;
    return entries.where((entry) => entry.matches(query)).toList();
  }

  static FaqEntry? byId(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}
