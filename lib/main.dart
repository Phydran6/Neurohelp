import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/db/app_database.dart';
import 'core/di/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initFromEnvironment();

  // Die Datenbank ist das Rückgrat der App und wird vor dem ersten Bild
  // geöffnet – ohne Historie kann kein Feature starten.
  final database = await AppDatabase.open();
  final services = AppServices.from(database);

  runApp(AppScope(services: services, child: const NeurohelpApp()));
}
