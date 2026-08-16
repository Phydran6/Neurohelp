import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../shared/widgets/text_context_menu.dart';
import 'history_detail_page.dart';
import 'history_labels.dart';

/// Der Historie-Bereich (Konzept, Abschnitt 12).
///
/// Bisher war die Historie nur das Rückgrat **hinter** den Features: Jeder
/// Ablauf hat hineingeschrieben, gelesen hat daraus niemand außer dem
/// Historie-Check am Anfang. Was die App wusste, konnte der User nicht sehen –
/// „Du warst hier stehen geblieben" ohne die Möglichkeit nachzuschauen, wo
/// eigentlich.
///
/// Hier steht alles: offene und erledigte Vorgänge, quer über alle Features,
/// durchsuchbar. Kein Zwang, nichts Rotes – eine Liste, sonst nichts.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.initialFeature});

  /// Vorausgewähltes Feature, wenn der Bereich aus einem Ablauf geöffnet wird.
  final HistoryFeature? initialFeature;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _search = TextEditingController();

  late HistoryFeature? _feature = widget.initialFeature;
  bool _openOnly = false;

  List<HistoryEntry> _entries = const [];
  Map<HistoryFeature, ({int open, int total})> _counts = const {};
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final history = AppScope.of(context).history;
    final query = _search.text.trim();

    // Die Suche schlägt den Filter „nur offene": Wer sucht, will finden, auch
    // wenn der Vorgang längst erledigt ist.
    final entries = query.isNotEmpty
        ? await history.search(query, feature: _feature, limit: 100)
        : _openOnly
        ? await history.openEntries(feature: _feature, limit: 100)
        : await history.recentEntries(feature: _feature, limit: 100);

    final counts = await history.countsByFeature();
    if (!mounted) return;

    setState(() {
      _entries = entries;
      _counts = counts;
      _loaded = true;
    });
  }

  Future<void> _open(HistoryEntry entry) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryDetailPage(entryId: entry.id),
      ),
    );
    if (mounted) unawaited(_load());
  }

  void _setFeature(HistoryFeature? feature) {
    setState(() => _feature = feature);
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _counts.values.fold(0, (sum, entry) => sum + entry.total);

    return Scaffold(
      appBar: AppBar(title: const Text('Deine Historie')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: TextField(
                key: const Key('history_search'),
                contextMenuBuilder: noScanContextMenu,
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Suchen – Thema oder Ansprechpartner',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('history_search_clear'),
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _search.clear();
                            unawaited(_load());
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => unawaited(_load()),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _Chip(
                    id: 'all',
                    label: 'Alles',
                    selected: _feature == null,
                    onSelected: () => _setFeature(null),
                  ),
                  for (final feature in HistoryFeature.values) ...[
                    const SizedBox(width: 8),
                    _Chip(
                      id: feature.name,
                      label: HistoryLabels.feature(feature),
                      count: _counts[feature]?.total ?? 0,
                      selected: _feature == feature,
                      onSelected: () => _setFeature(feature),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _summary(total),
                      key: const Key('history_summary'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Kein Schalter, der etwas verbirgt: „Nur offene" ist eine
                  // Sicht, keine Aufräumaktion.
                  TextButton.icon(
                    key: const Key('history_open_only'),
                    icon: Icon(
                      _openOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
                      size: 18,
                    ),
                    label: Text(_openOnly ? 'Nur offene' : 'Alle'),
                    onPressed: () {
                      setState(() => _openOnly = !_openOnly);
                      unawaited(_load());
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _entries.isEmpty
                  ? _Empty(
                      loaded: _loaded,
                      searching: _search.text.trim().isNotEmpty,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                      itemCount: _entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return _EntryTile(
                          entry: entry,
                          onTap: () => _open(entry),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _summary(int total) {
    if (!_loaded) return 'Ich hole deine Vorgänge …';
    if (total == 0) return 'Noch nichts aufgezeichnet.';

    final shown = _entries.length;
    return shown == 1 ? '1 Vorgang' : '$shown Vorgänge';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.id,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count = 0,
  });

  final String id;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: Key('history_filter_$id'),
      label: Text(count == 0 ? label : '$label · $count'),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Ein Vorgang in der Liste.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final HistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Erledigtes tritt zurück, statt durchgestrichen zu werden: Es ist fertig,
    // nicht falsch.
    final faded = !entry.isOpen;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('history_item_${entry.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                HistoryLabels.featureIcon(entry.feature),
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // Ein Vorgang ohne Titel ist ein Fehlstart aus einem
                      // abgebrochenen Ablauf. Er wird benannt, nicht versteckt.
                      entry.title.trim().isEmpty
                          ? 'Ohne Titel'
                          : entry.title.trim(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: faded
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        HistoryLabels.feature(entry.feature),
                        HistoryLabels.status(entry.status),
                        HistoryLabels.moment(entry.updatedAt),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (entry.contact != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.contact!,
                        style: theme.textTheme.bodySmall?.copyWith(
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

class _Empty extends StatelessWidget {
  const _Empty({required this.loaded, required this.searching});

  final bool loaded;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Kein Ladekringel: Der Zugriff dauert Millisekunden und flackert nur.
    final text = !loaded
        ? 'Einen Moment …'
        : searching
        ? 'Dazu finde ich nichts. Vielleicht stand es unter einem anderen '
              'Stichwort.'
        : 'Hier landet alles, was du mit mir angehst – Anrufe, Termine, '
              'Nachrichten, Aufgaben. Noch ist nichts da.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          text,
          key: const Key('history_empty'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
