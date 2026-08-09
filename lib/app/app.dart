import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/di/app_services.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/start_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/security/presentation/lock_screen.dart';

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
      home: const _Entry(),
    );
  }
}

/// Entscheidet, was beim Start zu sehen ist: Onboarding, Sperre oder App.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  AppSettings? _settings;
  bool _unlocked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settings == null) unawaited(_load());
  }

  Future<void> _load() async {
    final settings = await AppScope.of(context).settings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      // Ohne eingerichtete Sperre gibt es nichts zu entsperren.
      _unlocked = !settings.isLocked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return const SizedBox.shrink();

    if (!settings.onboardingCompleted) {
      return OnboardingPage(onDone: () => unawaited(_load()));
    }

    if (settings.isLocked && !_unlocked) {
      return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }

    return const StartPage();
  }
}
