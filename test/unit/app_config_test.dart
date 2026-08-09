import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('fällt ohne FLAVOR-Define auf dev zurück', () {
      AppConfig.initFromEnvironment();

      expect(AppConfig.instance.flavor, Flavor.dev);
      expect(AppConfig.instance.isProduction, isFalse);
    });

    test('overrideForTesting setzt die Instanz', () {
      AppConfig.overrideForTesting(
        const AppConfig(
          flavor: Flavor.prod,
          apiBaseUrl: 'https://example.test',
        ),
      );

      expect(AppConfig.instance.isProduction, isTrue);
      expect(AppConfig.instance.apiBaseUrl, 'https://example.test');
    });

    test('das Backend ist voreingestellt', () {
      AppConfig.initFromEnvironment();

      expect(AppConfig.instance.hasBackend, isTrue);
      expect(AppConfig.instance.supabaseUrl, startsWith('https://'));

      // Der öffentliche Schlüssel darf hier stehen, der geheime nie.
      expect(AppConfig.instance.supabaseKey, startsWith('sb_publishable_'));
    });

    test('ohne Backend-Werte läuft die App rein lokal', () {
      AppConfig.overrideForTesting(
        const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
      );

      expect(AppConfig.instance.hasBackend, isFalse);
    });
  });
}
