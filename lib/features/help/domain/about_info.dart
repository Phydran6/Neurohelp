/// Eine verwendete Fremdbibliothek und ihre Lizenz.
class ThirdPartyLicense {
  const ThirdPartyLicense({required this.name, required this.license});

  final String name;
  final String license;
}

/// Ein Verweis nach draußen – Quelltext, Dokumentation, Lizenz.
class AboutLink {
  const AboutLink({
    required this.id,
    required this.label,
    required this.hint,
    required this.url,
  });

  final String id;
  final String label;

  /// Was den User dort erwartet. Ein nackter Link erklärt nichts.
  final String hint;

  final String url;
}

/// Was unter „Über die App" steht (Konzept, Abschnitt 15).
class AboutInfo {
  const AboutInfo({required this.version, required this.buildNumber});

  /// Kommt aus dem Build, nicht aus dem Quelltext.
  final String version;
  final String buildNumber;

  static const String appName = 'Neurohelp';

  static const String purpose =
      'Neurohelp hilft dir im Alltag – beim Telefonieren, beim Schreiben, '
      'beim Sortieren von Aufgaben und beim Klären von Terminen.';

  static const String origin =
      'Entstanden, weil Alltagskram für manche Menschen unverhältnismäßig '
      'schwer ist und die vorhandenen Werkzeuge davon nichts wissen.';

  static const String developer = 'Philipp Fischer';

  static const String repository = 'https://github.com/Phydran6/Neurohelp';

  static const String license = 'MIT';

  /// Hinweis zur Datenhaltung – gehört sichtbar in den Info-Bereich und
  /// nicht nur in eine Datenschutzerklärung.
  static const String dataNotice =
      'Deine Daten bleiben auf deinem Gerät. Über das Internet laufen nur '
      'dein Konto, Passwort-Reset-Mails und – wenn du KI eingeschaltet hast '
      '– die Texte, die die KI verarbeiten soll.';

  /// Alles, was nachvollziehbar sein soll, liegt öffentlich im Repository.
  /// Die App verlinkt bewusst dorthin, statt Texte doppelt zu pflegen.
  static const List<AboutLink> links = [
    AboutLink(
      id: 'repository',
      label: 'Quelltext auf GitHub',
      hint: 'Der komplette Code der App, öffentlich einsehbar.',
      url: repository,
    ),
    AboutLink(
      id: 'konzept',
      label: 'Konzept',
      hint: 'Was die App tut, was sie bewusst nicht tut – und warum.',
      url: '$repository/blob/main/docs/KONZEPT.md',
    ),
    AboutLink(
      id: 'datenschutz',
      label: 'Datenschutz',
      hint: 'Welche Daten wo liegen, im Klartext.',
      url: '$repository/blob/main/docs/DATENSCHUTZ.md',
    ),
    AboutLink(
      id: 'changelog',
      label: 'Was sich geändert hat',
      hint: 'Alle Änderungen, Version für Version.',
      url: '$repository/blob/main/CHANGELOG.md',
    ),
    AboutLink(
      id: 'lizenz',
      label: 'Lizenz (MIT)',
      hint: 'Der volle Lizenztext.',
      url: '$repository/blob/main/LICENSE',
    ),
    AboutLink(
      id: 'issues',
      label: 'Fehler melden',
      hint: 'Was klemmt, kommt hierhin – auch anonym lesbar.',
      url: '$repository/issues',
    ),
  ];

  static const List<ThirdPartyLicense> thirdParty = [
    ThirdPartyLicense(name: 'Flutter', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'sqflite', license: 'BSD-2-Clause'),
    ThirdPartyLicense(name: 'crypto', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'uuid', license: 'MIT'),
    ThirdPartyLicense(name: 'path', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'path_provider', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'supabase_flutter', license: 'MIT'),
    ThirdPartyLicense(name: 'local_auth', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'flutter_secure_storage', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'url_launcher', license: 'BSD-3-Clause'),
  ];

  String get versionLabel => '$version ($buildNumber)';
}
