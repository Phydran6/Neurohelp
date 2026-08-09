import 'package:flutter/material.dart';

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
/// leeres Feld zu schreiben. Die freie Eingabe steht bewusst zuletzt.
class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  /// Statt Emojis ruhige Symbole – gleiche Bedeutung, weniger Bildrauschen.
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
    MenuEntry(
      id: 'free',
      label: 'Etwas anderes',
      icon: Icons.chat_bubble_outline,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Was geht? Womit kann ich helfen?',
              key: const Key('menu_title'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            for (final entry in entries) ...[
              _MenuTile(entry: entry),
              const SizedBox(height: 12),
            ],
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
        onTap: () => _showComingSoon(context),
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

  void _showComingSoon(BuildContext context) {
    // Ehrlich statt so tun als ob: Die Abläufe dahinter sind gebaut und
    // getestet, die Bildschirme dafür kommen als Nächstes.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('„${entry.label}“ ist gleich fertig.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
