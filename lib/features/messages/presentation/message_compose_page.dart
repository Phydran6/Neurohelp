import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../shared/widgets/ai_suggestions.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/history_check.dart';
import '../../../shared/widgets/recall_entry.dart';
import '../../../shared/widgets/text_context_menu.dart';
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
  final _scroll = ScrollController();
  bool _busy = false;

  /// Nur für den ersten Schritt. Ein Entwurf, der schon einen Betreff hat,
  /// fängt nicht wieder bei der Frage an.
  late RecallMode _subjectMode = widget.draft.subject.trim().isEmpty
      ? RecallMode.asking
      : RecallMode.typing;

  /// Was der Historie-Check zum Nachrichten-Feature gefunden hat.
  List<HistoryEntry> _found = const [];
  HistoryCheckState _check = HistoryCheckState.running;

  @override
  void initState() {
    super.initState();
    _controller.text = _valueForStep();
  }

  /// „Warte mal, ich schau kurz für dich." (Konzept, Abschnitt 10, Schritt 2)
  ///
  /// Erst gräbt die App, dann erst wird der User gefragt. Gedächtnis
  /// anstupsen kann überfordern – die Denkarbeit macht die App.
  Future<void> _digIntoHistory() async {
    setState(() {
      _subjectMode = RecallMode.helping;
      _check = HistoryCheckState.running;
      _found = const [];
    });

    final entries = await AppScope.of(
      context,
    ).history.recentEntries(feature: HistoryFeature.message, limit: 8);
    if (!mounted) return;

    // Der eigene, gerade angelegte Vorgang ist kein Fund.
    final others = entries
        .where((entry) => entry.id != _flow.draft.entryId)
        .toList();

    setState(() {
      _found = others;
      _check = others.isEmpty
          ? HistoryCheckState.empty
          : HistoryCheckState.found;
    });
  }

  /// Ein Fund aus der Historie wird zum Thema der neuen Nachricht.
  ///
  /// Übernommen wird nur der Titel: Der alte Vorgang bleibt, wie er ist –
  /// hier entsteht eine neue Nachricht, kein Weiterschreiben am alten.
  void _takeFromHistory(HistoryEntry entry) {
    setState(() {
      _subjectMode = RecallMode.typing;
      _controller.text = entry.title;
    });
    unawaited(_applyAndAdvance());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _valueForStep() => switch (_flow.step) {
    MessageStep.subject => _flow.draft.subject,
    MessageStep.recipientType => _flow.draft.recipientType ?? '',
    MessageStep.recipient => _flow.draft.recipient ?? '',
    MessageStep.compose => _flow.draft.body,
    _ => '',
  };

  Future<void> _applyAndAdvance() async {
    final text = _controller.text.trim();

    final draft = switch (_flow.step) {
      MessageStep.subject => _flow.draft.copyWith(subject: text),
      MessageStep.recipientType => _flow.draft.copyWith(recipientType: text),
      MessageStep.recipient => _flow.draft.copyWith(recipient: text),
      // Wer am Anfang nicht sagen konnte, worum es geht, soll am Ende
      // trotzdem keine Nachricht ohne Betreff verschicken. Der ergibt sich
      // aus dem, was inzwischen dasteht.
      MessageStep.compose => _flow.draft.copyWith(
        body: text,
        subject: _flow.draft.subject.trim().isEmpty
            ? _subjectFromBody(text)
            : _flow.draft.subject,
      ),
      _ => _flow.draft,
    };

    var next = _flow.withDraft(draft);

    // „Weiß ich noch nicht" ist eine gültige Antwort – aber nur, wenn der
    // User sie ausdrücklich gibt.
    if (_flow.step == MessageStep.subject &&
        text.isEmpty &&
        _subjectMode == RecallMode.helping) {
      next = next.deferSubject();
    }

    if (!next.canAdvance) return;

    next = next.advance();

    // Der Historie-Check ist Arbeit der App, keine Frage an den User. Er
    // ist beim Einstieg schon gelaufen und bekommt hier keinen Bildschirm.
    while (next.step == MessageStep.historyCheck && next.nextStep != null) {
      next = next.advance();
    }

    // Jeder Schritt geht sofort in die Datenbank. Vorher wurde erst beim
    // Übergeben gespeichert – wer mittendrin aufhörte, verlor alles, und die
    // Liste „Angefangen und liegengeblieben" blieb für immer leer, weil es
    // nie eine liegengebliebene Zeile gab.
    await AppScope.of(context).messages.save(draft);
    if (!mounted) return;

    setState(() {
      _flow = next;
      _controller.text = _valueForStep();
    });
    // Jeder Schritt fängt oben an, nicht dort, wo der vorige endete.
    _scrollToField();
  }

  void _back() {
    // Im ersten Schritt führt „zurück" nicht aus der Nachricht heraus,
    // sondern eine Ebene höher: zurück zu der Frage, ob man es noch weiß.
    if (_flow.step == MessageStep.subject) {
      setState(() => _subjectMode = RecallMode.asking);
      return;
    }

    var previous = _flow.back();
    while (previous.step == MessageStep.historyCheck) {
      previous = previous.back();
    }

    setState(() {
      _flow = previous;
      _controller.text = _valueForStep();
      if (previous.step == MessageStep.subject) {
        _subjectMode = RecallMode.typing;
      }
    });
    _scrollToField();
  }

  /// Aus dem geschriebenen Text einen brauchbaren Betreff machen.
  static String _subjectFromBody(String body) {
    final firstLine = body
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return '';

    final stop = firstLine.indexOf(RegExp(r'[.!?]'));
    final sentence = stop > 0 ? firstLine.substring(0, stop) : firstLine;
    return sentence.length <= 60 ? sentence : '${sentence.substring(0, 57)}…';
  }

  /// Was die KI zum Formulieren braucht: Betreff, Empfängertyp und die
  /// Stichpunkte, die schon im Feld stehen.
  String? _composeInput() {
    final notes = _controller.text.trim();
    if (notes.isEmpty) return null;

    final draft = _flow.draft;
    return [
      if (draft.subject.trim().isNotEmpty) 'Betreff: ${draft.subject}',
      if (draft.recipientType != null) 'Empfänger: ${draft.recipientType}',
      'Stichpunkte: $notes',
    ].join('\n');
  }

  /// Text aus der Zwischenablage an die Cursorstelle setzen.
  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text ?? '';
    if (!mounted) return;

    if (pasted.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('In der Zwischenablage steht gerade kein Text.'),
        ),
      );
      return;
    }

    final value = _controller.value;
    final selection = value.selection;
    // Ohne gesetzten Cursor (Feld noch nie berührt) hängt der Text hinten an.
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;

    setState(() {
      _controller.value = TextEditingValue(
        text: value.text.replaceRange(start, end, pasted),
        selection: TextSelection.collapsed(offset: start + pasted.length),
      );
    });
  }

  void _scrollToField() {
    if (!_scroll.hasClients) return;
    unawaited(
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ),
    );
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
    final isAsking =
        _flow.step == MessageStep.subject && _subjectMode == RecallMode.asking;
    final isHelping =
        _flow.step == MessageStep.subject && _subjectMode == RecallMode.helping;
    final hint = isHelping ? null : _hintFor(_flow.step);

    return Scaffold(
      appBar: AppBar(
        leading: isAsking
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
              if (!isAsking) ...[
                Text(
                  _questionFor(_flow.step),
                  key: const Key('msg_question'),
                  style: theme.textTheme.headlineSmall,
                ),
                if (hint != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    hint,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
              if (isAsking)
                // Erst die Frage, dann das leere Feld. Wer nicht weiß, worum
                // es geht, muss hier nicht raten – die App gräbt für ihn.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RecallChoice(
                        prefix: 'msg',
                        onKnow: () =>
                            setState(() => _subjectMode = RecallMode.typing),
                        onHelp: () => unawaited(_digIntoHistory()),
                      ),
                      const Spacer(),
                    ],
                  ),
                )
              else if (isReview)
                Expanded(child: _Preview(draft: _flow.draft))
              else
                // Feld und KI-Block teilen sich eine Liste, die scrollt.
                // Vorher hing das Feld in einem `Expanded`: Sobald der
                // KI-Block Vorschläge zeigte, blieb für das Feld fast keine
                // Höhe mehr übrig – der eigene Text und der Cursor waren weg.
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    children: [
                      // Zuerst gräbt die App, dann erst wird gefragt.
                      if (isHelping) ...[
                        RecallPanel(
                          prefix: 'msg',
                          state: _check,
                          hits: _found,
                          nudges: RecallNudges.message,
                          onPick: _takeFromHistory,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Wenn dir doch etwas einfällt:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        key: const Key('msg_field'),
                        controller: _controller,
                        autofocus: true,
                        minLines: _flow.step == MessageStep.compose ? 6 : 1,
                        maxLines: _flow.step == MessageStep.compose ? null : 1,
                        textAlignVertical: TextAlignVertical.top,
                        textCapitalization: TextCapitalization.sentences,
                        contextMenuBuilder: noScanContextMenu,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      // Wer den Text woanders schon geschrieben hat, soll ihn
                      // herüberholen können, ohne im Auswahlmenü zu suchen.
                      if (_flow.step == MessageStep.compose)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('msg_paste'),
                            onPressed: () => unawaited(_pasteFromClipboard()),
                            icon: const Icon(Icons.content_paste_outlined),
                            label: const Text('Aus Zwischenablage einfügen'),
                          ),
                        ),
                      // Der Moment der KI-Hilfe (Konzept, Abschnitt 10,
                      // Schritt 4): aus Stichpunkten wird ein Vorschlag, den
                      // der User übernimmt oder liegen lässt. Nichts wird
                      // automatisch eingesetzt.
                      if (_flow.step == MessageStep.compose)
                        AiSuggestionBox(
                          task: AiTask.composeMessage,
                          singleLine: true,
                          acceptLabel: 'Einsetzen',
                          inputBuilder: _composeInput,
                          onAccept: (suggestion) {
                            setState(() => _controller.text = suggestion);
                            // Der Knopf sitzt unter dem Feld: ohne diesen
                            // Sprung nach oben landet der übernommene Text
                            // außerhalb des Sichtbaren.
                            _scrollToField();
                          },
                        ),
                    ],
                  ),
                ),
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
              ] else if (!isAsking)
                // Im Historie-Weg geht es immer weiter – auch mit leerem
                // Feld. Sonst stünde genau der User fest, dem geholfen
                // werden soll. Was fehlt, ergibt sich in den nächsten
                // Schritten.
                BigActionButton(
                  key: const Key('msg_next'),
                  label: isHelping && _controller.text.trim().isEmpty
                      ? 'Weiter, ich weiß es noch nicht'
                      : 'Weiter',
                  onPressed: _controller.text.trim().isEmpty && !isHelping
                      ? null
                      : () => unawaited(_applyAndAdvance()),
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
