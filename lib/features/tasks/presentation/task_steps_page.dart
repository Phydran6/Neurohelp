import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/ai_suggestions.dart';
import '../../../shared/widgets/big_action_button.dart';
import 'task_focus_page.dart';

/// Eine neue Aufgabe anlegen und selbst zerlegen (Konzept, Abschnitt 11,
/// Weg B).
///
/// Das Anlegen muss sich **smooth anfühlen** – genau hier entsteht sonst die
/// Reibung, die blockiert. Deshalb: ein Feld, Eingabetaste, nächster Punkt.
/// Kein Dialog, kein Speichern-Knopf pro Schritt.
class TaskStepsPage extends StatefulWidget {
  const TaskStepsPage({super.key});

  @override
  State<TaskStepsPage> createState() => _TaskStepsPageState();
}

class _TaskStepsPageState extends State<TaskStepsPage> {
  final _titleController = TextEditingController();
  final _stepController = TextEditingController();
  final _stepFocus = FocusNode();

  final List<String> _steps = [];
  bool _saving = false;

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

  bool get _canStart =>
      _titleController.text.trim().isNotEmpty && _steps.isNotEmpty;

  Future<void> _start() async {
    if (!_canStart || _saving) return;
    setState(() => _saving = true);

    final tasks = AppScope.of(context).tasks;
    final title = _titleController.text.trim();
    final entryId = await tasks.createTask(title);
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
      appBar: AppBar(title: const Text('Neue Aufgabe')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('task_title_field'),
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
                onAccept: (suggestion) => _acceptSuggestions([suggestion]),
                onAcceptAll: _acceptSuggestions,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _steps.length,
                  itemBuilder: (context, index) => ListTile(
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
                      onPressed: () => setState(() => _steps.removeAt(index)),
                    ),
                  ),
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
