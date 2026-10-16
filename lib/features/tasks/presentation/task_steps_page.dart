import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../shared/widgets/ai_suggestions.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/history_check.dart';
import '../../../shared/widgets/recall_entry.dart';
import '../../history/presentation/resume_entry.dart';
import '../../../shared/widgets/text_context_menu.dart';
import 'task_focus_page.dart';

/// Eine neue Aufgabe anlegen und selbst zerlegen (Konzept, Abschnitt 11,
/// Weg B).
///
/// Das Anlegen muss sich **smooth anfühlen** – genau hier entsteht sonst die
/// Reibung, die blockiert. Deshalb: ein Feld, Eingabetaste, nächster Punkt.
/// Kein Dialog, kein Speichern-Knopf pro Schritt.
class TaskStepsPage extends StatefulWidget {
  const TaskStepsPage({super.key, this.entryId, this.initialTitle});

  /// Eine Aufgabe, die es schon gibt.
  ///
  /// Der Weg aus der Historie zurück in eine Aufgabe, die beim Anlegen
  /// abgebrochen wurde: Sie steht in der Historie, hat aber keine Schritte –
  /// im Fokus-Modus gäbe es also nichts zu zeigen. Statt sie als leere Hülle
  /// stehen zu lassen, wird hier weiterzerlegt.
  final String? entryId;

  /// Titel, der schon feststeht. Kommt zusammen mit [entryId].
  final String? initialTitle;

  @override
  State<TaskStepsPage> createState() => _TaskStepsPageState();
}

class _TaskStepsPageState extends State<TaskStepsPage> {
  final _titleController = TextEditingController();
  final _stepController = TextEditingController();
  final _stepFocus = FocusNode();

  final List<String> _steps = [];
  bool _saving = false;

  /// Der Einstieg ist überall derselbe: erst die Frage, dann das Feld
  /// (Konzept, Abschnitt 10, Schritt 2 – gilt für alle Features).
  ///
  /// Ausnahme: An einer bestehenden Aufgabe gibt es nichts zu erinnern – sie
  /// ist ja schon gefunden. Dann steht sofort das Feld da.
  late RecallMode _mode = widget.entryId == null
      ? RecallMode.asking
      : RecallMode.typing;
  List<HistoryEntry> _found = const [];
  HistoryCheckState _check = HistoryCheckState.running;

  /// „Warte mal, ich schau kurz für dich." Erst gräbt die App, dann erst
  /// wird der User gefragt.
  Future<void> _digIntoHistory() async {
    setState(() {
      _mode = RecallMode.helping;
      _check = HistoryCheckState.running;
      _found = const [];
    });

    final entries = await AppScope.of(
      context,
    ).history.recentEntries(feature: HistoryFeature.task, limit: 8);
    if (!mounted) return;

    setState(() {
      _found = entries;
      _check = entries.isEmpty
          ? HistoryCheckState.empty
          : HistoryCheckState.found;
    });
  }

  /// Am gefundenen Vorgang weiterarbeiten, statt einen zweiten anzulegen.
  ///
  /// **Das war die Lücke.** Der Historie-Check hat gefunden, was offen war,
  /// und der einzige Weg weiter hieß: Titel übernehmen, neuer Vorgang. Wer
  /// seine angefangene Sache wiedererkannte, bekam eine Kopie davon und
  /// arbeitete garantiert nicht dort weiter, wo er aufgehört hatte.
  Future<void> _resumeFromHistory(HistoryEntry entry) async {
    final blocked = await ResumeEntry.open(context, entry);
    if (!mounted) return;
    if (blocked == null) return;

    // Geht es doch nicht weiter, bleibt der alte Weg: als Vorlage nehmen.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ResumeEntry.describe(blocked)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Ein Fund wird zum Titel der neuen Aufgabe – der alte Vorgang bleibt.
  void _takeFromHistory(HistoryEntry entry) {
    setState(() {
      _mode = RecallMode.typing;
      _titleController.text = entry.title;
    });
  }

  @override
  void initState() {
    super.initState();
    final title = widget.initialTitle;
    // Der Platzhalter aus einem abgebrochenen Ablauf ist kein Titel – er
    // gehört nicht ins Feld, sonst steht er gleich wieder als Thema da.
    if (title != null && title != kUnknownTopic) _titleController.text = title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _stepController.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  void _addStep() {
    final text = _stepController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _steps.add(text);
      _stepController.clear();
    });
    // Direkt weitertippen können, ohne erneut ins Feld zu tippen.
    _stepFocus.requestFocus();
  }

  /// Übernimmt einen KI-Vorschlag. Doppelte fliegen still raus – die Liste
  /// soll nicht durch zweimaliges Tippen wachsen.
  void _acceptSuggestions(List<String> suggestions) {
    setState(() {
      for (final suggestion in suggestions) {
        if (!_steps.contains(suggestion)) _steps.add(suggestion);
      }
    });
  }

  /// Ohne Schritte gibt es nichts zu sortieren – das bleibt die Bedingung.
  /// Der Titel dagegen darf offen bleiben, wenn der User ausdrücklich gesagt
  /// hat, dass er ihn nicht weiß.
  bool get _canStart =>
      _steps.isNotEmpty &&
      (_titleController.text.trim().isNotEmpty || _mode == RecallMode.helping);

  Future<void> _start() async {
    if (!_canStart || _saving) return;
    setState(() => _saving = true);

    final services = AppScope.of(context);
    final tasks = services.tasks;
    final typed = _titleController.text.trim();
    final title = typed.isEmpty ? kUnknownTopic : typed;

    // Eine bestehende Aufgabe wird weiterzerlegt, keine zweite angelegt.
    // Sonst stünden nach dem Weitermachen aus der Historie zwei gleich
    // heißende Vorgänge nebeneinander.
    final existing = widget.entryId;
    final entryId = existing ?? await tasks.createTask(title);
    if (existing != null && typed.isNotEmpty && typed != widget.initialTitle) {
      await services.history.rename(existing, title);
    }
    await tasks.addSteps(entryId, titles: _steps);

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TaskFocusPage(entryId: entryId, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.entryId == null ? 'Neue Aufgabe' : 'Aufgabe weiter zerlegen',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _mode == RecallMode.asking
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    RecallChoice(
                      prefix: 'task',
                      onKnow: () => setState(() => _mode = RecallMode.typing),
                      onHelp: () => unawaited(_digIntoHistory()),
                    ),
                    const Spacer(),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('task_title_field'),
                      contextMenuBuilder: noScanContextMenu,
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Worum geht es?',
                        hintText: 'Zum Beispiel: Umzug organisieren',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Was gehört dazu?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('task_step_field'),
                      contextMenuBuilder: noScanContextMenu,
                      controller: _stepController,
                      focusNode: _stepFocus,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: 'Ein kleiner Schritt',
                        suffixIcon: IconButton(
                          key: const Key('task_step_add'),
                          icon: const Icon(Icons.add),
                          onPressed: _addStep,
                        ),
                      ),
                      onSubmitted: (_) => _addStep(),
                    ),
                    // Der Moment der KI-Hilfe: aus dem Titel werden Mikroschritte,
                    // die als Vorschlag in der Liste landen. Ohne KI fehlt genau
                    // dieser Block, sonst nichts.
                    AiSuggestionBox(
                      task: AiTask.splitTask,
                      inputBuilder: () {
                        final title = _titleController.text.trim();
                        return title.isEmpty ? null : title;
                      },
                      onAccept: (suggestion) =>
                          _acceptSuggestions([suggestion]),
                      onAcceptAll: _acceptSuggestions,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          // Was die App gefunden hat, steht über der eigenen Liste –
                          // antippen genügt, getippt werden muss nichts.
                          if (_mode == RecallMode.helping) ...[
                            RecallPanel(
                              prefix: 'task',
                              state: _check,
                              hits: _found,
                              nudges: RecallNudges.task,
                              onPick: _takeFromHistory,
                              onResume: _resumeFromHistory,
                              resumeLabel: 'Daran weitermachen',
                            ),
                            const SizedBox(height: 16),
                          ],
                          for (var index = 0; index < _steps.length; index++)
                            ListTile(
                              key: Key('task_step_$index'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.circle_outlined,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(_steps[index]),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _steps.removeAt(index)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    BigActionButton(
                      key: const Key('task_start'),
                      label: 'Los geht’s',
                      onPressed: _canStart && !_saving ? _start : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
