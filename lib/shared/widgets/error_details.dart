import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Die technischen Details zu einer Störung – zugeklappt.
///
/// Anlass: In der Alpha endete jede Störung in einem freundlichen Satz ohne
/// jeden Anhaltspunkt. Wer meldet, dass „es nicht geht", kann damit nichts
/// belegen, und wer sucht, hat nichts zum Suchen.
///
/// Sichtbar ist nur „Details" – die ruhige Meldung steht darüber und bleibt
/// die Hauptsache. Wer mag, klappt auf und kopiert.
class ErrorDetails extends StatelessWidget {
  const ErrorDetails({required this.technical, super.key});

  final String technical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Theme(
      // Ohne das zeichnet ExpansionTile Trennlinien quer über die Seite.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('error_details'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          'Details',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  technical,
                  key: const Key('error_details_text'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('error_details_copy'),
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Kopieren'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: technical));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Details kopiert.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
