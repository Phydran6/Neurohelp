import 'package:flutter/material.dart';

import '../../../core/history/domain/history_entry.dart';
import '../../../core/history/domain/history_event.dart';

/// Die Historie in Worten, die auf einem Bildschirm stehen dürfen.
///
/// Die Aufzählungen im Kern heißen `handedOver` und `stepDone` – das ist für
/// den Code richtig und für den User unlesbar. Hier steht die eine
/// Übersetzung, statt in jedem Widget eine eigene.
abstract final class HistoryLabels {
  static String feature(HistoryFeature value) => switch (value) {
    HistoryFeature.call => 'Anruf',
    HistoryFeature.appointment => 'Termin',
    HistoryFeature.message => 'Nachricht',
    HistoryFeature.task => 'Aufgabe',
  };

  static IconData featureIcon(HistoryFeature value) => switch (value) {
    HistoryFeature.call => Icons.call_outlined,
    HistoryFeature.appointment => Icons.event_outlined,
    HistoryFeature.message => Icons.mail_outlined,
    HistoryFeature.task => Icons.checklist_outlined,
  };

  /// Der Zustand als Feststellung – nichts Belohnendes, nichts Mahnendes.
  static String status(HistoryStatus value) => switch (value) {
    HistoryStatus.open => 'Offen',
    HistoryStatus.active => 'Läuft',
    HistoryStatus.handedOver => 'Übergeben',
    HistoryStatus.done => 'Erledigt',
    HistoryStatus.dropped => 'Liegengelassen',
  };

  /// Was ein protokolliertes Ereignis bedeutet.
  static String event(HistoryEventKind value) => switch (value) {
    HistoryEventKind.created => 'Angefangen',
    HistoryEventKind.stepDone => 'Schritt erledigt',
    HistoryEventKind.stepAdded => 'Schritt hinzugefügt',
    HistoryEventKind.noteAdded => 'Notiz',
    HistoryEventKind.statusChanged => 'Zustand geändert',
    HistoryEventKind.handedOver => 'An die System-App übergeben',
    HistoryEventKind.followUpAsked => 'Nachgefragt',
    HistoryEventKind.followUpAnswered => 'Beantwortet',
    HistoryEventKind.closed => 'Abgeschlossen',
  };

  /// Datum und Uhrzeit, so kurz wie möglich.
  ///
  /// „Heute, 14:30" ist beim Durchsehen sofort einzuordnen; ein vollständiges
  /// Datum wäre für den Vorgang von vorhin nur Rauschen. Kein `intl`: Die App
  /// ist deutschsprachig, ein Paket für ein Datumsformat wäre zu viel.
  static String moment(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final days = _dayDifference(reference, value);

    final time = '${_two(value.hour)}:${_two(value.minute)}';
    return switch (days) {
      0 => 'Heute, $time',
      1 => 'Gestern, $time',
      _ when days > 1 && days < 7 => '${_weekday(value)}, $time',
      _ => '${_two(value.day)}.${_two(value.month)}.${value.year}, $time',
    };
  }

  /// Nur der Tag, ohne Uhrzeit – für Überschriften über einer Gruppe.
  static String day(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    return switch (_dayDifference(reference, value)) {
      0 => 'Heute',
      1 => 'Gestern',
      _ => '${_two(value.day)}.${_two(value.month)}.${value.year}',
    };
  }

  /// Ganze Tage zwischen zwei Zeitpunkten, auf Kalendertage gerechnet.
  ///
  /// Nicht über die Differenz in Stunden: 23:30 und 00:30 liegen eine Stunde
  /// auseinander und sind trotzdem „gestern" und „heute".
  static int _dayDifference(DateTime now, DateTime value) {
    final today = DateTime(now.year, now.month, now.day);
    final other = DateTime(value.year, value.month, value.day);
    return today.difference(other).inDays;
  }

  static String _weekday(DateTime value) => switch (value.weekday) {
    DateTime.monday => 'Montag',
    DateTime.tuesday => 'Dienstag',
    DateTime.wednesday => 'Mittwoch',
    DateTime.thursday => 'Donnerstag',
    DateTime.friday => 'Freitag',
    DateTime.saturday => 'Samstag',
    _ => 'Sonntag',
  };

  static String _two(int value) => value.toString().padLeft(2, '0');
}
