import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../core/history/domain/history_event.dart';
import '../../../shared/widgets/text_context_menu.dart';
import 'history_labels.dart';

/// Ein einzelner Vorgang mit seinem vollständigen Protokoll.
///
/// Designprinzip 9 lautet „Alles wird geloggt" – damit die App sagen kann:
/// *„Du warst hier stehen geblieben."* Geloggt wurde von Anfang an, gezeigt
/// wurde es nie. Hier steht der Verlauf, Zeile für Zeile.
class HistoryDetailPage extends StatefulWidget {
  const HistoryDetailPage({required this.entryId, super.key});

  final String entryId;

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  HistoryEntry? _entry;
  List<HistoryEvent> _events = const [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) unawaited(_load());
  }

  Future<void> _load() async {
    final history = AppScope.of(context).history;
    final entry = await history.entryById(widget.entryId);
    final events = entry == null
        ? const <HistoryEvent>[]
        : await history.eventsFor(entry.id);

    if (!mounted) return;
    setState(() {
      _entry = entry;
      // Neueste zuerst: Wer nachschaut, will wissen, wo er stehen geblieben
      // ist, nicht wie es angefangen hat.
      _events = events.reversed.toList();
      _loaded = true;
    });
  }

  Future<void> _rename() async {
    final entry = _entry;
    if (entry == null) return;

    final controller = TextEditingController(text: entry.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wie soll das heißen?'),
        content: TextField(
          key: const Key('history_rename_field'),
          contextMenuBuilder: noScanContextMenu,
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: const Key('history_rename_save'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (title == null || title.trim().isEmpty || !mounted) return;
    await AppScope.of(context).history.rename(entry.id, title.trim());
    if (mounted) await _load();
  }

  /// Von Hand abschließen oder wieder öffnen.
  ///
  /// Der Ausweg für alles, was außerhalb der App passiert ist: Wer den Anruf
  /// nebenbei erledigt hat, soll den Vorgang zumachen können, ohne den ganzen
  /// Ablauf noch einmal zu durchlaufen.
  Future<void> _toggleStatus() async {
    final entry = _entry;
    if (entry == null) return;

    final history = AppScope.of(context).history;
    if (entry.isOpen) {
      await history.closeEntry(entry.id, note: 'Von Hand abgehakt.');
    } else {
      await history.updateStatus(
        entry.id,
        HistoryStatus.open,
        note: 'Wieder geöffnet.',
      );
    }
    if (mounted) await _load();
  }

  Future<void> _delete() async {
    final entry = _entry;
    if (entry == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vorgang löschen?'),
        content: const Text(
          'Der Vorgang und sein Protokoll verschwinden von diesem Gerät. Das '
          'lässt sich nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            key: const Key('history_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Doch nicht'),
          ),
          FilledButton(
            key: const Key('history_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await AppScope.of(context).history.deleteEntry(entry.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = _entry;

    if (!_loaded) {
      return const Scaffold(body: SizedBox.shrink());
    }

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Diesen Vorgang gibt es nicht mehr.',
              key: const Key('history_detail_missing'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(HistoryLabels.feature(entry.feature)),
        actions: [
          IconButton(
            key: const Key('history_rename'),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Umbenennen',
            onPressed: _rename,
          ),
          IconButton(
            key: const Key('history_delete'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              entry.title.trim().isEmpty ? 'Ohne Titel' : entry.title.trim(),
              key: const Key('history_detail_title'),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              [
                HistoryLabels.status(entry.status),
                if (entry.contact != null) entry.contact!,
                'angefangen ${HistoryLabels.moment(entry.createdAt)}',
                if (entry.closedAt != null)
                  'abgeschlossen ${HistoryLabels.moment(entry.closedAt!)}',
              ].join(' · '),
              key: const Key('history_detail_meta'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('history_toggle_status'),
              onPressed: _toggleStatus,
              icon: Icon(entry.isOpen ? Icons.check : Icons.refresh, size: 18),
              label: Text(
                entry.isOpen ? 'Als erledigt abhaken' : 'Wieder öffnen',
              ),
            ),
            const SizedBox(height: 32),
            Text('Verlauf', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Alles, was zu diesem Vorgang mitgeschrieben wurde.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_events.isEmpty)
              Text(
                'Zu diesem Vorgang wurde nichts protokolliert.',
                key: const Key('history_events_empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (var i = 0; i < _events.length; i++)
                _EventRow(event: _events[i], isLast: i == _events.length - 1),
          ],
        ),
      ),
    );
  }
}

/// Eine Zeile im Verlauf, mit der Linie, die sie mit der nächsten verbindet.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.event, required this.isLast});

  final HistoryEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = event.note?.trim();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Icon(
                  Icons.circle,
                  size: 8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    HistoryLabels.event(event.kind),
                    key: Key('history_event_${event.id}'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    HistoryLabels.moment(event.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(note, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
