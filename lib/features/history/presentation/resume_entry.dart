import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../core/history/domain/history_entry.dart';
import '../../appointments/domain/appointment.dart';
import '../../appointments/presentation/appointment_book_page.dart';
import '../../appointments/presentation/appointment_route_page.dart';
import '../../calls/presentation/call_active_page.dart';
import '../../calls/presentation/call_prepare_page.dart';
import '../../messages/presentation/message_compose_page.dart';
import '../../tasks/presentation/task_focus_page.dart';
import '../../tasks/presentation/task_steps_page.dart';

/// Warum es nicht weitergeht.
///
/// Nur zwei Gründe, und beide sind erklärbar. Ein stummer Knopf wäre der
/// dritte und der schlimmste.
enum ResumeBlock {
  /// Zum Vorgang gehört kein Ablauf mehr – gelöscht oder nie einer gewesen.
  nothingToOpen,

  /// Der Vorgang ist abgeschlossen. Es gibt nichts weiterzumachen.
  alreadyDone,
}

/// Springt aus der Historie **direkt** in den Ablauf zurück.
///
/// **Das war die Lücke.** Die Historie konnte einen Vorgang zeigen und seinen
/// Zustand ändern – mehr nicht. Wer dort seine angefangene Aufgabe
/// wiederfand, stand vor einem Protokoll und musste den Ablauf von vorn
/// suchen. Für eine App, deren ganzer Sinn „du musst dir nichts merken" ist,
/// war das der falsche Weg: Erinnern ohne Weitermachen hilft niemandem.
///
/// Hier steht die eine Zuordnung von Vorgang zu Bildschirm. An einer Stelle,
/// weil sie an fünf Stellen gebraucht wird – Historie-Liste, Historie-Detail
/// und der Historie-Check am Anfang jedes Features.
abstract final class ResumeEntry {
  /// Ob es sich lohnt, überhaupt einen Knopf anzubieten.
  ///
  /// Nur bei offenen Vorgängen. Einen erledigten wieder aufzumachen ist eine
  /// eigene Entscheidung und steht im Detail als eigener Knopf.
  static bool isPossible(HistoryEntry entry) => entry.isOpen;

  /// Öffnet den passenden Bildschirm.
  ///
  /// Liefert `null`, wenn es geklappt hat, sonst den Grund. Der Aufrufer
  /// zeigt ihn an – kein stummer Knopf.
  static Future<ResumeBlock?> open(
    BuildContext context,
    HistoryEntry entry,
  ) async {
    if (!entry.isOpen) return ResumeBlock.alreadyDone;

    final services = AppScope.of(context);
    final route = await _routeFor(services, entry);
    if (route == null) return ResumeBlock.nothingToOpen;
    if (!context.mounted) return null;

    await Navigator.of(context).push(route);
    return null;
  }

  /// Welcher Bildschirm zu welchem Vorgang gehört.
  ///
  /// Innerhalb eines Features hängt das am Fortschritt: Ein Termin ohne
  /// entschiedenen Weg gehört auf die Wegauswahl, einer mit auf das
  /// Eintragen. Sonst landet der User auf einem Bildschirm, den er schon
  /// hinter sich hatte.
  static Future<MaterialPageRoute<void>?> _routeFor(
    AppServices services,
    HistoryEntry entry,
  ) async {
    switch (entry.feature) {
      case HistoryFeature.task:
        final tree = await services.tasks.loadTree(entry.id);
        // Eine Aufgabe ohne Schritte ist beim Anlegen abgebrochen worden.
        // Dann gehört sie ans Zerlegen, nicht in den Fokus – der hätte
        // nichts zu zeigen.
        if (tree.isEmpty) {
          return MaterialPageRoute<void>(
            builder: (_) =>
                TaskStepsPage(entryId: entry.id, initialTitle: entry.title),
          );
        }
        return MaterialPageRoute<void>(
          builder: (_) => TaskFocusPage(entryId: entry.id, title: entry.title),
        );

      case HistoryFeature.message:
        final draft = await services.messages.byEntryId(entry.id);
        if (draft == null) return null;
        return MaterialPageRoute<void>(
          builder: (_) => MessageComposePage(draft: draft),
        );

      case HistoryFeature.call:
        final plan = await services.calls.byEntryId(entry.id);
        if (plan == null) return null;
        // Wurde schon gewählt, steht der Leitfaden an; sonst wird er erst
        // noch vorbereitet.
        return MaterialPageRoute<void>(
          builder: (_) => plan.calledAt != null
              ? CallActivePage(planId: plan.id)
              : CallPreparePage(planId: plan.id),
        );

      case HistoryFeature.appointment:
        final appointment = await services.appointments.byEntryId(entry.id);
        if (appointment == null) return null;
        return MaterialPageRoute<void>(
          builder: (_) => appointment.route == BookingRoute.undecided
              ? AppointmentRoutePage(appointmentId: appointment.id)
              : AppointmentBookPage(appointmentId: appointment.id),
        );
    }
  }

  /// Der Satz zu einem Grund. Ruhig, ohne Schuld, mit dem, was jetzt geht.
  static String describe(ResumeBlock block) => switch (block) {
    ResumeBlock.nothingToOpen =>
      'Zu diesem Vorgang gibt es nichts mehr zum Weitermachen – nur noch '
          'das Protokoll darunter.',
    ResumeBlock.alreadyDone =>
      'Der ist schon erledigt. Wenn doch noch etwas offen ist, mach ihn '
          'unten wieder auf.',
  };

  /// Was auf dem Knopf steht – je Feature das Verb des Ablaufs.
  static String labelFor(HistoryFeature feature) => switch (feature) {
    HistoryFeature.task => 'Weiter an der Aufgabe',
    HistoryFeature.message => 'Weiter an der Nachricht',
    HistoryFeature.call => 'Weiter mit dem Anruf',
    HistoryFeature.appointment => 'Weiter mit dem Termin',
  };
}
