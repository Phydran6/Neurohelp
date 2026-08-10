import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/account/data/supabase_account_repository.dart';
import 'core/account/data/unconfigured_account_repository.dart';
import 'core/ai/ai_client.dart';
import 'core/ai/data/supabase_ai_client.dart';
import 'core/config/app_config.dart';
import 'core/db/app_database.dart';
import 'core/di/app_services.dart';
import 'core/logging/app_logger.dart';
import 'core/security/data/device_app_lock.dart';
import 'features/calls/data/url_launcher_call_launcher.dart';
import 'features/messages/data/url_launcher_message_sender.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initFromEnvironment();

  // Die Datenbank ist das Rückgrat der App und wird vor dem ersten Bild
  // geöffnet – ohne Historie kann kein Feature starten.
  final database = await AppDatabase.open();
  final client = await _connectBackend();

  final services = AppServices.from(
    database,
    sender: const UrlLauncherMessageSender(),
    dialer: const UrlLauncherCallLauncher(),
    lock: const DeviceAppLock(),
    account: client == null
        ? const UnconfiguredAccountRepository()
        : SupabaseAccountRepository(client),
    // Der Schalter kommt gleich aus den Einstellungen. Bis dahin gilt: aus.
    ai: client == null
        ? const DisabledAiClient()
        : SupabaseAiClient(client, enabled: false),
  );

  // Einmal lesen, bevor das erste Bild steht: Danach kennen Startseite,
  // KI-Client und Sperre den gespeicherten Stand.
  await services.settings.load();

  runApp(AppScope(services: services, child: const NeurohelpApp()));
}

/// Baut die Verbindung zum Backend auf, oder liefert `null`.
///
/// `null` ist kein Fehlerfall: Die App bleibt dann vollständig lokal
/// benutzbar und sagt im Onboarding ruhig, dass es kein Konto gibt.
Future<SupabaseClient?> _connectBackend() async {
  final config = AppConfig.instance;
  if (!config.hasBackend) return null;

  try {
    final supabase = await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseKey,
      // Ohne das versucht Supabase, Bestätigungs- und Reset-Links über den
      // Browser zurück in die App zu holen. Neurohelp arbeitet stattdessen
      // mit sechsstelligen Codes: Die tippt man ab, und sie funktionieren
      // auch dann, wenn der Link im falschen Browser landet.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );
    return supabase.client;
  } on Exception catch (error, stackTrace) {
    AppLogger.error(
      'Backend nicht erreichbar – die App läuft lokal weiter',
      scope: 'backend',
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}
