import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../domain/call_plan.dart';
import 'call_prepare_page.dart';

/// Der Einstieg in „Anruf erledigen" (Konzept, Abschnitt 8).
///
/// **Auswahl vor Eingabe:** zuerst die Kategorie antippen. Danach schaut die
/// App nach, ob es dazu schon einen Vorgang gab.
class CallStartPage extends StatelessWidget {
  const CallStartPage({super.key});

  /// Die häufigsten Fälle aus dem Konzept, plus ein offener Punkt.
  static const List<String> categories = [
    'Arzt',
    'Versicherung',
    'Handwerker',
    'Amt',
    'Etwas anderes',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Anruf erledigen')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Wen rufst du an?',
              key: const Key('call_title'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            for (final category in categories) ...[
              _CategoryTile(category: category),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('call_category_$category'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => unawaited(_open(context)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          child: Row(
            children: [
              Expanded(
                child: Text(category, style: theme.textTheme.titleMedium),
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

  Future<void> _open(BuildContext context) async {
    final services = AppScope.of(context);

    // Historie zuerst: Gab es dazu schon etwas?
    final earlier = await services.calls.previousInCategory(category);
    if (!context.mounted) return;

    final open = earlier.where((call) => !call.isDone).toList();
    if (open.isEmpty) {
      await _startNew(context);
      return;
    }

    final resume = await showModalBottomSheet<CallPlan?>(
      context: context,
      builder: (sheetContext) => _EarlierSheet(calls: open),
    );
    if (!context.mounted) return;

    if (resume == null) {
      await _startNew(context);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallPreparePage(planId: resume.id),
        ),
      );
    }
  }

  Future<void> _startNew(BuildContext context) async {
    final plan = await AppScope.of(context).calls.create(category: category);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CallPreparePage(planId: plan.id)),
    );
  }
}

/// „Geht's um [Thema vom letzten Mal]?" – die Frage aus Schritt 2.
class _EarlierSheet extends StatelessWidget {
  const _EarlierSheet({required this.calls});

  final List<CallPlan> calls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Da war schon mal was',
              key: const Key('call_earlier_title'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            for (final call in calls)
              ListTile(
                key: Key('call_earlier_${call.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(call.goal ?? call.category),
                subtitle: call.contactName == null
                    ? null
                    : Text(call.contactName!),
                onTap: () => Navigator.of(context).pop(call),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('call_earlier_new'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nein, etwas Neues'),
            ),
          ],
        ),
      ),
    );
  }
}
