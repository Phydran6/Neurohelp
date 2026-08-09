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

  /// Ob ein Backend hinterlegt ist. Ohne das läuft die App rein lokal.
  bool get hasBackend => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static AppConfig? _instance;

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

    _instance = AppConfig(
      flavor: Flavor.values.firstWhere(
        (f) => f.name == rawFlavor,
        orElse: () => Flavor.dev,
      ),
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseKey: supabaseKey,
    );
  }

  /// Nur für Tests.
  static void overrideForTesting(AppConfig config) => _instance = config;
}
