import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/config/app_config.dart';
import '../core/di/app_services.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/start_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/security/presentation/lock_screen.dart';

/// Die Sprachpakete, die Flutter selbst mitbringt.
///
/// Ohne sie sprechen Datums- und Zeitwähler Englisch und rechnen mit der
/// US-Woche: Der Kalender fängt bei Sonntag an. Im Deutschen steht Montag
/// vorn – und wer beim Termin eine Spalte danebengreift, merkt es erst am
/// falschen Tag.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Die App ist durchgehend deutsch geschrieben. Deshalb wird auch das, was
/// Flutter beisteuert, auf Deutsch festgelegt – und nicht der Sprache des
/// Geräts überlassen, sonst steht ein englischer Kalender in einer deutschen
/// App.
const Locale appLocale = Locale('de');

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
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: const [appLocale],
      locale: appLocale,
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
