import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/history_check.dart';
import '../../history/presentation/resume_entry.dart';
import 'task_steps_page.dart';

/// Der Einstieg in „Aufgabe sortieren" (Konzept, Abschnitt 11, Schritt 1).
///
/// **Historie zuerst.** Bevor der User irgendetwas eingibt, schaut die App
/// nach, ob schon etwas angefangen ist – und sagt auch, wenn sie nichts
/// gefunden hat. Er soll sich nichts merken müssen.
class TaskStartPage extends StatefulWidget {
  const TaskStartPage({super.key});

  @override
  State<TaskStartPage> createState() => _TaskStartPageState();
}

class _TaskStartPageState extends State<TaskStartPage> {
  List<HistoryEntry> _open = const [];
  HistoryCheckState _check = HistoryCheckState.running;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) unawaited(_load());
  }

  Future<void> _load() async {
    final open = await AppScope.of(
      context,
    ).history.openEntries(feature: HistoryFeature.task);
    if (!mounted) return;
    setState(() {
      _open = open;
      _loaded = true;
      _check = open.isEmpty ? HistoryCheckState.empty : HistoryCheckState.found;
    });
  }

  /// Zurück in eine liegengebliebene Aufgabe.
  ///
  /// Über [ResumeEntry] statt direkt in den Fokus-Modus: Eine Aufgabe, die
  /// beim Anlegen abgebrochen wurde, hat keine Schritte. Der Fokus-Modus
  /// hätte dann nichts zu zeigen und meldete „alles erledigt" – für eine
  /// Aufgabe, an der nie jemand etwas getan hat. Sie gehört ans Zerlegen.
  Future<void> _openExisting(HistoryEntry entry) async {
    final blocked = await ResumeEntry.open(context, entry);
    if (!mounted) return;

    if (blocked != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ResumeEntry.describe(blocked)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    unawaited(_load());
  }

  Future<void> _startNew() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const TaskStepsPage()));
    if (mounted) unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aufgabe sortieren')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HistoryCheckHeader(state: _check),
              if (_open.isNotEmpty) ...[
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.separated(
                    itemCount: _open.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final entry = _open[index];
                      return HistoryEntryTile(
                        key: Key('task_open_${entry.id}'),
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
