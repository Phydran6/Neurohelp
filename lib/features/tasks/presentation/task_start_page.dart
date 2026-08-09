import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../shared/widgets/big_action_button.dart';
import 'task_focus_page.dart';
import 'task_steps_page.dart';

/// Der Einstieg in „Aufgabe sortieren" (Konzept, Abschnitt 11, Schritt 1).
///
/// **Historie zuerst.** Bevor der User irgendetwas eingibt, schaut die App
/// nach, ob schon etwas angefangen ist. Er soll sich nichts merken müssen.
class TaskStartPage extends StatefulWidget {
  const TaskStartPage({super.key});

  @override
  State<TaskStartPage> createState() => _TaskStartPageState();
}

class _TaskStartPageState extends State<TaskStartPage> {
  List<HistoryEntry> _open = const [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final open = await AppScope.of(
      context,
    ).history.openEntries(feature: HistoryFeature.task);
    if (!mounted) return;
    setState(() {
      _open = open;
      _loading = false;
    });
  }

  Future<void> _openExisting(HistoryEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskFocusPage(entryId: entry.id, title: entry.title),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _startNew() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TaskStepsPage()));
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Aufgabe sortieren')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_open.isNotEmpty) ...[
                      Text(
                        'Da war noch was',
                        key: const Key('task_open_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _open.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final entry = _open[index];
                            return _OpenTaskTile(
                              entry: entry,
                              onTap: () => _openExisting(entry),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      const Spacer(),
                    BigActionButton(
                      key: const Key('task_new'),
                      label: 'Neue Aufgabe',
                      icon: Icons.add,
                      onPressed: _startNew,
                    ),
                    if (_open.isEmpty) const Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OpenTaskTile extends StatelessWidget {
  const _OpenTaskTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('task_open_${entry.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(entry.title, style: theme.textTheme.titleMedium),
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
