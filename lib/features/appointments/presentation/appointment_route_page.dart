import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../calls/presentation/call_start_page.dart';
import '../../messages/presentation/message_start_page.dart';
import '../domain/appointment.dart';
import 'appointment_book_page.dart';

/// Den Buchungsweg wählen (Konzept, Abschnitt 9, Schritt 1).
///
/// Die KI schlägt sonst einen Weg vor; der User kann ihn **jederzeit
/// überstimmen**. Ohne KI wählt er direkt.
///
/// Telefon übergibt an das Anruf-Feature, Mail und Formular an das
/// Nachricht-Feature – die Abläufe werden nicht doppelt gebaut.
class AppointmentRoutePage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            const SizedBox(height: 24),
            for (final option in options) ...[
              _RouteTile(appointmentId: appointmentId, option: option),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.appointmentId, required this.option});

  final String appointmentId;
  final ({BookingRoute route, String label, String hint}) option;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('appt_route_${option.route.name}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => _choose(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(option.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                option.hint,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final services = AppScope.of(context);
    final updated = await services.appointments.chooseRoute(
      appointmentId,
      option.route,
    );
    if (!context.mounted) return;

    // Telefon und Nachricht haben ihre eigenen Abläufe. Der Termin wartet
    // solange und wird danach eingetragen.
    final delegate = switch (option.route) {
      BookingRoute.phone => const CallStartPage(),
      BookingRoute.mail || BookingRoute.webForm => const MessageStartPage(),
      _ => null,
    };

    if (delegate != null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => delegate));
      if (!context.mounted) return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AppointmentBookPage(appointmentId: updated.id),
      ),
    );
  }
}
