import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/message_draft.dart';
import 'message_compose_page.dart';

/// Der Einstieg in „Nachricht schreiben" (Konzept, Abschnitt 10).
///
/// **Zuerst gräbt die App.** Bevor der User etwas eingibt, schaut sie nach,
/// ob eine Nachricht offen ist – und fragt bei übergebenen Nachrichten
/// sanft nach, ob es geklappt hat.
class MessageStartPage extends StatefulWidget {
  const MessageStartPage({super.key});

  @override
  State<MessageStartPage> createState() => _MessageStartPageState();
}

class _MessageStartPageState extends State<MessageStartPage> {
  List<MessageDraft> _awaiting = const [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  Future<void> _load() async {
    final awaiting = await AppScope.of(context).messages.awaitingConfirmation();
    if (!mounted) return;
    setState(() {
      _awaiting = awaiting;
      _loading = false;
    });
  }

  Future<void> _answer(MessageDraft draft, {required bool sent}) async {
    await AppScope.of(context).messages.confirmSent(draft.id, sent: sent);
    if (mounted) unawaited(_load());
  }

  /// „Nicht jetzt" – der Vorgang bleibt, die Frage verschwindet für diesmal.
  void _dismiss(MessageDraft draft) {
    setState(() {
      _awaiting = _awaiting.where((entry) => entry.id != draft.id).toList();
    });
  }

  Future<void> _startNew() async {
    final services = AppScope.of(context);
    final draft = await services.messages.create(subject: '');
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => MessageComposePage(draft: draft)),
    );
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nachricht schreiben')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_awaiting.isNotEmpty)
                      Expanded(
                        child: ListView.separated(
                          itemCount: _awaiting.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final draft = _awaiting[index];
                            return _FollowUpCard(
                              draft: draft,
                              onYes: () => _answer(draft, sent: true),
                              onNo: () => _answer(draft, sent: false),
                              onLater: () => _dismiss(draft),
                            );
                          },
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(height: 16),
                    BigActionButton(
                      key: const Key('msg_new'),
                      label: 'Neue Nachricht',
                      icon: Icons.add,
                      onPressed: _startNew,
                    ),
                    if (_awaiting.isEmpty) const Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Die sanfte Nachfrage (Konzept, Abschnitt 10, Schritt 7).
///
/// **Immer mit Ausweg.** Höchstens drei Nachfragen insgesamt – die Grenze
/// steckt in der Historie-Schicht.
class _FollowUpCard extends StatelessWidget {
  const _FollowUpCard({
    required this.draft,
    required this.onYes,
    required this.onNo,
    required this.onLater,
  });

  final MessageDraft draft;
  final VoidCallback onYes;
  final VoidCallback onNo;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final an = draft.recipientType ?? draft.recipient ?? 'jemanden';

    return Container(
      key: Key('msg_followup_${draft.id}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Du wolltest neulich eine Nachricht an $an rausschicken – '
            'hat das geklappt?',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton(
                key: Key('msg_yes_${draft.id}'),
                onPressed: onYes,
                child: const Text('Ja'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: Key('msg_no_${draft.id}'),
                onPressed: onNo,
                child: const Text('Nein'),
              ),
              const Spacer(),
              TextButton(
                key: Key('msg_later_${draft.id}'),
                onPressed: onLater,
                child: const Text('Nicht jetzt'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
