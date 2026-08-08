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
  });

  final Flavor flavor;
  final String apiBaseUrl;

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

    _instance = AppConfig(
      flavor: Flavor.values.firstWhere(
        (f) => f.name == rawFlavor,
        orElse: () => Flavor.dev,
      ),
      apiBaseUrl: apiBaseUrl,
    );
  }

  /// Nur für Tests.
  static void overrideForTesting(AppConfig config) => _instance = config;
}
