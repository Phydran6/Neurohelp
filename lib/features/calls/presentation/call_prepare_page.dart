import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/ai_suggestions.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/call_plan.dart';
import 'call_active_page.dart';

/// Den Anruf vorbereiten (Konzept, Abschnitt 8, Schritte 3 bis 5).
///
/// Ziel und Ansprechpartner leitet sonst die KI ab. Ohne KI trägt der User
/// sie selbst ein – der Ablauf bleibt derselbe, nur die Vorarbeit fehlt.
class CallPreparePage extends StatefulWidget {
  const CallPreparePage({required this.planId, super.key});

  final String planId;

  @override
  State<CallPreparePage> createState() => _CallPreparePageState();
}

class _CallPreparePageState extends State<CallPreparePage> {
  final _goal = TextEditingController();
  final _contact = TextEditingController();
  final _number = TextEditingController();
  final _point = TextEditingController();
  final _pointFocus = FocusNode();

  CallPlan? _plan;
  List<String> _points = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  @override
  void dispose() {
    _goal.dispose();
    _contact.dispose();
    _number.dispose();
    _point.dispose();
    _pointFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final plan = await AppScope.of(context).calls.byId(widget.planId);
    if (!mounted || plan == null) return;

    setState(() {
      _plan = plan;
      _goal.text = plan.goal ?? '';
      _contact.text = plan.contactName ?? '';
      _number.text = plan.contactNumber ?? '';
      _points = List.of(plan.talkingPoints);
      _loading = false;
    });
  }

  void _addPoint() {
    final text = _point.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _points.add(text);
      _point.clear();
    });
    _pointFocus.requestFocus();
  }

  void _addPoints(Iterable<String> texts) {
    setState(() {
      for (final text in texts) {
        if (!_points.contains(text)) _points.add(text);
      }
    });
  }

  /// Was die KI zum Vorbereiten braucht: Kategorie und, falls schon da, das
  /// Ziel und der Ansprechpartner.
  String? _prepareInput() {
    final plan = _plan;
    if (plan == null) return null;

    final goal = _goal.text.trim();
    final contact = _contact.text.trim();

    return [
      'Kategorie: ${plan.category}',
      if (goal.isNotEmpty) 'Ziel: $goal',
      if (contact.isNotEmpty) 'Ansprechpartner: $contact',
    ].join('\n');
  }

  /// Übernimmt einen kompletten Vorschlag.
  ///
  /// Der Backend-Prompt liefert erst das Ziel, dann den Ansprechpartner, dann
  /// die Stichpunkte. Leere Felder werden gefüllt, ausgefüllte bleiben stehen
  /// – überschrieben wird nichts, was der User selbst getippt hat.
  void _acceptAll(List<String> lines) {
    if (lines.isEmpty) return;

    setState(() {
      if (_goal.text.trim().isEmpty) _goal.text = lines.first;
      if (lines.length > 1 && _contact.text.trim().isEmpty) {
        _contact.text = lines[1];
      }
    });
    _addPoints(lines.skip(lines.length > 1 ? 2 : 1));
  }

  bool get _ready => _number.text.trim().isNotEmpty && _points.isNotEmpty;

  Future<void> _start() async {
    final plan = _plan;
    if (plan == null || !_ready) return;

    final services = AppScope.of(context);
    final saved = await services.calls.save(
      plan.copyWith(
        goal: _goal.text.trim(),
        contactName: _contact.text.trim(),
        contactNumber: _number.text.trim(),
        talkingPoints: _points,
      ),
    );

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => CallActivePage(planId: saved.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_plan?.category ?? 'Anruf')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          TextField(
                            key: const Key('call_goal'),
                            controller: _goal,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Was willst du erreichen?',
                              hintText:
                                  'Zum Beispiel: Termin für einen Sehtest',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            key: const Key('call_contact'),
                            controller: _contact,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Wen rufst du an?',
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            key: const Key('call_number'),
                            controller: _number,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Nummer',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Was willst du sagen?',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stichpunkte, kein Text zum Ablesen.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('call_point_field'),
                            controller: _point,
                            focusNode: _pointFocus,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Ein Stichpunkt',
                              suffixIcon: IconButton(
                                key: const Key('call_point_add'),
                                icon: const Icon(Icons.add),
                                onPressed: _addPoint,
                              ),
                            ),
                            onSubmitted: (_) => _addPoint(),
                          ),
                          // Der Moment der KI-Hilfe (Konzept, Abschnitt 8,
                          // Schritte 3 bis 5): Ziel, Ansprechpartner und ein
                          // Leitfaden als Vorschlag – kein Skript zum Ablesen.
                          AiSuggestionBox(
                            task: AiTask.prepareCall,
                            inputBuilder: _prepareInput,
                            onAccept: (suggestion) => _addPoints([suggestion]),
                            onAcceptAll: _acceptAll,
                          ),
                          for (var i = 0; i < _points.length; i++)
                            ListTile(
                              key: Key('call_point_$i'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.circle_outlined,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(_points[i]),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _points.removeAt(i)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BigActionButton(
                      key: const Key('call_ready'),
                      label: 'Bereit',
                      onPressed: _ready ? _start : null,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
