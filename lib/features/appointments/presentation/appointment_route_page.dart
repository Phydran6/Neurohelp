import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ai/ai_client.dart';
import '../../../core/companion/tone_texts.dart';
import '../../../core/di/app_services.dart';
import '../../calls/presentation/call_start_page.dart';
import '../../messages/presentation/message_start_page.dart';
import '../domain/appointment.dart';
import 'appointment_book_page.dart';

/// Den Buchungsweg wählen (Konzept, Abschnitt 9, Schritt 1).
///
/// Die KI schlägt einen Weg vor; der User kann ihn **jederzeit überstimmen**.
/// Ohne KI wählt er direkt – die Liste ist dieselbe, nur ohne Markierung.
///
/// Telefon übergibt an das Anruf-Feature, Mail und Formular an das
/// Nachricht-Feature – die Abläufe werden nicht doppelt gebaut.
///
/// Auch beim Weitermachen führt der Weg hier vorbei. Wer mitten im Anruf
/// abbricht, hat den Weg zwar schon gewählt, aber noch nichts erledigt:
/// Vorher landete er direkt im Eintragen und kam an das Telefonat nicht mehr
/// heran. Jetzt steht der zuletzt gewählte Weg markiert da und lässt sich
/// noch einmal gehen – oder gegen einen anderen tauschen.
class AppointmentRoutePage extends StatefulWidget {
  const AppointmentRoutePage({required this.appointmentId, super.key});

  final String appointmentId;

  static const List<({BookingRoute route, String label, String hint})> options =
      [
        (
          route: BookingRoute.phone,
          label: 'Anrufen',
          hint: 'Ich helfe dir durchs Telefonat.',
        ),
        (
          route: BookingRoute.online,
          label: 'Online buchen',
          hint: 'Ich sage dir, was du bereithalten solltest.',
        ),
        (
          route: BookingRoute.mail,
          label: 'Mail schreiben',
          hint: 'Ich formuliere die Nachricht mit dir.',
        ),
        (
          route: BookingRoute.webForm,
          label: 'Kontaktformular',
          hint: 'Ich bereite den Text vor, du fügst ihn ein.',
        ),
      ];

  @override
  State<AppointmentRoutePage> createState() => _AppointmentRoutePageState();
}

class _AppointmentRoutePageState extends State<AppointmentRoutePage> {
  Appointment? _appointment;

  BookingRoute? _suggested;
  String? _reason;
  bool _asking = false;
  String? _aiError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appointment == null) unawaited(_load());
  }

  Future<void> _load() async {
    final appointment = await AppScope.of(
      context,
    ).appointments.byId(widget.appointmentId);
    if (!mounted) return;
    setState(() => _appointment = appointment);
  }

  Future<void> _askAi() async {
    final appointment = _appointment;
    if (appointment == null || _asking) return;

    setState(() {
      _asking = true;
      _aiError = null;
    });

    final services = AppScope.of(context);

    try {
      final answer = await services.ai.run(
        AiTask.routeAppointment,
        input: appointment.title,
        tone: services.settings.current.tone,
      );
      if (!mounted) return;

      final lines = AiSuggestions.linesOf(answer);
      setState(() {
        _asking = false;
        _suggested = _routeOf(lines.isEmpty ? '' : lines.first);
        _reason = lines.length > 1 ? lines[1] : null;
        if (_suggested == null) {
          _aiError = 'Da kam kein klarer Weg zurück. Wähl einfach selbst.';
        }
      });
    } on AiUnavailableException catch (error) {
      if (!mounted) return;
      setState(() {
        _asking = false;
        _aiError = error.reason;
      });
    }
  }

  /// Die Beschriftung eines Weges, wie sie auch in der Liste steht.
  static String _labelOf(BookingRoute route) => AppointmentRoutePage.options
      .firstWhere((option) => option.route == route)
      .label;

  /// Der Backend-Prompt antwortet mit einem der vier Wörter. Alles andere
  /// gilt als „kein Vorschlag" – geraten wird nicht.
  static BookingRoute? _routeOf(String line) {
    final value = line.toUpperCase();
    if (value.contains('TELEFON')) return BookingRoute.phone;
    if (value.contains('ONLINE')) return BookingRoute.online;
    if (value.contains('FORMULAR')) return BookingRoute.webForm;
    if (value.contains('MAIL')) return BookingRoute.mail;
    return null;
  }

  /// Wer den Termin schon in der Hand hat, überspringt den Weg.
  ///
  /// Der Knopf steht bewusst unter der Liste und nicht darüber: Er ist der
  /// Ausweg, nicht der Vorschlag.
  Future<void> _bookDirectly() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            AppointmentBookPage(appointmentId: widget.appointmentId),
      ),
    );
  }

  Future<void> _choose(BookingRoute route) async {
    final services = AppScope.of(context);
    final updated = await services.appointments.chooseRoute(
      widget.appointmentId,
      route,
      suggestedByAi: route == _suggested,
    );
    if (!mounted) return;

    // Telefon und Nachricht haben ihre eigenen Abläufe. Der Termin wartet
    // solange und wird danach eingetragen.
    final delegate = switch (route) {
      BookingRoute.phone => const CallStartPage(),
      BookingRoute.mail || BookingRoute.webForm => const MessageStartPage(),
      _ => null,
    };

    if (delegate != null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => delegate));
      if (!mounted) return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentBookPage(appointmentId: updated.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = AppScope.of(context);
    final texts = ToneTexts(services.settings.current.tone);

    // Beim Weitermachen ist der Weg schon einmal gewählt worden. Das ist
    // keine erledigte Buchung – nur ein Anhaltspunkt.
    final chosen = _appointment?.route ?? BookingRoute.undecided;

    return Scaffold(
      appBar: AppBar(title: const Text('Termin klären')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              'Wie kommst du an den Termin?',
              key: const Key('appt_route_title'),
              style: theme.textTheme.headlineSmall,
            ),
            if (chosen != BookingRoute.undecided) ...[
              const SizedBox(height: 12),
              Text(
                'Zuletzt wolltest du das hier: ${_labelOf(chosen)}. '
                'Du kannst es noch einmal versuchen oder etwas anderes '
                'nehmen.',
                key: const Key('appt_route_again'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (services.ai.isEnabled) ...[
              if (_asking)
                Text(
                  texts.aiWorking,
                  key: const Key('appt_route_busy'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (_suggested == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const Key('appt_route_ask'),
                    onPressed: _appointment == null ? null : _askAi,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(texts.askAi),
                  ),
                ),
              if (_aiError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _aiError!,
                  key: const Key('appt_route_ai_error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            for (final option in AppointmentRoutePage.options) ...[
              _RouteTile(
                option: option,
                // Vorschlag heißt Vorschlag: markiert, nicht vorausgewählt.
                isSuggested: option.route == _suggested,
                // Genauso der zuletzt gewählte Weg: Er steht da, damit man
                // ihn wiederfindet – angeklickt wird er von Hand.
                wasChosen: option.route == chosen,
                reason: option.route == _suggested ? _reason : null,
                onTap: () => _choose(option.route),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            TextButton(
              key: const Key('appt_route_skip'),
              onPressed: _bookDirectly,
              child: const Text('Der Termin steht schon – eintragen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.option,
    required this.isSuggested,
    required this.wasChosen,
    required this.reason,
    required this.onTap,
  });

  final ({BookingRoute route, String label, String hint}) option;
  final bool isSuggested;

  /// Dieser Weg war beim letzten Mal schon gewählt – der Ablauf wurde nur
  /// nicht zu Ende gegangen.
  final bool wasChosen;

  final String? reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('appt_route_${option.route.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: isSuggested || wasChosen
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary),
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.label,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  if (isSuggested || wasChosen)
                    Text(
                      isSuggested ? 'Vorschlag' : 'Zuletzt gewählt',
                      key: Key('appt_route_badge_${option.route.name}'),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                option.hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (reason != null) ...[
                const SizedBox(height: 6),
                Text(
                  reason!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
