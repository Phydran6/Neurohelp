import 'package:flutter/material.dart';

import '../../core/companion/tone_texts.dart';
import '../../core/di/app_services.dart';
import '../../core/history/domain/history_entry.dart';

/// Das Ergebnis des Historie-Checks am Anfang eines Features.
///
/// Drei Zustände, und **alle drei werden gezeigt**: läuft noch, etwas
/// gefunden, nichts gefunden. Der stumme dritte Fall war der Fehler – der
/// User konnte nicht wissen, ob überhaupt gesucht wurde.
enum HistoryCheckState { running, found, empty }

/// Zeigt an, was der Historie-Check ergeben hat (Konzept, Abschnitt 12).
///
/// Jedes Feature startet damit, **bevor** der User etwas eingeben muss.
class HistoryCheckHeader extends StatelessWidget {
  const HistoryCheckHeader({required this.state, super.key});

  final HistoryCheckState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final texts = ToneTexts(AppScope.of(context).settings.current.tone);

    final text = switch (state) {
      // Kein Ladekringel: Der Check dauert Millisekunden, ein Kringel
      // flackert nur.
      HistoryCheckState.running => 'Ich schau kurz nach, ob da schon was war …',
      HistoryCheckState.found => texts.historyFound,
      HistoryCheckState.empty => texts.historyEmpty,
    };

    return Padding(
      key: const Key('history_check'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            switch (state) {
              HistoryCheckState.running => Icons.search,
              HistoryCheckState.found => Icons.history,
              HistoryCheckState.empty => Icons.check,
            },
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              key: Key('history_check_${state.name}'),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein gefundener offener Vorgang, zum Weitermachen.
class HistoryEntryTile extends StatelessWidget {
  const HistoryEntryTile({
    required this.entry,
    required this.onTap,
    this.subtitle,
    super.key,
  });

  final HistoryEntry entry;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('history_entry_${entry.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
