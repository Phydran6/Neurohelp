import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/call_plan.dart';

/// Der Anruf selbst und die Nachbereitung (Konzept, Abschnitt 8).
///
/// Die Stichpunkte stehen groß da. Die native Begleitung – Android Overlay,
/// iOS Live Activity – kommt später; bis dahin bleibt dieser Bildschirm
/// offen, und die Notiz wird danach erfasst. Das ist auf iOS ohnehin der
/// vorgesehene Weg.
class CallActivePage extends StatefulWidget {
  const CallActivePage({required this.planId, super.key});

  final String planId;

  @override
  State<CallActivePage> createState() => _CallActivePageState();
}

class _CallActivePageState extends State<CallActivePage> {
  final _note = TextEditingController();

  CallPlan? _plan;
  bool _loading = true;
  bool _called = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final plan = await AppScope.of(context).calls.byId(widget.planId);
    if (!mounted || plan == null) return;
    setState(() {
      _plan = plan;
      _called = plan.calledAt != null;
      _loading = false;
    });
  }

  Future<void> _dial() async {
    final plan = _plan;
    if (plan == null) return;

    final services = AppScope.of(context);
    await services.dialer.dial(plan.contactNumber ?? '');
    final updated = await services.calls.markCalled(plan.id);

    if (!mounted) return;
    setState(() {
      _plan = updated;
      _called = true;
    });
  }

  Future<void> _finish({required bool succeeded}) async {
    final plan = _plan;
    if (plan == null) return;

    final note = _note.text.trim();
    await AppScope.of(context).calls.finish(
      plan.id,
      succeeded: succeeded,
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;

    if (_loading || plan == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: Text(plan.contactName ?? plan.category)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (plan.goal != null && plan.goal!.isNotEmpty) ...[
                Text(
                  plan.goal!,
                  key: const Key('call_goal_text'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
              ],
              Expanded(
                child: ListView(
                  children: [
                    for (var i = 0; i < plan.talkingPoints.length; i++)
                      Padding(
                        key: Key('call_active_point_$i'),
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                plan.talkingPoints[i],
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_called) ...[
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('call_note'),
                        controller: _note,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notiz zum Gespräch',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!_called)
                BigActionButton(
                  key: const Key('call_dial'),
                  label: 'Anruf starten',
                  icon: Icons.call,
                  onPressed: _dial,
                )
              else ...[
                // Nachbereitung: eine Frage, zwei Antworten.
                Text(
                  'Hat es geklappt?',
                  key: const Key('call_outcome_question'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        key: const Key('call_yes'),
                        onPressed: () => _finish(succeeded: true),
                        child: const Text('Ja'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('call_no'),
                        onPressed: () => _finish(succeeded: false),
                        child: const Text('Nein'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
