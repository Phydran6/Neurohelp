import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/big_action_button.dart';
import 'expert_settings_page.dart';
import 'guided_settings_page.dart';

/// Der Einstieg in die Einstellungen (Konzept, Abschnitte 4, 5, 13, 14, 15).
///
/// **Die Vorschaltung ist der Punkt.** Bis hierher gab es eine einzige lange
/// Liste: Ton, KI-Schalter, eigener KI-Zugang, Biometrie, PIN,
/// Wiederherstellungs-Codes, Zwei-Faktor, Abmelden, Konto löschen. Für wen
/// ist die gebaut? Für einen, der weiß, was ein API-Schlüssel ist – und der
/// ist nicht die Zielgruppe dieser App. Für alle anderen ist so eine Liste
/// ein Raum voller Hebel, von denen jeder etwas kaputtmachen könnte.
///
/// Also zwei Wege, einmal gefragt:
///
/// * **„Ich weiß, was ich tue"** – alle Schalter, roh. Eigener KI-Endpunkt,
///   Sicherungsdatei selbst ablegen, Konto löschen, Zwei-Faktor.
/// * **„Ich hab keinen Plan"** – Entscheidungen statt Schalter. Dieselben
///   Fähigkeiten, aber niemand muss wissen, was OpenRouter ist.
///
/// Die Wahl ist **kein Urteil und keine Einbahnstraße**: Umschalten geht
/// oben rechts, jederzeit, ohne Erklärung.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  AppSettings _settings = const AppSettings();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) unawaited(_load());
  }

  Future<void> _load() async {
    final settings = await AppScope.of(context).settings.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loaded = true;
    });
  }

  Future<void> _choose(SettingsMode mode) async {
    final updated = await AppScope.of(context).settings.setSettingsMode(mode);
    if (mounted) setState(() => _settings = updated);
  }

  /// Zurück zur Auswahl. Nicht versteckt: Wer sich einmal verschätzt hat,
  /// soll nicht in einem Weg feststecken.
  void _reset() => unawaited(_choose(SettingsMode.unset));

  @override
  Widget build(BuildContext context) {
    // Kein Ladekringel: Der Zugriff dauert Millisekunden und flackert nur.
    if (!_loaded) return const Scaffold(body: SizedBox.shrink());

    return switch (_settings.settingsMode) {
      SettingsMode.unset => _SettingsGate(onChoose: _choose),
      SettingsMode.expert => ExpertSettingsPage(onSwitchMode: _reset),
      SettingsMode.guided => GuidedSettingsPage(onSwitchMode: _reset),
    };
  }
}

/// Die Frage vor den Einstellungen. Zwei gleichwertige Antworten.
class _SettingsGate extends StatelessWidget {
  const _SettingsGate({required this.onChoose});

  final Future<void> Function(SettingsMode mode) onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text(
              'Wie soll ich dir das zeigen?',
              key: const Key('settings_gate_question'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Beides führt zu denselben Möglichkeiten. Der Unterschied ist '
              'nur, wie viel dabei erklärt wird. Umstellen kannst du das '
              'jederzeit.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            _GateCard(
              id: 'guided',
              title: 'Ich hab keinen Plan',
              body:
                  'Wenige Fragen, im Klartext. KI mit einem Tap, Sicherung '
                  'läuft von selbst, nichts, was man kaputtmachen kann.',
              icon: Icons.favorite_outline,
              onTap: () => onChoose(SettingsMode.guided),
            ),
            const SizedBox(height: 12),
            _GateCard(
              id: 'expert',
              title: 'Ich weiß, was ich tue',
              body:
                  'Alles selbst: eigener KI-Endpunkt oder API-Schlüssel, '
                  'Sicherungsdatei dorthin, wo du willst, Zwei-Faktor, '
                  'Konto löschen.',
              icon: Icons.tune,
              onTap: () => onChoose(SettingsMode.expert),
            ),
            const SizedBox(height: 28),
            Text(
              'Keine der beiden Antworten sagt etwas über dich aus. Sie sagt '
              'nur, wie viel Text du heute lesen willst.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('settings_gate_$id'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der Knopf oben rechts, der zurück zur Auswahl führt.
///
/// Steht in beiden Wegen an derselben Stelle – wer ihn einmal gefunden hat,
/// findet ihn wieder.
class SwitchModeButton extends StatelessWidget {
  const SwitchModeButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const Key('settings_switch_mode'),
    icon: const Icon(Icons.swap_horiz),
    tooltip: 'Anders anzeigen',
    onPressed: onPressed,
  );
}

/// Der große Knopf am Ende beider Wege – „fertig".
class SettingsDoneButton extends StatelessWidget {
  const SettingsDoneButton({super.key});

  @override
  Widget build(BuildContext context) => BigActionButton(
    key: const Key('settings_done'),
    label: 'Fertig',
    onPressed: () => Navigator.of(context).pop(),
  );
}
