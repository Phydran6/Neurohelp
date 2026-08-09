/// Eine verwendete Fremdbibliothek und ihre Lizenz.
class ThirdPartyLicense {
  const ThirdPartyLicense({required this.name, required this.license});

  final String name;
  final String license;
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

  static const List<ThirdPartyLicense> thirdParty = [
    ThirdPartyLicense(name: 'Flutter', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'sqflite', license: 'BSD-2-Clause'),
    ThirdPartyLicense(name: 'crypto', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'uuid', license: 'MIT'),
    ThirdPartyLicense(name: 'path', license: 'BSD-3-Clause'),
    ThirdPartyLicense(name: 'path_provider', license: 'BSD-3-Clause'),
  ];

  String get versionLabel => '$version ($buildNumber)';
}
