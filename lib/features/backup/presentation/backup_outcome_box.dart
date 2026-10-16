import 'package:flutter/material.dart';

import '../../../shared/widgets/error_details.dart';
import '../domain/backup_runner.dart';

/// Was bei einem Sicherungsvorgang herausgekommen ist.
///
/// Ein Satz, der auf den Bildschirm darf, plus das Kleingedruckte zum
/// Aufklappen. An einer Stelle, weil der Einstieg nach der Neuinstallation
/// und die Einstellungen dasselbe zeigen sollen.
///
/// **Material, nicht Container:** Das aufklappbare Kleingedruckte malt
/// seinen Tipp-Effekt auf das nächste Material. Läge dazwischen nur eine
/// eingefärbte Box, verschluckt sie ihn – Flutter meldet das im Test als
/// Fehler, und auf dem Gerät fühlt sich die Zeile tot an.
class BackupOutcomeBox extends StatelessWidget {
  const BackupOutcomeBox({required this.outcome, super.key});

  final BackupOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: const Key('backup_outcome'),
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(outcome.message, style: theme.textTheme.bodyMedium),
            if (outcome.technical != null) ...[
              const SizedBox(height: 4),
              ErrorDetails(technical: outcome.technical!),
            ],
          ],
        ),
      ),
    );
  }
}
