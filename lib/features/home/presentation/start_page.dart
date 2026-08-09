import 'package:flutter/material.dart';

import '../../../shared/widgets/big_action_button.dart';
import '../../help/presentation/help_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../domain/greetings.dart';
import 'main_menu_page.dart';

/// Die Startseite (Konzept, Abschnitt 6).
///
/// Logo, ein wechselnder Spruch im Kumpel-Ton, **ein** großer Button. Kein
/// leeres Eingabefeld, das einen anstarrt. Kein Tutorial.
class StartPage extends StatelessWidget {
  const StartPage({super.key, this.today});

  /// Nur für Tests – sonst der heutige Tag.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final greeting = Greetings.forDate(today ?? DateTime.now());

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
                      MaterialPageRoute<void>(builder: (_) => const HelpPage()),
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
                label: 'Los geht’s',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MainMenuPage()),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
