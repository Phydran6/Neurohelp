import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/calendar/calendar_service.dart';
import '../../../core/calendar/ics.dart';
import '../../../core/di/app_services.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/appointment.dart';

/// Den gebuchten Termin eintragen (Konzept, Abschnitt 9).
///
/// Erst wenn er steht, beginnt die Nachverfolgung. Die Checkliste ist das,
/// was in der Erinnerung am Vortag auftaucht.
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

  Appointment? _appointment;
  DateTime? _startsAt;
  final List<String> _checklist = [];
  bool _loading = true;
  String? _note;

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
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt ?? now),
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
  }

  Future<void> _save() async {
    final startsAt = _startsAt;
    if (startsAt == null) return;

    await AppScope.of(context).appointments.markBooked(
      widget.appointmentId,
      startsAt: startsAt,
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      checklist: List.of(_checklist),
    );

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
                        children: [
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
                                  : _format(startsAt),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            key: const Key('appt_location'),
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
                            controller: _item,
                            focusNode: _itemFocus,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Zum Beispiel: Versichertenkarte',
                              suffixIcon: IconButton(
                                key: const Key('appt_item_add'),
                                icon: const Icon(Icons.add),
                                onPressed: _addItem,
                              ),
                            ),
                            onSubmitted: (_) => _addItem(),
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
                      label: 'Termin steht',
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

  static String _format(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year}, '
        '${two(value.hour)}:${two(value.minute)} Uhr';
  }
}
