import 'package:flutter/material.dart';

import '../../../core/companion/tone_texts.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../help/presentation/help_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../domain/greetings.dart';
import 'main_menu_page.dart';

/// Die Startseite (Konzept, Abschnitt 6).
///
/// Logo, ein wechselnder Spruch im gewählten Ton, **ein** großer Button. Kein
/// leeres Eingabefeld, das einen anstarrt. Kein Tutorial.
class StartPage extends StatelessWidget {
  const StartPage({super.key, this.today});

  /// Nur für Tests – sonst der heutige Tag.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = AppScope.of(context).settings;

    // Am Controller horchen: Wer in den Einstellungen den Ton umstellt, soll
    // beim Zurückkommen einen anderen Spruch sehen.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final tone = settings.current.tone;
        final texts = ToneTexts(tone);
        final greeting = Greetings.forDate(today ?? DateTime.now(), tone: tone);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Ruhig auffindbar, ohne den Startbildschirm zu stören
                  // (Konzept, Abschnitt 15).
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        key: const Key('start_help'),
                        icon: const Icon(Icons.help_outline),
                        tooltip: 'Hilfe & Info',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const HelpPage(),
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('start_settings'),
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: 'Einstellungen',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SettingsPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  Text(
                    'Neurohelp',
                    key: const Key('start_logo'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    greeting,
                    key: const Key('start_greeting'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(flex: 3),
                  BigActionButton(
                    key: const Key('start_button'),
                    label: texts.startButton,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const MainMenuPage(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
