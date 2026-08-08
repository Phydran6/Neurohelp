/// Wie der Termin gebucht wird (Konzept, Abschnitt 9, Schritt 1).
///
/// Die KI schlägt einen Weg vor, der User kann jederzeit überstimmen.
enum BookingRoute {
  /// Noch nicht entschieden.
  undecided,

  /// Übergibt an das Anruf-Feature.
  phone,

  /// Online-Buchung mit Live-Begleitung.
  online,

  /// Übergibt an das Nachricht-Feature.
  mail,

  /// Kontaktformular – übergibt ebenfalls an das Nachricht-Feature.
  webForm,
}

/// Ein Termin in Arbeit oder gebucht.
///
/// **V1-Scope:** nur Neuorganisation. Kein Umbuchen, kein Verschieben, kein
/// Termin-Chaos sortieren (Konzept, Abschnitt 9).
class Appointment {
  const Appointment({
    required this.id,
    required this.entryId,
    required this.title,
    required this.createdAt,
    this.route = BookingRoute.undecided,
    this.routeSuggestedByAi = false,
    this.startsAt,
    this.endsAt,
    this.location,
    this.checklist = const [],
    this.notifiedPhases = const {},
    this.bookedAt,
  });

  final String id;
  final String entryId;

  final String title;

  final BookingRoute route;

  /// Ob der Weg von der KI vorgeschlagen wurde. Nur fürs Protokoll – der
  /// User entscheidet so oder so.
  final bool routeSuggestedByAi;

  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? location;

  /// Was mitzubringen ist. Kommt in der Erinnerung am Tag davor.
  final List<String> checklist;

  /// Welche Nachverfolgungs-Phasen schon gemeldet wurden.
  ///
  /// **Höchstens eine Benachrichtigung pro Phase** – deshalb wird das
  /// mitgeschrieben und nicht neu berechnet.
  final Set<FollowUpPhase> notifiedPhases;

  final DateTime createdAt;
  final DateTime? bookedAt;

  bool get isBooked => bookedAt != null && startsAt != null;

  /// Ob dieser Weg an ein anderes Feature übergibt.
  bool get delegatesToCall => route == BookingRoute.phone;

  bool get delegatesToMessage =>
      route == BookingRoute.mail || route == BookingRoute.webForm;

  Appointment copyWith({
    String? title,
    BookingRoute? route,
    bool? routeSuggestedByAi,
    DateTime? startsAt,
    DateTime? endsAt,
    String? location,
    List<String>? checklist,
    Set<FollowUpPhase>? notifiedPhases,
    DateTime? bookedAt,
  }) {
    return Appointment(
      id: id,
      entryId: entryId,
      title: title ?? this.title,
      route: route ?? this.route,
      routeSuggestedByAi: routeSuggestedByAi ?? this.routeSuggestedByAi,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      location: location ?? this.location,
      checklist: checklist ?? this.checklist,
      notifiedPhases: notifiedPhases ?? this.notifiedPhases,
      createdAt: createdAt,
      bookedAt: bookedAt ?? this.bookedAt,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'entry_id': entryId,
    'title': title,
    'route': route.name,
    'route_by_ai': routeSuggestedByAi ? 1 : 0,
    'starts_at': startsAt?.millisecondsSinceEpoch,
    'ends_at': endsAt?.millisecondsSinceEpoch,
    'location': location,
    'checklist': checklist.join('\n'),
    'notified_phases': notifiedPhases.map((p) => p.name).join(','),
    'created_at': createdAt.millisecondsSinceEpoch,
    'booked_at': bookedAt?.millisecondsSinceEpoch,
  };

  static Appointment fromRow(Map<String, Object?> row) {
    final rawChecklist = (row['checklist'] as String?) ?? '';
    final rawPhases = (row['notified_phases'] as String?) ?? '';

    return Appointment(
      id: row['id']! as String,
      entryId: row['entry_id']! as String,
      title: row['title']! as String,
      route: BookingRoute.values.firstWhere(
        (value) => value.name == row['route'],
      ),
      routeSuggestedByAi: (row['route_by_ai'] as int?) == 1,
      startsAt: _date(row['starts_at']),
      endsAt: _date(row['ends_at']),
      location: row['location'] as String?,
      checklist: rawChecklist.isEmpty
          ? const []
          : rawChecklist.split('\n').where((line) => line.isNotEmpty).toList(),
      notifiedPhases: rawPhases.isEmpty
          ? const {}
          : rawPhases
                .split(',')
                .where((name) => name.isNotEmpty)
                .map(
                  (name) => FollowUpPhase.values.firstWhere(
                    (phase) => phase.name == name,
                  ),
                )
                .toSet(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at']! as int),
      bookedAt: _date(row['booked_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.fromMillisecondsSinceEpoch(value as int);
}

/// Die vier Phasen der Nachverfolgung (Konzept, Abschnitt 9, Schritt 3).
///
/// **Höchstens eine Benachrichtigung pro Phase. Keine Schuldmechanik.**
enum FollowUpPhase {
  /// Nach der Buchung: Bestätigung, Termin gespeichert.
  booked,

  /// Tag davor: Erinnerung und Checkliste – was mitnehmen?
  dayBefore,

  /// Am Tag selbst: Erinnerung und Anfahrtsinfos.
  dayOf,

  /// Danach: gelaufen? offene Punkte?
  after,
}
