import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/backup/backup_service.dart';
import '../../../core/backup/backup_vault.dart';
import '../../../core/di/app_services.dart';
import '../../../core/settings/app_settings.dart';
import '../../../shared/widgets/support_contact.dart';
import '../../history/presentation/history_labels.dart';
import '../domain/backup_runner.dart';
import 'backup_outcome_box.dart';

/// Sicherung und Wiederherstellung, aus den Einstellungen heraus.
///
/// Derselbe Bildschirm in zwei Tonlagen (Konzept, Abschnitt 4):
///
/// * **[simple] true** – zwei Knöpfe. „Jetzt sichern" und „Sicherung
///   zurückholen". Dateien kommen nicht vor, der Platz wird nicht erklärt.
/// * **[simple] false** – zusätzlich: Datei selbst ablegen, Datei selbst
///   auswählen, ersetzen oder dazulegen, und die Ansage, was **nicht** in der
///   Datei steht.
///
/// Zwei getrennte Bildschirme wären zwei Orte, an denen dieselbe Zusage
/// auseinanderlaufen kann.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, this.simple = false});

  final bool simple;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;
  bool _loaded = false;

  StoredBackup? _stored;
  AppSettings _settings = const AppSettings();
  BackupOutcome? _outcome;

  /// Nur im Expertenweg: dazulegen statt ersetzen.
  RestoreMode _mode = RestoreMode.replace;

  BackupRunner get _runner => BackupRunner(AppScope.of(context));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) unawaited(_load());
  }

  Future<void> _load() async {
    final services = AppScope.of(context);
    final stored = await services.vault.latest();
    final settings = await services.settings.load();
    if (!mounted) return;

    setState(() {
      _stored = stored;
      _settings = settings;
      _loaded = true;
    });
  }

  Future<void> _run(Future<BackupOutcome?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _outcome = null;
    });

    final outcome = await action();
    if (!mounted) return;

    setState(() {
      _busy = false;
      _outcome = outcome;
    });
    await _load();
  }

  Future<void> _setAutoBackup({required bool enabled}) async {
    final updated = await AppScope.of(
      context,
    ).settings.setAutoBackup(enabled: enabled);
    if (!mounted) return;
    setState(() {
      _settings = updated;
      _outcome = BackupOutcome.done(
        enabled
            ? 'Ab jetzt sichere ich von selbst mit, wenn du etwas erledigt '
                  'hast.'
            : 'Ab jetzt sichere ich nur noch, wenn du es sagst.',
      );
    });
  }

  /// Vor dem Ersetzen einmal nachfragen – aber nur, wenn wirklich etwas da
  /// ist, das ersetzt würde.
  Future<bool> _confirmReplace() async {
    if (_mode == RestoreMode.merge) return true;

    final counts = await AppScope.of(context).history.countsByFeature();
    final total = counts.values.fold(0, (sum, entry) => sum + entry.total);
    if (total == 0 || !mounted) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Das Vorhandene ersetzen?'),
        content: Text(
          'Auf diesem Gerät liegen gerade $total Vorgänge. Beim Einspielen '
          'werden sie durch die Sicherung ersetzt.\n\n'
          'Wenn du das nicht willst: Erst „Datei erzeugen" – dann hast du '
          'den jetzigen Stand in der Hand.',
        ),
        actions: [
          TextButton(
            key: const Key('backup_replace_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Doch nicht'),
          ),
          FilledButton(
            key: const Key('backup_replace_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ersetzen'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _restoreFromVault() async {
    if (!await _confirmReplace()) return;
    await _run(() => _runner.restoreFromVault(mode: _mode));
  }

  Future<void> _restoreFromFile() async {
    if (!await _confirmReplace()) return;
    await _run(() => _runner.restoreFromPickedFile(mode: _mode));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sicherung')),
      body: SafeArea(
        child: _loaded
            ? ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  Text(
                    widget.simple
                        ? 'Damit deine Sachen eine Neuinstallation überleben.'
                        : 'Alles, was auf diesem Gerät liegt, in einer Datei '
                              '– und wieder zurück. Versionen spielen keine '
                              'Rolle: Eine alte Sicherung lässt sich in eine '
                              'neue App einspielen und umgekehrt.',
                    key: const Key('backup_intro'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_outcome != null) ...[
                    const SizedBox(height: 20),
                    BackupOutcomeBox(outcome: _outcome!),
                  ],
                  const SizedBox(height: 28),
                  ..._statusSection(theme),
                  const SizedBox(height: 32),
                  ..._backupSection(theme),
                  const SizedBox(height: 32),
                  ..._restoreSection(theme),
                  if (!widget.simple) ...[
                    const SizedBox(height: 32),
                    _whatIsNotInside(theme),
                  ],
                  const SizedBox(height: 32),
                  const SupportContact(
                    subject: 'Neurohelp – Frage zur Sicherung',
                    context_: 'Es geht um die Sicherung meiner Daten.',
                  ),
                ],
              )
            // Kein Ladekringel: Der Zugriff dauert Millisekunden.
            : const SizedBox.shrink(),
      ),
    );
  }

  List<Widget> _statusSection(ThemeData theme) {
    final stored = _stored;
    final last = _settings.lastBackupAt;

    return [
      Text('Stand', style: theme.textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        stored != null
            ? 'Zuletzt gesichert: ${HistoryLabels.moment(stored.savedAt)} '
                  '(${stored.sizeLabel}).'
            : last != null
            ? 'Zuletzt gesichert: ${HistoryLabels.moment(last)} – als Datei, '
                  'die du selbst abgelegt hast.'
            // Keine Mahnung, keine Farbe, kein Ausrufezeichen. Eine
            // Feststellung (Konzept, Abschnitt 4).
            : 'Noch nichts gesichert.',
        key: const Key('backup_status'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        key: const Key('backup_auto'),
        value: _settings.autoBackup,
        onChanged: _busy ? null : (value) => _setAutoBackup(enabled: value),
        title: const Text('Von selbst mitsichern'),
        subtitle: const Text(
          'Nebenbei, ohne Meldung. Die Datei bleibt auf dem Gerät und geht '
          'nirgendwohin.',
        ),
        isThreeLine: true,
        contentPadding: EdgeInsets.zero,
      ),
    ];
  }

  List<Widget> _backupSection(ThemeData theme) => [
    Text('Sichern', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    ListTile(
      key: const Key('backup_to_vault'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.save_outlined),
      title: const Text('Jetzt sichern'),
      subtitle: const Text(
        'Legt die Sicherung dort ab, wo dein Telefon sie in seine eigene '
        'Sicherung mitnimmt.',
      ),
      isThreeLine: true,
      onTap: _busy ? null : () => unawaited(_run(_runner.backUpToVault)),
    ),
    ListTile(
      key: const Key('backup_to_file'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.ios_share),
      title: Text(
        widget.simple ? 'Zusätzlich woanders ablegen' : 'Datei erzeugen',
      ),
      subtitle: Text(
        widget.simple
            ? 'Zum Beispiel in deiner Cloud oder als Mail an dich selbst. '
                  'Dann ist sie auch dann noch da, wenn das Telefon weg ist.'
            : 'Eine .nhbackup-Datei, gepacktes JSON. Du entscheidest, wohin '
                  '– Dateien-App, iCloud Drive, Google Drive, Stick.',
      ),
      isThreeLine: true,
      onTap: _busy ? null : () => unawaited(_run(_runner.exportToFile)),
    ),
  ];

  List<Widget> _restoreSection(ThemeData theme) => [
    Text('Zurückholen', style: theme.textTheme.titleMedium),
    const SizedBox(height: 8),
    if (!widget.simple) ...[
      Text(
        'Wie soll eingespielt werden?',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      RadioGroup<RestoreMode>(
        groupValue: _mode,
        onChanged: (value) {
          if (value != null) setState(() => _mode = value);
        },
        child: const Column(
          children: [
            RadioListTile<RestoreMode>(
              key: Key('backup_mode_replace'),
              value: RestoreMode.replace,
              title: Text('Ersetzen'),
              subtitle: Text('Was jetzt da ist, fliegt raus.'),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<RestoreMode>(
              key: Key('backup_mode_merge'),
              value: RestoreMode.merge,
              title: Text('Dazulegen'),
              subtitle: Text(
                'Gleiche Vorgänge werden überschrieben, der Rest bleibt. '
                'Dieselbe Datei zweimal einzuspielen ändert nichts.',
              ),
              isThreeLine: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ],
    ListTile(
      key: const Key('restore_from_vault'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.restore),
      title: const Text('Vom Gerät zurückholen'),
      subtitle: Text(
        _stored == null
            ? 'Am Standardplatz liegt gerade nichts.'
            : 'Die Sicherung vom '
                  '${HistoryLabels.moment(_stored!.savedAt)}.',
      ),
      enabled: !_busy && _stored != null,
      onTap: () => unawaited(_restoreFromVault()),
    ),
    ListTile(
      key: const Key('restore_from_file'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.folder_open),
      title: const Text('Aus einer Datei zurückholen'),
      subtitle: const Text(
        'Such die Datei selbst heraus – egal, aus welcher Version sie '
        'stammt.',
      ),
      isThreeLine: true,
      enabled: !_busy,
      onTap: () => unawaited(_restoreFromFile()),
    ),
  ];

  /// Der ehrliche Teil, und er gehört sichtbar hierher.
  ///
  /// Wer glaubt, seine PIN sei mitgesichert, steht nach der Neuinstallation
  /// ratlos da. Das einmal hinzuschreiben ist billiger als jede Erklärung
  /// hinterher.
  Widget _whatIsNotInside(ThemeData theme) => Container(
    key: const Key('backup_not_inside'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Was nicht in der Datei steht', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Deine PIN, deine Wiederherstellungs-Codes und deine KI-Zugänge. '
          'Die liegen im Schlüsselbund des Geräts, nicht in der Datenbank – '
          'eine Sicherungsdatei, die den Zugang zum Gerät gleich mitliefert, '
          'wäre das Gegenteil von Sicherheit.\n\n'
          'Die Datei ist deshalb nicht verschlüsselt, sondern nur gepackt. '
          'Sie enthält aber deine Historie im Klartext – leg sie dorthin, wo '
          'du auch Kontoauszüge hinlegen würdest.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
