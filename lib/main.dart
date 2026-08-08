import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.initFromEnvironment();
  runApp(const NeurohelpApp());
}
