/// Build-Flavor der App. Wird per `--dart-define=FLAVOR=...` gesetzt.
enum Flavor { dev, staging, prod }

/// Zentrale, zur Build-Zeit befüllte Konfiguration.
///
/// Beispiel:
/// `flutter run --dart-define=FLAVOR=dev --dart-define=API_BASE_URL=https://...`
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.openRouterSharedKey = '',
    this.supportEmail = '',
  });

  final Flavor flavor;
  final String apiBaseUrl;

  /// Adresse des Supabase-Projekts.
  final String supabaseUrl;

  /// Der öffentliche Schlüssel (`sb_publishable_…`).
  ///
  /// Kein Geheimnis: Er steckt in jeder ausgelieferten App und lässt sich
  /// dort auslesen. Geschützt wird über Row Level Security, nicht über
  /// diesen Wert. Der geheime Schlüssel bleibt ausschließlich im Backend.
  final String supabaseKey;

  /// Ein von uns bezahlter OpenRouter-Schlüssel, den die App allen anbietet,
  /// die weder zahlen noch etwas einrichten wollen (Konzept, Abschnitt 17a,
  /// Stufe 1a).
  ///
  /// **Kommt nie ins Repository.** Der Vorgabewert ist leer; gesetzt wird er
  /// beim Bauen mit `--dart-define=OPENROUTER_SHARED_KEY=sk-or-...` aus einem
  /// GitHub-Secret. Ohne ihn fehlt diese Stufe einfach – die App sagt das und
  /// bietet stattdessen den eigenen Zugang an.
  ///
  /// Ehrlich bleiben muss man trotzdem: Ein ausgelieferter Schlüssel lässt
  /// sich aus jeder App herausholen. Deshalb gehört dort ein Limit drauf, und
  /// deshalb steht in der Oberfläche, dass die Anfragen über ein gemeinsames
  /// Konto laufen.
  final String openRouterSharedKey;

  /// Adresse für "schreib mir direkt", wenn etwas nicht geht.
  ///
  /// Wer mit GitHub umgehen kann, meldet dort; alle anderen brauchen eine
  /// Mail-Adresse. Leer heißt: Die App bietet nur den GitHub-Weg an.
  final String supportEmail;

  /// Ob ein Backend hinterlegt ist. Ohne das läuft die App rein lokal.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Ob der fertige KI-Zugang angeboten werden kann.
  bool get hasSharedAiKey => openRouterSharedKey.isNotEmpty;

  static AppConfig? _instance;

  /// Die Konfiguration, falls es schon eine gibt.
  ///
  /// Für die Oberfläche: Ein Widget-Test baut einzelne Seiten ohne `main()`,
  /// und dort ist nichts eingelesen. Ein Bildschirm, der wegen einer
  /// fehlenden Build-Einstellung abstürzt, ist die falsche Strenge – er lässt
  /// die betroffene Zeile einfach weg. Wo die Konfiguration wirklich
  /// gebraucht wird, steht weiterhin [instance] und knallt.
  static AppConfig? get instanceOrNull => _instance;

  static AppConfig get instance {
    final config = _instance;
    if (config == null) {
      throw StateError(
        'AppConfig.initFromEnvironment() wurde nicht aufgerufen.',
      );
    }
    return config;
  }

  bool get isProduction => flavor == Flavor.prod;

  static void initFromEnvironment() {
    const rawFlavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

    // Die Vorgabewerte sind das produktive Projekt. Beides darf im Repository
    // stehen; per `--dart-define` lässt sich auf ein anderes Projekt zeigen.
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://skbhhsxhnygyjavtjmib.supabase.co',
    );
    const supabaseKey = String.fromEnvironment(
      'SUPABASE_KEY',
      defaultValue: 'sb_publishable_ez-w3GVAlDJ4KEyR-R2ccA_TBzZxZJd',
    );

    // Ohne Vorgabewert, und das bleibt so: Ein echter OpenRouter-Schlüssel
    // ist ein Geheimnis und gehört nicht ins Repository (CLAUDE.md). Die CI
    // reicht ihn aus einem GitHub-Secret durch.
    const openRouterSharedKey = String.fromEnvironment('OPENROUTER_SHARED_KEY');

    // Die Adresse für „schreib mir direkt". Kein Geheimnis – sie steht
    // ohnehin im Store-Eintrag und soll auch ohne dart-define funktionieren.
    const supportEmail = String.fromEnvironment(
      'SUPPORT_EMAIL',
      defaultValue: 'it@phytech.de',
    );

    _instance = AppConfig(
      flavor: Flavor.values.firstWhere(
        (f) => f.name == rawFlavor,
        orElse: () => Flavor.dev,
      ),
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseKey: supabaseKey,
      openRouterSharedKey: openRouterSharedKey,
      supportEmail: supportEmail,
    );
  }

  /// Nur für Tests.
  static void overrideForTesting(AppConfig config) => _instance = config;
}
