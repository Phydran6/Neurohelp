import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/history_check.dart';
import '../domain/appointment.dart';
import 'appointment_book_page.dart';
import 'appointment_route_page.dart';

/// Der Einstieg in „Termin klären" (Konzept, Abschnitt 9).
///
/// Zeigt zuerst, was ansteht: fällige Erinnerungen und Nachfragen. Erst
/// danach die Möglichkeit, einen neuen Termin anzulegen.
class AppointmentStartPage extends StatefulWidget {
  const AppointmentStartPage({super.key});

  @override
  State<AppointmentStartPage> createState() => _AppointmentStartPageState();
}

class _AppointmentStartPageState extends State<AppointmentStartPage> {
  final _title = TextEditingController();

  List<({Appointment appointment, FollowUpPhase phase})> _due = const [];
  List<Appointment> _unbooked = const [];
  HistoryCheckState _check = HistoryCheckState.running;
  bool _loading = true;

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
    if (!mounted) return;

    setState(() {
      _due = due;
      _unbooked = unbooked;
      _loading = false;
      _check = due.isEmpty && unbooked.isEmpty
          ? HistoryCheckState.empty
          : HistoryCheckState.found;
    });
  }

  /// Weitermachen, wo der Ablauf abgebrochen wurde: Steht der Weg schon
  /// fest, geht es direkt ans Eintragen.
  Future<void> _resume(Appointment appointment) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => appointment.route == BookingRoute.undecided
            ? AppointmentRoutePage(appointmentId: appointment.id)
            : AppointmentBookPage(appointmentId: appointment.id),
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

  Future<void> _startNew() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSomething = _due.isNotEmpty || _unbooked.isNotEmpty;

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
                                _UnbookedTile(
                                  appointment: appointment,
                                  onTap: () => _resume(appointment),
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
                    TextField(
                      key: const Key('appt_title'),
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
                    BigActionButton(
                      key: const Key('appt_new'),
                      label: 'Weiter',
                      onPressed: _title.text.trim().isEmpty ? null : _startNew,
                    ),
                    if (!hasSomething) const Spacer(),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Ein angefangener Termin, bei dem die Buchung noch aussteht.
class _UnbookedTile extends StatelessWidget {
  const _UnbookedTile({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('appt_unbooked_${appointment.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  appointment.title,
                  style: theme.textTheme.titleMedium,
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
  });

  final Appointment appointment;
  final FollowUpPhase phase;
  final VoidCallback onAcknowledge;
  final void Function({required bool wentWell}) onAnswer;

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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('appt_ack_${appointment.id}'),
                onPressed: onAcknowledge,
                child: const Text('Alles klar'),
              ),
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
