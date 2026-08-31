import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/calendar/date_text.dart';
import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/history_check.dart';
import '../../../shared/widgets/recall_entry.dart';
import '../../../shared/widgets/text_context_menu.dart';
import '../domain/appointment.dart';
import 'appointment_book_page.dart';
import 'appointment_route_page.dart';

/// Der Einstieg in „Termin klären" (Konzept, Abschnitt 9).
///
/// Zeigt zuerst, was ansteht: fällige Erinnerungen und Nachfragen, danach
/// die angefangenen und die schon gebuchten Termine. Erst dann die
/// Möglichkeit, einen neuen Termin anzulegen.
///
/// Die gebuchten stehen bewusst mit da. Vorher verschwanden sie mit dem
/// Speichern, und wer hinterher noch wusste, was er mitnehmen muss, kam an
/// den Eintrag nicht mehr heran.
class AppointmentStartPage extends StatefulWidget {
  const AppointmentStartPage({super.key});

  @override
  State<AppointmentStartPage> createState() => _AppointmentStartPageState();
}

class _AppointmentStartPageState extends State<AppointmentStartPage> {
  final _title = TextEditingController();

  List<({Appointment appointment, FollowUpPhase phase})> _due = const [];
  List<Appointment> _unbooked = const [];
  List<Appointment> _upcoming = const [];
  HistoryCheckState _check = HistoryCheckState.running;
  bool _loading = true;

  /// Der Einstieg in einen **neuen** Termin – derselbe wie überall: erst die
  /// Frage, dann das Feld.
  RecallMode _mode = RecallMode.asking;
  List<HistoryEntry> _found = const [];
  HistoryCheckState _recallCheck = HistoryCheckState.running;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appointments = AppScope.of(context).appointments;
    final due = await appointments.pendingNotifications();
    final unbooked = await appointments.unbooked();
    final upcoming = await appointments.upcoming();
    if (!mounted) return;

    // Was oben schon als Erinnerung steht, kommt unten nicht noch einmal.
    final dueIds = due.map((entry) => entry.appointment.id).toSet();

    setState(() {
      _due = due;
      _unbooked = unbooked;
      _upcoming = upcoming
          .where((appointment) => !dueIds.contains(appointment.id))
          .toList();
      _loading = false;
      _check = due.isEmpty && unbooked.isEmpty && _upcoming.isEmpty
          ? HistoryCheckState.empty
          : HistoryCheckState.found;
    });
  }

  /// Weitermachen, wo der Ablauf abgebrochen wurde.
  ///
  /// Immer über die Wahl des Weges – auch wenn der schon feststand. Vorher
  /// ging es von hier direkt ins Eintragen: Wer das Telefonat abgebrochen
  /// hatte, kam über die App nicht mehr an den Anruf heran, weil die App
  /// annahm, er habe schon angerufen.
  Future<void> _resume(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentRoutePage(appointmentId: appointment.id),
      ),
    );
    if (mounted) unawaited(_load());
  }

  /// Einen Termin öffnen, der schon steht – zum Nachtragen und Ändern.
  Future<void> _open(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentBookPage(appointmentId: appointment.id),
      ),
    );
    if (mounted) unawaited(_load());
  }

  Future<void> _acknowledge(
    Appointment appointment,
    FollowUpPhase phase,
  ) async {
    final services = AppScope.of(context);
    await services.appointments.markPhaseNotified(appointment.id, phase);
    if (mounted) unawaited(_load());
  }

  Future<void> _answerAfter(
    Appointment appointment, {
    required bool wentWell,
  }) async {
    final services = AppScope.of(context);
    await services.appointments.markPhaseNotified(
      appointment.id,
      FollowUpPhase.after,
    );
    await services.appointments.finish(appointment.id, wentWell: wentWell);
    if (mounted) unawaited(_load());
  }

  /// „Warte mal, ich schau kurz für dich." Erst gräbt die App.
  Future<void> _digIntoHistory() async {
    setState(() {
      _mode = RecallMode.helping;
      _recallCheck = HistoryCheckState.running;
      _found = const [];
    });

    final entries = await AppScope.of(
      context,
    ).history.recentEntries(feature: HistoryFeature.appointment, limit: 8);
    if (!mounted) return;

    setState(() {
      _found = entries;
      _recallCheck = entries.isEmpty
          ? HistoryCheckState.empty
          : HistoryCheckState.found;
    });
  }

  /// Ein Fund wird zum Thema des neuen Termins – der alte Vorgang bleibt.
  void _takeFromHistory(HistoryEntry entry) {
    setState(() {
      _mode = RecallMode.typing;
      _title.text = entry.title;
    });
  }

  Future<void> _startNew() async {
    final typed = _title.text.trim();
    // Wer ausdrücklich gesagt hat, dass er es nicht weiß, kommt trotzdem
    // weiter. Das Thema wird beim Klären nachgetragen.
    if (typed.isEmpty && _mode != RecallMode.helping) return;
    final title = typed.isEmpty ? kUnknownTopic : typed;

    final services = AppScope.of(context);
    final appointment = await services.appointments.create(title);
    if (!mounted) return;

    _title.clear();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentRoutePage(appointmentId: appointment.id),
      ),
    );
    if (mounted) unawaited(_load());
  }

  /// Der Einstieg: entweder die Frage „Weißt du es noch?" oder das Feld mit
  /// dem großen Knopf. Steht an zwei Stellen – unten unter der Liste, oder
  /// mittig, wenn es nichts zu listen gibt.
  Widget _entry(ThemeData theme) {
    if (_mode == RecallMode.asking) {
      return RecallChoice(
        prefix: 'appt',
        onKnow: () => setState(() => _mode = RecallMode.typing),
        onHelp: () => unawaited(_digIntoHistory()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mode == RecallMode.helping) ...[
          // Was die App gefunden hat, kommt vor dem Feld.
          RecallPanel(
            prefix: 'appt',
            state: _recallCheck,
            hits: _found,
            nudges: RecallNudges.appointment,
            onPick: _takeFromHistory,
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          key: const Key('appt_title'),
          contextMenuBuilder: noScanContextMenu,
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Worum geht es?',
            hintText: 'Zum Beispiel: Sehtest beim Optiker',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _startNew(),
        ),
        const SizedBox(height: 16),
        // Im Historie-Weg geht es immer weiter, auch mit leerem Feld.
        BigActionButton(
          key: const Key('appt_new'),
          label: _mode == RecallMode.helping && _title.text.trim().isEmpty
              ? 'Weiter, ich weiß es noch nicht'
              : 'Weiter',
          onPressed: _title.text.trim().isEmpty && _mode != RecallMode.helping
              ? null
              : _startNew,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSomething =
        _due.isNotEmpty || _unbooked.isNotEmpty || _upcoming.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Termin klären')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HistoryCheckHeader(state: _check),
                    if (hasSomething)
                      Expanded(
                        child: ListView(
                          children: [
                            for (final entry in _due) ...[
                              _PhaseCard(
                                appointment: entry.appointment,
                                phase: entry.phase,
                                onAcknowledge: () => _acknowledge(
                                  entry.appointment,
                                  entry.phase,
                                ),
                                onAnswer: ({required bool wentWell}) =>
                                    _answerAfter(
                                      entry.appointment,
                                      wentWell: wentWell,
                                    ),
                                onEdit: () => _open(entry.appointment),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_unbooked.isNotEmpty) ...[
                              Text(
                                'Angefangen, noch nicht gebucht',
                                key: const Key('appt_unbooked_title'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final appointment in _unbooked) ...[
                                _AppointmentTile(
                                  keyPrefix: 'appt_unbooked',
                                  appointment: appointment,
                                  onTap: () => _resume(appointment),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                            if (_upcoming.isNotEmpty) ...[
                              if (_unbooked.isNotEmpty)
                                const SizedBox(height: 16),
                              Text(
                                'Termine, die stehen',
                                key: const Key('appt_upcoming_title'),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final appointment in _upcoming) ...[
                                _AppointmentTile(
                                  keyPrefix: 'appt_upcoming',
                                  appointment: appointment,
                                  subtitle: appointment.startsAt == null
                                      ? null
                                      : DateText.dateTime(
                                          appointment.startsAt!,
                                        ),
                                  onTap: () => _open(appointment),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ],
                        ),
                      ),
                    if (hasSomething) ...[
                      const SizedBox(height: 16),
                      _entry(theme),
                    ] else
                      // Nichts zu zeigen: Der Einstieg steht mittig. Wenn er
                      // bei großer Schrift nicht mehr aufs Blatt passt, rollt
                      // er – vorher lief er unten aus dem Bild, und der Knopf
                      // „Weiter" war nicht mehr zu erreichen. Bei doppelter
                      // Schriftgröße fehlten über 700 Pixel.
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, viewport) => SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: viewport.maxHeight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [_entry(theme)],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Ein Termin in der Liste – angefangen oder schon gebucht.
class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.keyPrefix,
    required this.appointment,
    required this.onTap,
    this.subtitle,
  });

  /// Vorsilbe des Widget-Schlüssels – `appt_unbooked` oder `appt_upcoming`.
  final String keyPrefix;

  final Appointment appointment;

  /// Bei gebuchten Terminen steht hier, wann es soweit ist.
  final String? subtitle;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('${keyPrefix}_${appointment.id}'),
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
                    Text(appointment.title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
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

/// Eine fällige Phase der Nachverfolgung.
///
/// Höchstens eine Benachrichtigung pro Phase – deshalb verschwindet die
/// Karte, sobald sie zur Kenntnis genommen wurde.
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.appointment,
    required this.phase,
    required this.onAcknowledge,
    required this.onAnswer,
    required this.onEdit,
  });

  final Appointment appointment;
  final FollowUpPhase phase;
  final VoidCallback onAcknowledge;
  final void Function({required bool wentWell}) onAnswer;

  /// Den Termin öffnen, um etwas nachzutragen. Genau hier fällt einem ein,
  /// was noch fehlt – die Karte fragt ja danach.
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: Key('appt_phase_${appointment.id}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appointment.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            _text(),
            key: const Key('appt_phase_text'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (phase == FollowUpPhase.dayBefore &&
              appointment.checklist.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final item in appointment.checklist)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('· $item', style: theme.textTheme.bodyMedium),
              ),
          ],
          const SizedBox(height: 16),
          if (phase == FollowUpPhase.after)
            Row(
              children: [
                FilledButton(
                  key: Key('appt_went_well_${appointment.id}'),
                  onPressed: () => onAnswer(wentWell: true),
                  child: const Text('Ja'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  key: Key('appt_open_points_${appointment.id}'),
                  onPressed: () => onAnswer(wentWell: false),
                  child: const Text('Es ist noch was offen'),
                ),
              ],
            )
          else
            Row(
              children: [
                TextButton(
                  key: Key('appt_ack_${appointment.id}'),
                  onPressed: onAcknowledge,
                  child: const Text('Alles klar'),
                ),
                TextButton(
                  key: Key('appt_edit_${appointment.id}'),
                  onPressed: onEdit,
                  child: const Text('Etwas nachtragen'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _text() => switch (phase) {
    FollowUpPhase.booked => 'Der Termin ist gespeichert.',
    FollowUpPhase.dayBefore => 'Morgen ist es soweit. Das brauchst du:',
    FollowUpPhase.dayOf =>
      'Heute ist der Termin${appointment.location == null ? '' : ' – '
                '${appointment.location}'}.',
    FollowUpPhase.after => 'Ist der Termin gelaufen?',
  };
}
