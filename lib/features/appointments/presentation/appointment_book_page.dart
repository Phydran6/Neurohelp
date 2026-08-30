import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/calendar/calendar_service.dart';
import '../../../core/calendar/date_text.dart';
import '../../../core/calendar/ics.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/text_context_menu.dart';
import '../domain/appointment.dart';

/// Den gebuchten Termin eintragen – und später nachbessern (Konzept,
/// Abschnitt 9).
///
/// Erst wenn er steht, beginnt die Nachverfolgung. Die Checkliste ist das,
/// was in der Erinnerung am Vortag auftaucht.
///
/// Dieselbe Seite öffnet sich auch für einen Termin, der schon steht. Was
/// man mitnehmen muss, weiß man selten beim Eintragen – vorher war der
/// Eintrag danach zu; wer es später wusste, kam nicht mehr heran. Ein
/// Umbuchen ist das nicht: Beim Arzt ändert sich davon nichts.
class AppointmentBookPage extends StatefulWidget {
  const AppointmentBookPage({required this.appointmentId, super.key});

  final String appointmentId;

  @override
  State<AppointmentBookPage> createState() => _AppointmentBookPageState();
}

class _AppointmentBookPageState extends State<AppointmentBookPage> {
  final _location = TextEditingController();
  final _item = TextEditingController();
  final _itemFocus = FocusNode();
  final _scroll = ScrollController();

  Appointment? _appointment;
  DateTime? _startsAt;
  final List<String> _checklist = [];
  bool _loading = true;
  String? _note;

  /// Ob der Termin schon steht. Dann heißt Speichern „ändern", nicht
  /// „buchen".
  bool get _isEditing => _appointment?.isBooked ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) unawaited(_load());
  }

  @override
  void dispose() {
    _location.dispose();
    _item.dispose();
    _itemFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appointment = await AppScope.of(
      context,
    ).appointments.byId(widget.appointmentId);
    if (!mounted) return;

    // Auch ohne Termin fertig laden: Vorher blieb `_loading` in diesem Fall
    // für immer stehen und der User sah einen leeren Bildschirm ohne
    // Erklärung und ohne Ausweg.
    setState(() {
      _appointment = appointment;
      _startsAt = appointment?.startsAt;
      _location.text = appointment?.location ?? '';
      if (appointment != null) _checklist.addAll(appointment.checklist);
      _loading = false;
    });
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final start = _startsAt;

    // Der Wähler verträgt kein Datum vor seiner eigenen Untergrenze. Bei
    // einem Termin, der schon vorbei ist, muss die Grenze also mitgehen –
    // sonst bricht das Nachtragen ab, statt sich zu öffnen.
    var firstDate = now.subtract(const Duration(days: 1));
    if (start != null && start.isBefore(firstDate)) firstDate = start;

    final date = await showDatePicker(
      context: context,
      initialDate: start ?? now,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'An welchem Tag?',
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start ?? now),
      helpText: 'Um wie viel Uhr?',
    );
    if (time == null || !mounted) return;

    setState(() {
      _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _addItem() {
    final text = _item.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _checklist.add(text);
      _item.clear();
    });
    _itemFocus.requestFocus();

    // Ans Ende scrollen, sonst landet der frisch eingetragene Punkt hinter
    // der Tastatur und es sieht aus, als wäre nichts passiert.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _save() async {
    final startsAt = _startsAt;
    if (startsAt == null) return;

    final appointments = AppScope.of(context).appointments;
    final location = _location.text.trim().isEmpty
        ? null
        : _location.text.trim();

    // Ein Termin wird nur einmal gebucht. Danach ist Speichern ein
    // Nachtragen – die Nachverfolgung läuft weiter, statt von vorn zu
    // beginnen.
    if (_isEditing) {
      await appointments.updateBooking(
        widget.appointmentId,
        startsAt: startsAt,
        location: location,
        checklist: List.of(_checklist),
      );
    } else {
      await appointments.markBooked(
        widget.appointmentId,
        startsAt: startsAt,
        location: location,
        checklist: List.of(_checklist),
      );
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Den Termin als `.ics` herausgeben (Konzept, Abschnitt 8, Schritt 7).
  ///
  /// Der Weg ohne Kalenderzugriff: Die Datei kennt die anderen Termine nicht
  /// und prüft deshalb nichts auf Kollisionen – dafür funktioniert sie mit
  /// jedem Kalender, auch mit dem, den die App nicht kennt.
  Future<void> _exportIcs() async {
    final startsAt = _startsAt;
    final appointment = _appointment;
    if (startsAt == null || appointment == null) return;

    final services = AppScope.of(context);
    final event = CalendarEvent(
      title: appointment.title,
      start: startsAt,
      end: startsAt.add(const Duration(hours: 1)),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      description: _checklist.isEmpty
          ? null
          : 'Mitnehmen: ${_checklist.join(', ')}',
    );

    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      await services.files.save(
        fileName: 'termin.ics',
        content: IcsExporter.export(event),
        mimeType: 'text/calendar',
        subject: appointment.title,
        origin: origin,
      );
      if (!mounted) return;
      setState(() => _note = 'Termin ist raus – such dir deinen Kalender aus.');
    } on Exception {
      if (!mounted) return;
      setState(
        () => _note =
            'Das Herausgeben hat nicht geklappt. Der Termin ist trotzdem hier '
            'gespeichert.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startsAt = _startsAt;

    return Scaffold(
      appBar: AppBar(title: Text(_appointment?.title ?? 'Termin')),
      body: SafeArea(
        child: _loading
            ? const SizedBox.shrink()
            : _appointment == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Diesen Termin gibt es nicht mehr.',
                    key: const Key('appt_missing'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ListView(
                        controller: _scroll,
                        children: [
                          if (_isEditing) ...[
                            Text(
                              'Der Termin steht. Hier kannst du nachtragen, '
                              'was du inzwischen weißt.',
                              key: const Key('appt_edit_hint'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            'Wann ist der Termin?',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            key: const Key('appt_pick_time'),
                            onPressed: _pickDateTime,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              startsAt == null
                                  ? 'Datum und Uhrzeit wählen'
                                  // Mit Wochentag: Im Kalenderblatt liegt
                                  // der Sonntag neben dem Montag, und ein
                                  // Griff daneben fällt sonst erst am
                                  // falschen Tag auf.
                                  : DateText.dateTime(startsAt),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            key: const Key('appt_location'),
                            contextMenuBuilder: noScanContextMenu,
                            controller: _location,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(labelText: 'Wo?'),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Was musst du mitnehmen?',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Daran erinnere ich dich am Tag davor.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('appt_item_field'),
                            contextMenuBuilder: noScanContextMenu,
                            controller: _item,
                            focusNode: _itemFocus,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Zum Beispiel: Versichertenkarte',
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _addItem(),
                          ),
                          const SizedBox(height: 8),
                          // Beschrifteter Knopf statt eines kleinen Pluses
                          // im Feld: Das Plus war da, aber niemand hat es
                          // als „hinzufügen" gelesen.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const Key('appt_item_add'),
                              onPressed: _item.text.trim().isEmpty
                                  ? null
                                  : _addItem,
                              icon: const Icon(Icons.add, size: 20),
                              label: const Text('Punkt hinzufügen'),
                            ),
                          ),
                          for (var i = 0; i < _checklist.length; i++)
                            ListTile(
                              key: Key('appt_item_$i'),
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                Icons.circle_outlined,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(_checklist[i]),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _checklist.removeAt(i)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_note != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _note!,
                        key: const Key('appt_note'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    BigActionButton(
                      key: const Key('appt_save'),
                      label: _isEditing
                          ? 'Änderungen speichern'
                          : 'Termin steht',
                      onPressed: startsAt == null ? null : _save,
                    ),
                    // Der Weg in den eigenen Kalender, ohne der App dafür
                    // Kalenderzugriff geben zu müssen.
                    TextButton.icon(
                      key: const Key('appt_export_ics'),
                      onPressed: startsAt == null ? null : _exportIcs,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('In den Kalender übernehmen'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
