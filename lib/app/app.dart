import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/di/app_services.dart';
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
  bool _unlocked = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final settings = AppScope.of(context).settings;
    if (settings.isLoaded) {
      _unlocked = !settings.current.isLocked;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final loaded = await AppScope.of(context).settings.load();
    if (!mounted) return;
    // Ohne eingerichtete Sperre gibt es nichts zu entsperren.
    setState(() => _unlocked = !loaded.isLocked);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).settings;

    // Am Controller horchen: Ton, KI-Schalter und Sperre dürfen sich zur
    // Laufzeit ändern und sollen sofort ankommen.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.isLoaded) return const SizedBox.shrink();
        final settings = controller.current;

        if (!settings.onboardingCompleted) {
          return OnboardingPage(onDone: () => setState(() => _unlocked = true));
        }

        if (settings.isLocked && !_unlocked) {
          return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
        }

        return const StartPage();
      },
    );
  }
}
