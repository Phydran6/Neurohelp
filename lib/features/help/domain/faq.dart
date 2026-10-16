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
      id: 'eigenes-ki-konto',
      question: 'Was bringt es, ein eigenes KI-Konto zu verbinden?',
      answer:
          'Bessere Antworten, und es ist kostenlos möglich. Du meldest dich '
          'einmal an – ein Tap, du musst nichts kopieren und nichts '
          'einrichten. Danach gehen die Texte, die die KI verarbeitet, '
          'direkt von deinem Gerät zum Anbieter, statt über unseren Server. '
          'Das Angebot steht in den Einstellungen unter „KI". Ohne das '
          'funktioniert alles genauso, nur eine Stufe einfacher.',
      keywords: ['ki', 'konto', 'openrouter', 'verbinden', 'besser'],
    ),
    FaqEntry(
      id: 'eigenes-ki-konto-daten',
      question: 'Was passiert mit meinen Texten beim eigenen KI-Konto?',
      answer:
          'Sie gehen direkt von deinem Gerät an OpenRouter und von dort an '
          'den Anbieter des Modells, das gerade antwortet. Bei kostenlosen '
          'Modellen darf mit diesen Texten häufig trainiert werden – bei '
          'Arzt- und Kassenthemen ist das einen Gedanken wert. Dein Zugang '
          'liegt verschlüsselt auf deinem Gerät und geht nie an uns. Über '
          '„Trennen" in den Einstellungen ist er sofort weg.',
      keywords: ['ki', 'datenschutz', 'openrouter', 'training', 'schlüssel'],
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
          'Melde dich mit deinem Konto neu an. Beim ersten Bildschirm gibt es '
          '„Passwort vergessen": Du bekommst einen sechsstelligen Code per '
          'Mail, setzt damit ein neues Passwort und kannst danach eine neue '
          'PIN vergeben.',
      keywords: ['pin', 'vergessen', 'passwort', 'wiederherstellung'],
    ),
    FaqEntry(
      id: 'bestaetigungs-code',
      question: 'Warum bekomme ich einen Code statt eines Links per Mail?',
      answer:
          'Weil ein Link in der Mail erst im Browser landet und von dort '
          'zurück in die App finden muss. Das geht oft schief. Ein '
          'sechsstelliger Code wird abgetippt und funktioniert überall. Er '
          'gilt eine Stunde; danach lässt du dir einfach einen neuen '
          'schicken.',
      keywords: ['code', 'mail', 'bestätigung', 'link', 'registrierung'],
    ),
    FaqEntry(
      id: 'schon-ein-konto',
      question: 'Ich habe die App neu installiert und schon ein Konto.',
      answer:
          'Beim allerersten Start fragt die App: „Warst du schon mal hier?" '
          'Sag ja, dann holt sie deine alten Sachen zurück – entweder von '
          'selbst oder aus einer Sicherungsdatei, die du heraussuchst. '
          'Danach meldest du dich mit E-Mail und Passwort an und richtest '
          'die App-Sperre neu ein.',
      keywords: ['anmelden', 'login', 'konto', 'neu', 'gerätewechsel'],
    ),
    FaqEntry(
      id: 'sicherung-was-ist-das',
      question: 'Was ist die Sicherung und muss ich mich darum kümmern?',
      answer:
          'Nein. Die App legt von selbst eine Sicherung an einem Platz ab, '
          'den dein Telefon in seine eigene Sicherung mitnimmt – nach iCloud '
          'oder zu Google. Installierst du die App neu oder ziehst auf ein '
          'neues Gerät um, fragt sie beim ersten Start, ob sie alles '
          'zurückholen soll.\n\n'
          'Das Ganze ist abschaltbar, und du kannst die Sicherung auch '
          'selbst als Datei irgendwohin legen. Beides steht in den '
          'Einstellungen unter „Sicherung".',
      keywords: ['backup', 'sicherung', 'umzug', 'neues handy', 'sichern'],
    ),
    FaqEntry(
      id: 'sicherung-was-drin',
      question: 'Was steht in der Sicherungsdatei – und was nicht?',
      answer:
          'Drin: deine Historie, alle Vorgänge (Anrufe, Termine, '
          'Nachrichten, Aufgaben) und deine Einstellungen.\n\n'
          'Nicht drin: deine PIN, deine Wiederherstellungs-Codes und deine '
          'KI-Zugänge. Die liegen im Schlüsselbund des Geräts. Eine Datei, '
          'die den Zugang zum Gerät gleich mitliefert, wäre das Gegenteil '
          'von Sicherheit. Die App-Sperre richtest du nach dem Einspielen '
          'deshalb neu ein.\n\n'
          'Die Datei ist gepackt, aber nicht verschlüsselt. Leg sie dorthin, '
          'wo du auch Kontoauszüge hinlegen würdest.',
      keywords: ['backup', 'sicherung', 'datei', 'pin', 'inhalt'],
    ),
    FaqEntry(
      id: 'sicherung-alte-version',
      question: 'Funktioniert eine alte Sicherung in einer neuen App?',
      answer:
          'Ja, und umgekehrt auch. In der Datei steht, welche Angaben es zum '
          'Zeitpunkt der Sicherung gab. Beim Einspielen nimmt die App alles, '
          'was sie kennt, lässt weg, was sie nicht kennt, und füllt Fehlendes '
          'mit ihren Vorgaben. Wenn dabei etwas nicht übernommen werden '
          'konnte, sagt sie es hinterher.',
      keywords: ['backup', 'sicherung', 'version', 'alt', 'update'],
    ),
    FaqEntry(
      id: 'sicherung-cloud',
      question: 'Kann ich die Sicherung in meine Cloud legen?',
      answer:
          'Ja. In den Einstellungen unter „Sicherung" gibt es „Datei '
          'erzeugen". Danach geht das Teilen-Blatt deines Telefons auf, und '
          'dort stehen alle Dienste, die du installiert hast – iCloud Drive, '
          'Google Drive, Dropbox, oder eine Mail an dich selbst. Die App '
          'selbst kennt keinen dieser Dienste und schickt nichts von allein '
          'irgendwohin. Du entscheidest.',
      keywords: ['cloud', 'icloud', 'google drive', 'dropbox', 'sicherung'],
    ),
    FaqEntry(
      id: 'einstellungen-zwei-wege',
      question: 'Warum fragen die Einstellungen, ob ich weiß, was ich tue?',
      answer:
          'Weil dieselbe Liste für zwei sehr verschiedene Leute gedacht ist. '
          'Wer mit API-Schlüsseln und Dateipfaden umgehen kann, soll sie '
          'bekommen. Wer nicht, soll nicht daran vorbeimüssen.\n\n'
          'Beide Wege können dasselbe. Der Unterschied ist nur, wie viel '
          'dabei erklärt wird. Umschalten kannst du jederzeit – oben rechts '
          'in den Einstellungen.',
      keywords: ['einstellungen', 'experte', 'einfach', 'modus'],
    ),
    FaqEntry(
      id: 'eigener-ki-server',
      question: 'Kann ich meine eigene KI benutzen – OpenWebUI, Ollama?',
      answer:
          'Ja. In den Einstellungen unter „Ich weiß, was ich tue" gibt es '
          '„Eigenen KI-Server eintragen". Du gibst Adresse, Modell und – '
          'falls nötig – einen Schlüssel an; die App probiert es einmal aus, '
          'bevor sie es speichert.\n\n'
          'Unterstützt wird alles, was die OpenAI-Schnittstelle spricht '
          '(OpenWebUI, Ollama, LM Studio, OpenAI selbst) sowie Anthropic. '
          'Die Anfragen gehen dann direkt von deinem Gerät dorthin.\n\n'
          'Wichtig: Ein ChatGPT-Plus- oder Claude-Abo ist nicht dasselbe wie '
          'ein Schlüssel für die Schnittstelle. Die werden getrennt '
          'abgerechnet.',
      keywords: [
        'ollama',
        'openwebui',
        'openai',
        'anthropic',
        'claude',
        'chatgpt',
        'eigener server',
      ],
    ),
    FaqEntry(
      id: 'hell-dunkel',
      question: 'Kann ich die App dauerhaft dunkel stellen?',
      answer:
          'Ja, in den Einstellungen unter „Darstellung" bzw. „Hell oder '
          'dunkel?". Standard ist, was dein Gerät gerade macht; du kannst '
          'aber fest hell oder fest dunkel wählen, ohne dafür das ganze '
          'Gerät umzustellen.',
      keywords: ['dunkel', 'dark mode', 'hell', 'theme', 'darstellung'],
    ),
    FaqEntry(
      id: 'weitermachen',
      question: 'Wie mache ich an etwas weiter, das ich angefangen habe?',
      answer:
          'In der Historie. Neben jedem offenen Vorgang steht ein '
          'Abspiel-Pfeil – der bringt dich direkt dorthin zurück, wo du '
          'aufgehört hast, nicht nur ins Protokoll.\n\n'
          'Dasselbe gilt am Anfang jedes Ablaufs: Findet die App beim '
          'Nachschauen etwas Offenes, steht dort „Daran weitermachen". '
          'Antippen des Eintrags legt stattdessen etwas Neues mit demselben '
          'Thema an – beides geht, du entscheidest.',
      keywords: [
        'weitermachen',
        'fortsetzen',
        'historie',
        'angefangen',
        'offen',
      ],
    ),
    FaqEntry(
      id: 'zwei-faktor',
      question: 'Was ist die Zwei-Faktor-Anmeldung und muss ich die haben?',
      answer:
          'Nein, sie ist freiwillig. Sie verlangt beim Anmelden zusätzlich '
          'einen Code aus einer Authenticator-App. Du kannst sie im '
          'Onboarding überspringen und jederzeit in den Einstellungen '
          'nachholen – oder wieder entfernen.',
      keywords: ['2fa', 'mfa', 'zwei-faktor', 'authenticator', 'totp'],
    ),
    FaqEntry(
      id: 'biometrie-abschalten',
      question: 'Kann ich Fingerabdruck oder Gesicht wieder abschalten?',
      answer:
          'Ja. In den Einstellungen unter „App-Sperre" gibt es dafür einen '
          'Schalter. Danach wird beim Öffnen nur noch die PIN gefragt. Die '
          'PIN änderst du an derselben Stelle.',
      keywords: ['biometrie', 'fingerabdruck', 'gesicht', 'abschalten', 'pin'],
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
          'Ein Weg, ein Tipp: In den Einstellungen unter „Konto löschen". '
          'Erst verschwindet alles, was serverseitig zu dir gehört – du '
          'bekommst darüber eine Mail. Klappt das, räumt die App direkt '
          'danach dieses Gerät leer: Vorgänge, Historie, Einstellungen, PIN. '
          'Danach bist du abgemeldet und die App fängt wieder von vorn an. '
          'Was schon aus der App heraus ist – eine übergebene Mail, ein '
          'Termin im Kalender oder eine Sicherungsdatei, die du selbst '
          'woanders abgelegt hast – bleibt, wo es ist.',
      keywords: ['löschen', 'deinstallieren', 'konto'],
    ),
    FaqEntry(
      id: 'nichts-geht',
      question: 'Es geht gar nichts mehr. Was kann ich tun?',
      answer:
          'Schreib mir. Im Hilfe-Bereich steht unter den häufigen Fragen '
          '„Deine Frage steht nicht dabei?" – dort gibt es zwei Wege: eine '
          'Mail direkt an mich oder ein Ticket auf GitHub. Die Mail ist '
          'schon vorausgefüllt, inklusive deiner Version; du musst nur noch '
          'hinschreiben, was passiert ist.\n\n'
          'Beides landet bei derselben Person. Nimm den Weg, der dir '
          'leichter fällt.',
      keywords: ['hilfe', 'kaputt', 'fehler', 'melden', 'mail', 'kontakt'],
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
