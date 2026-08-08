import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/home_page.dart';

class NeurohelpApp extends StatelessWidget {
  const NeurohelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neurohelp',
      debugShowCheckedModeBanner: !AppConfig.instance.isProduction,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
