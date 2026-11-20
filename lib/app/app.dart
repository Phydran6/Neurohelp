import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/di/app_services.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/app_theme.dart';
import '../features/backup/presentation/restore_gate_page.dart';
import '../features/home/presentation/start_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/security/presentation/lock_screen.dart';

class NeurohelpApp extends StatelessWidget {
  const NeurohelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;

    // Am Controller horchen, nicht einmal lesen: Wer in den Einstellungen auf
    // dunkel stellt, soll es sofort sehen und nicht nach einem Neustart.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp(
        title: 'Neurohelp',
        // Store-Bildschirmfotos laufen mit FLAVOR=dev, dürfen das
        // DEBUG-Band aber nicht zeigen.
        debugShowCheckedModeBanner:
            !AppConfig.instance.isProduction &&
            !const bool.fromEnvironment('STORE_SCREENSHOTS'),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: switch (settings.current.themeChoice) {
          AppThemeChoice.system => ThemeMode.system,
          AppThemeChoice.light => ThemeMode.light,
          AppThemeChoice.dark => ThemeMode.dark,
        },
        home: const _Entry(),
      ),
    );
  }
}

/// Entscheidet, was beim Start zu sehen ist.
///
/// Die Reihenfolge ist Absicht: **Wiederherstellung vor Onboarding.** Wer die
/// App neu installiert hat, soll seine Sachen zurückbekommen, bevor er
/// gefragt wird, wie er angeredet werden will. Andersherum hätte er das
/// Onboarding zweimal – einmal vor und einmal nach dem Einspielen, weil die
/// Sicherung die Einstellungen mitbringt.
class _Entry extends StatefulWidget {
  const _Entry();

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _unlocked = false;
  bool _started = false;

  /// Ob eine Sitzung besteht. `null`, solange das noch nicht gelesen ist.
  bool? _signedIn;
  StreamSubscription<bool>? _accountChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final account = AppScope.of(context).account;
    if (account.isConfigured) {
      _accountChanges = account.signedInChanges.listen((signedIn) {
        if (mounted) setState(() => _signedIn = signedIn);
      });
      unawaited(_readAccount());
    }

    final settings = AppScope.of(context).settings;
    if (settings.isLoaded) {
      _unlocked = !settings.current.isLocked;
    } else {
      unawaited(_load());
    }
  }

  Future<void> _readAccount() async {
    final account = await AppScope.of(context).account.currentAccount();
    if (mounted) setState(() => _signedIn = account != null);
  }

  @override
  void dispose() {
    unawaited(_accountChanges?.cancel());
    super.dispose();
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

        // Genau einmal, beim allerersten Start: „Warst du schon mal hier?"
        if (!settings.onboardingCompleted && !settings.restoreOffered) {
          return const RestoreGatePage();
        }

        if (!settings.onboardingCompleted) {
          return OnboardingPage(onDone: () => setState(() => _unlocked = true));
        }

        if (settings.isLocked && !_unlocked) {
          return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
        }

        // Das Konto ist Pflicht (Konzept, Abschnitt 13). Wer abgemeldet ist,
        // meldet sich wieder an, statt in der App weiterzumachen, als wäre
        // nichts gewesen. Seine Sachen auf dem Gerät bleiben dabei, wo sie
        // sind.
        if (AppScope.of(context).account.isConfigured) {
          if (_signedIn == null) return const SizedBox.shrink();
          if (_signedIn == false) {
            return OnboardingPage(
              key: const Key('entry_sign_in'),
              signInOnly: true,
              onDone: () => setState(() => _signedIn = true),
            );
          }
        }

        return const StartPage();
      },
    );
  }
}
