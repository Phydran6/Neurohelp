import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/task_node.dart';

/// Der Fokus-Modus (Konzept, Abschnitt 11, Schritt 3).
///
/// **Der Berg bleibt unsichtbar.** Zu sehen ist immer nur der nächste offene
/// Schritt. Eine Sache fertig, die nächste erscheint. Kein Fortschrittsbalken,
/// keine Liste, die einen erschlägt.
class TaskFocusPage extends StatefulWidget {
  const TaskFocusPage({required this.entryId, required this.title, super.key});

  final String entryId;
  final String title;

  @override
  State<TaskFocusPage> createState() => _TaskFocusPageState();
}

class _TaskFocusPageState extends State<TaskFocusPage> {
  TaskNode? _step;
  bool _loading = true;
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    final next = await AppScope.of(context).tasks.nextStep(widget.entryId);
    if (!mounted) return;

    setState(() {
      _step = next;
      _done = next == null;
      _loading = false;
    });
  }

  Future<void> _complete() async {
    final step = _step;
    if (step == null) return;

    setState(() => _loading = true);
    await AppScope.of(context).tasks.completeStep(widget.entryId, step.id);
    if (!mounted) return;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _loading
              ? const SizedBox.shrink()
              : _done
              ? const _AllDone(key: Key('focus_done'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Text(
                      'Als Nächstes',
                      key: const Key('focus_label'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _step!.title,
                      key: const Key('focus_step'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (_step!.note != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _step!.note!,
                        key: const Key('focus_note'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    BigActionButton(
                      key: const Key('focus_complete'),
                      label: 'Erledigt',
                      icon: Icons.check,
                      onPressed: _complete,
                    ),
                    const SizedBox(height: 12),
                    // Ausweg ohne Schuld: Der Vorgang bleibt liegen und
                    // wartet, er mahnt nicht.
                    TextButton(
                      key: const Key('focus_later'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Später weitermachen'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AllDone extends StatelessWidget {
  const _AllDone({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 20),
        // Feststellung, kein Lob. Konzept, Abschnitt 4: kein Coach.
        Text(
          'Alles abgehakt.',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 32),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zurück'),
        ),
      ],
    );
  }
}
