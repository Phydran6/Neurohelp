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
import 'core/settings/data/sqlite_settings_repository.dart';
import 'features/calls/data/url_launcher_call_launcher.dart';
import 'features/messages/data/url_launcher_message_sender.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initFromEnvironment();

  // Die Datenbank ist das Rückgrat der App und wird vor dem ersten Bild
  // geöffnet – ohne Historie kann kein Feature starten.
  final database = await AppDatabase.open();

  // Der KI-Toggle aus dem Onboarding entscheidet, ob es überhaupt einen
  // KI-Zugang gibt. Ohne ihn läuft die App vollständig lokal weiter.
  final settings = await SqliteSettingsRepository(database.raw).load();
  final client = await _connectBackend();

  final services = AppServices.from(
    database,
    sender: const UrlLauncherMessageSender(),
    dialer: const UrlLauncherCallLauncher(),
    lock: const DeviceAppLock(),
    account: client == null
        ? const UnconfiguredAccountRepository()
        : SupabaseAccountRepository(client),
    ai: client == null
        ? const DisabledAiClient()
        : SupabaseAiClient(client, enabled: settings.aiEnabled),
  );

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
