import 'package:flutter/material.dart';

import '../../../core/companion/tone_texts.dart';
import '../../../core/di/app_services.dart';
import '../../appointments/presentation/appointment_start_page.dart';
import '../../calls/presentation/call_start_page.dart';
import '../../history/presentation/history_page.dart';
import '../../messages/presentation/message_start_page.dart';
import '../../tasks/presentation/task_start_page.dart';

/// Ein Eintrag im Hauptmenü.
class MenuEntry {
  const MenuEntry({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

/// Das Hauptmenü (Konzept, Abschnitt 7).
///
/// Auswahl vor Eingabe: Der User tippt auf das, was er vorhat, statt in ein
/// leeres Feld zu schreiben.
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  /// Statt Emojis ruhige Symbole – gleiche Bedeutung, weniger Bildrauschen.
  ///
  /// Hier steht **nur**, was auch funktioniert. Der Eintrag „Etwas anderes"
  /// hat einen Bildschirm versprochen und eine Notiz geliefert, dass es ihn
  /// bald gibt – das ist schlimmer als eine kürzere Liste. Er kommt zurück,
  /// wenn der freie Ablauf gebaut ist (Konzept, Abschnitt 7).
  static const List<MenuEntry> entries = [
    MenuEntry(id: 'call', label: 'Anruf erledigen', icon: Icons.call_outlined),
    MenuEntry(
      id: 'appointment',
      label: 'Termin klären',
      icon: Icons.event_outlined,
    ),
    MenuEntry(
      id: 'message',
      label: 'Nachricht schreiben',
      icon: Icons.mail_outlined,
    ),
    MenuEntry(
      id: 'task',
      label: 'Aufgabe sortieren',
      icon: Icons.checklist_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texts = ToneTexts(AppScope.of(context).settings.current.tone);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              texts.menuTitle,
              key: const Key('menu_title'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            for (final entry in entries) ...[
              _MenuTile(entry: entry),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 20),
            // Ruhig darunter statt als fünfte Kachel: Nachschauen ist kein
            // Vorhaben, sondern der Weg dahin, wenn man das Vorhaben vergessen
            // hat (Konzept, Abschnitt 12).
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('menu_history'),
                icon: const Icon(Icons.history, size: 18),
                label: const Text('Was war da nochmal?'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.entry});

  final MenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('menu_${entry.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Icon(entry.icon, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Text(entry.label, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    final page = switch (entry.id) {
      'task' => const TaskStartPage(),
      'message' => const MessageStartPage(),
      'call' => const CallStartPage(),
      'appointment' => const AppointmentStartPage(),
      // Nicht erreichbar: [MainMenuPage.entries] enthält nur Einträge mit
      // gebautem Bildschirm. Wer hier ergänzt, soll darüber stolpern.
      _ => throw StateError('Kein Bildschirm für ${entry.id}.'),
    };

    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
