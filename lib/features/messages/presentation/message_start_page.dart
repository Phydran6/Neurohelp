import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/history_check.dart';
import '../domain/message_draft.dart';
import 'message_compose_page.dart';

/// Der Einstieg in „Nachricht schreiben" (Konzept, Abschnitt 10).
///
/// **Zuerst gräbt die App.** Bevor der User etwas eingibt, schaut sie nach,
/// ob eine Nachricht offen ist – fragt bei übergebenen Nachrichten sanft
/// nach, ob es geklappt hat, und sagt auch dann Bescheid, wenn sie nichts
/// gefunden hat.
class MessageStartPage extends StatefulWidget {
  const MessageStartPage({super.key});

  @override
  State<MessageStartPage> createState() => _MessageStartPageState();
}

class _MessageStartPageState extends State<MessageStartPage> {
  List<MessageDraft> _awaiting = const [];
  List<MessageDraft> _unfinished = const [];
  HistoryCheckState _check = HistoryCheckState.running;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) unawaited(_load());
  }

  Future<void> _load() async {
    final messages = AppScope.of(context).messages;
    final awaiting = await messages.awaitingConfirmation();
    final unfinished = await messages.unfinished();
    if (!mounted) return;

    setState(() {
      _awaiting = awaiting;
      _unfinished = unfinished;
      _loaded = true;
      _check = awaiting.isEmpty && unfinished.isEmpty
          ? HistoryCheckState.empty
          : HistoryCheckState.found;
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

  Future<void> _openDraft(MessageDraft draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(builder: (_) => MessageComposePage(draft: draft)),
    );
    if (mounted) unawaited(_load());
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
    final theme = Theme.of(context);
    final hasSomething = _awaiting.isNotEmpty || _unfinished.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Nachricht schreiben')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HistoryCheckHeader(state: _check),
              if (hasSomething)
                Expanded(
                  child: ListView(
                    children: [
                      for (final draft in _awaiting) ...[
                        _FollowUpCard(
                          draft: draft,
                          onYes: () => _answer(draft, sent: true),
                          onNo: () => _answer(draft, sent: false),
                          onLater: () => _dismiss(draft),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_unfinished.isNotEmpty) ...[
                        Text(
                          'Angefangen und liegengeblieben',
                          key: const Key('msg_unfinished_title'),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final draft in _unfinished) ...[
                          _DraftTile(
                            draft: draft,
                            onTap: () => _openDraft(draft),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    ],
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
              if (!hasSomething) const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eine liegengebliebene Nachricht zum Weitermachen.
class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.draft, required this.onTap});

  final MessageDraft draft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final an = draft.recipient ?? draft.recipientType;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('msg_draft_${draft.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(draft.subject, style: theme.textTheme.titleMedium),
                    if (an != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'An $an',
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
