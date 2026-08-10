import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/ai_suggestions.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/message_draft.dart';
import '../domain/message_flow.dart';

/// Führt Schritt für Schritt durch eine Nachricht (Konzept, Abschnitt 10).
///
/// **Ein Schritt pro Bildschirm.** Die Reihenfolge ist festgelegt: Inhalt
/// zuerst, Empfänger später, und dort erst der Typ, dann die Adresse.
class MessageComposePage extends StatefulWidget {
  const MessageComposePage({required this.draft, super.key});

  final MessageDraft draft;

  @override
  State<MessageComposePage> createState() => _MessageComposePageState();
}

class _MessageComposePageState extends State<MessageComposePage> {
  late MessageFlow _flow = MessageFlow(draft: widget.draft);
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.text = _valueForStep();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _valueForStep() => switch (_flow.step) {
    MessageStep.subject => _flow.draft.subject,
    MessageStep.recipientType => _flow.draft.recipientType ?? '',
    MessageStep.recipient => _flow.draft.recipient ?? '',
    MessageStep.compose => _flow.draft.body,
    _ => '',
  };

  void _applyAndAdvance() {
    final text = _controller.text.trim();

    final draft = switch (_flow.step) {
      MessageStep.subject => _flow.draft.copyWith(subject: text),
      MessageStep.recipientType => _flow.draft.copyWith(recipientType: text),
      MessageStep.recipient => _flow.draft.copyWith(recipient: text),
      MessageStep.compose => _flow.draft.copyWith(body: text),
      _ => _flow.draft,
    };

    var next = _flow.withDraft(draft);
    if (!next.canAdvance) return;

    next = next.advance();

    // Der Historie-Check ist Arbeit der App, keine Frage an den User. Er
    // ist beim Einstieg schon gelaufen und bekommt hier keinen Bildschirm.
    while (next.step == MessageStep.historyCheck && next.nextStep != null) {
      next = next.advance();
    }

    setState(() {
      _flow = next;
      _controller.text = _valueForStep();
    });
  }

  void _back() {
    var previous = _flow.back();
    while (previous.step == MessageStep.historyCheck) {
      previous = previous.back();
    }

    setState(() {
      _flow = previous;
      _controller.text = _valueForStep();
    });
  }

  /// Was die KI zum Formulieren braucht: Betreff, Empfängertyp und die
  /// Stichpunkte, die schon im Feld stehen.
  String? _composeInput() {
    final notes = _controller.text.trim();
    if (notes.isEmpty) return null;

    final draft = _flow.draft;
    return [
      'Betreff: ${draft.subject}',
      if (draft.recipientType != null) 'Empfänger: ${draft.recipientType}',
      'Stichpunkte: $notes',
    ].join('\n');
  }

  Future<void> _handOver() async {
    if (_busy) return;
    setState(() => _busy = true);

    final services = AppScope.of(context);
    final saved = await services.messages.save(_flow.draft);
    await services.sender.handOver(saved);
    // Übergeben heißt nicht gesendet: Ob die Mail rausging, kann die App
    // nicht wissen. Sie merkt sich den Zwischenstand und fragt später.
    await services.messages.handOver(saved.id);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReview = _flow.step == MessageStep.review;

    return Scaffold(
      appBar: AppBar(
        leading: _flow.step == MessageStep.subject
            ? null
            : IconButton(
                key: const Key('msg_back'),
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              ),
        title: const Text('Nachricht schreiben'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _questionFor(_flow.step),
                key: const Key('msg_question'),
                style: theme.textTheme.headlineSmall,
              ),
              if (_hintFor(_flow.step) != null) ...[
                const SizedBox(height: 12),
                Text(
                  _hintFor(_flow.step)!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (isReview)
                Expanded(child: _Preview(draft: _flow.draft))
              else ...[
                Expanded(
                  child: TextField(
                    key: const Key('msg_field'),
                    controller: _controller,
                    autofocus: true,
                    maxLines: _flow.step == MessageStep.compose ? null : 1,
                    expands: _flow.step == MessageStep.compose,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Der Moment der KI-Hilfe (Konzept, Abschnitt 10, Schritt 4):
                // aus Stichpunkten wird ein Vorschlag, den der User übernimmt
                // oder liegen lässt. Nichts wird automatisch eingesetzt.
                if (_flow.step == MessageStep.compose)
                  AiSuggestionBox(
                    task: AiTask.composeMessage,
                    singleLine: true,
                    acceptLabel: 'Einsetzen',
                    inputBuilder: _composeInput,
                    onAccept: (suggestion) => setState(() {
                      _controller.text = suggestion;
                    }),
                  ),
              ],
              const SizedBox(height: 16),
              if (isReview) ...[
                BigActionButton(
                  key: const Key('msg_send'),
                  label: 'An die Mail-App übergeben',
                  icon: Icons.outbox_outlined,
                  onPressed: _busy ? null : _handOver,
                ),
                const SizedBox(height: 8),
                // Kein Zwang in beide Richtungen: senden oder nochmal ran.
                TextButton(
                  key: const Key('msg_edit_again'),
                  onPressed: () => setState(() => _flow = _flow.editAgain()),
                  child: const Text('Nochmal bearbeiten'),
                ),
              ] else
                BigActionButton(
                  key: const Key('msg_next'),
                  label: 'Weiter',
                  onPressed: _controller.text.trim().isEmpty
                      ? null
                      : _applyAndAdvance,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _questionFor(MessageStep step) => switch (step) {
    // Inhalt zuerst, nicht Empfänger.
    MessageStep.subject => 'Worum geht es?',
    MessageStep.historyCheck => 'Einen Moment …',
    MessageStep.recipientType => 'An wen ungefähr?',
    MessageStep.recipient => 'Und wohin genau?',
    MessageStep.compose => 'Was möchtest du sagen?',
    MessageStep.review => 'So sieht es aus',
  };

  static String? _hintFor(MessageStep step) => switch (step) {
    MessageStep.recipientType =>
      'Grob reicht: Krankenkasse, Vermieter, Amt. Der genaue Kontakt kommt '
          'gleich.',
    MessageStep.compose =>
      'Schreib einfach hin, worum es geht. Anrede und Grußformel setze ich '
          'dazu.',
    MessageStep.review => 'Nichts geht raus, bevor du es losschickst.',
    _ => null,
  };
}

class _Preview extends StatelessWidget {
  const _Preview({required this.draft});

  final MessageDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'An: ${draft.recipient ?? ''}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Betreff: ${draft.subject}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              draft.fullText(),
              key: const Key('msg_preview'),
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
