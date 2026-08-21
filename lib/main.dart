import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/account/data/supabase_account_repository.dart';
import 'core/account/data/unconfigured_account_repository.dart';
import 'core/ai/ai_client.dart';
import 'core/ai/data/layered_ai_client.dart';
import 'core/ai/data/openrouter_ai_client.dart';
import 'core/ai/data/supabase_ai_client.dart';
import 'core/ai/openrouter/openrouter_account.dart';
import 'core/ai/openrouter/openrouter_api.dart';
import 'core/ai/openrouter/openrouter_key_store.dart';
import 'core/config/app_config.dart';
import 'core/db/app_database.dart';
import 'core/di/app_services.dart';
import 'core/files/file_saver.dart';
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

  // Der eigene KI-Zugang des Users, falls einer auf dem Gerät liegt
  // (Konzept, Abschnitt 17a). Er wird gleich gelesen – vor dem ersten Bild,
  // damit die Einstellungen nicht kurz „nicht verbunden" behaupten.
  final openRouterApi = OpenRouterApi();
  final openRouter = OpenRouterAccount(
    store: const SecureOpenRouterKeyStore(),
    api: openRouterApi,
  );
  await openRouter.load();

  final services = AppServices.from(
    database,
    sender: const UrlLauncherMessageSender(),
    dialer: const UrlLauncherCallLauncher(),
    lock: const DeviceAppLock(),
    files: const ShareFileSaver(),
    account: client == null
        ? const UnconfiguredAccountRepository()
        : SupabaseAccountRepository(client),
    openRouter: openRouter,
    // Der Schalter kommt gleich aus den Einstellungen. Bis dahin gilt: aus.
    ai: _buildAi(
      backend: client,
      openRouter: openRouter,
      openRouterApi: openRouterApi,
    ),
  );

  // Einmal lesen, bevor das erste Bild steht: Danach kennen Startseite,
  // KI-Client und Sperre den gespeicherten Stand.
  await services.settings.load();

  runApp(AppScope(services: services, child: const NeurohelpApp()));
}

/// Stellt die KI-Schicht mit ihren Stufen zusammen (Konzept, Abschnitt 17a).
///
/// Reihenfolge: erst der eigene Zugang des Users, dann die eigene gehostete
/// KI. Fällt oben etwas aus, geht es stillschweigend eine Stufe tiefer.
/// Bleibt nichts übrig, geht jeder Ablauf seinen lokalen Weg.
///
/// Der Schalter steht überall zunächst auf „aus" – er kommt gleich aus den
/// Einstellungen.
AiClient _buildAi({
  required SupabaseClient? backend,
  required OpenRouterAccount openRouter,
  required OpenRouterApi openRouterApi,
}) {
  final stages = <AiClient>[
    OpenRouterAiClient(account: openRouter, api: openRouterApi, enabled: false),
    if (backend != null) SupabaseAiClient(backend, enabled: false),
  ];

  return LayeredAiClient(stages);
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
