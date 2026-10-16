import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/backup/backup_vault.dart';
import '../../../core/di/app_services.dart';
import '../../../features/history/presentation/history_labels.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../../../shared/widgets/support_contact.dart';
import '../domain/backup_runner.dart';
import 'backup_outcome_box.dart';

/// Der allererste Bildschirm nach einer Neuinstallation.
///
/// **Warum vor dem Onboarding:** Wer die App neu installiert hat, hatte sie
/// schon einmal. Ihn zuerst durch die Einführung zu schicken und ihm danach
/// zu sagen, dass seine Sachen übrigens wieder da sind, ist die falsche
/// Reihenfolge – erst recht, weil die Sicherung die Einstellungen mitbringt
/// und das eben Eingestellte gleich wieder überschreibt.
///
/// **Zwei Wege, wie überall in dieser App:** Wer weiß, wo seine Datei liegt,
/// sucht sie selbst heraus. Wer davon nichts weiß, lässt die App am
/// Standardplatz nachsehen. Findet sie dort nichts, wird das gesagt – ohne
/// Schuld und ohne den Versuch, es schönzureden.
class RestoreGatePage extends StatefulWidget {
  const RestoreGatePage({super.key});

  @override
  State<RestoreGatePage> createState() => _RestoreGatePageState();
}

/// Welcher der beiden Wege gerade offen ist.
enum _Step { asking, expert, guided, done }

class _RestoreGatePageState extends State<RestoreGatePage> {
  _Step _step = _Step.asking;
  bool _busy = false;
  bool _searched = false;

  StoredBackup? _found;
  BackupOutcome? _outcome;

  BackupRunner get _runner => BackupRunner(AppScope.of(context));

  /// „Nein, ich fange neu an." Die Frage kommt danach nie wieder.
  Future<void> _skip() async {
    await AppScope.of(context).settings.setRestoreOffered(offered: true);
  }

  Future<void> _goGuided() async {
    setState(() {
      _step = _Step.guided;
      _busy = true;
    });

    final found = await _runner.findInVault();
    if (!mounted) return;
    setState(() {
      _found = found;
      _searched = true;
      _busy = false;
    });
  }

  Future<void> _restoreFromVault() => _run(() => _runner.restoreFromVault());

  Future<void> _restoreFromFile() =>
      _run(() => _runner.restoreFromPickedFile());

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
      // Ein Abbruch in der Dateiauswahl ist keine Antwort – der Bildschirm
      // bleibt einfach stehen.
      if (outcome != null && outcome.ok) _step = _Step.done;
    });
  }

  /// Nach dem Einspielen weiter in die App.
  ///
  /// Der Rest entscheidet sich von selbst: Bringt die Sicherung ein
  /// abgeschlossenes Onboarding mit, steht der User direkt auf der
  /// Startseite. Sonst läuft die Einführung – dann aber mit seinen Daten.
  Future<void> _continue() => _skip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: switch (_step) {
            _Step.asking => _asking(theme),
            _Step.expert => _expert(theme),
            _Step.guided => _guided(theme),
            _Step.done => _done(theme),
          },
        ),
      ),
    );
  }

  Widget _asking(ThemeData theme) => ListView(
    children: [
      const SizedBox(height: 16),
      Text(
        'Warst du schon mal hier?',
        key: const Key('restore_question'),
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        'Wenn du Neurohelp schon einmal benutzt hast, kann ich deine alten '
        'Sachen zurückholen – Historie, Vorgänge, Einstellungen. Wenn nicht, '
        'fangen wir einfach an.',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 28),
      BigActionButton(
        key: const Key('restore_guided'),
        label: 'Ja – schau du nach',
        icon: Icons.search,
        onPressed: () => unawaited(_goGuided()),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const Key('restore_expert'),
        onPressed: () => setState(() => _step = _Step.expert),
        icon: const Icon(Icons.folder_open),
        label: const Text('Ja – ich habe eine Sicherungsdatei'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('restore_skip'),
          onPressed: () => unawaited(_skip()),
          child: const Text('Nein, ich fange neu an'),
        ),
      ),
    ],
  );

  Widget _expert(ThemeData theme) => ListView(
    children: [
      const SizedBox(height: 8),
      Text(
        'Such deine Datei heraus',
        key: const Key('restore_expert_title'),
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        'Sie heißt ungefähr „neurohelp-sicherung-…" und kann überall liegen: '
        'in der Dateien-App, in deiner Cloud, als Mailanhang an dich selbst. '
        'Aus welcher Version sie stammt, ist egal.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 24),
      BigActionButton(
        key: const Key('restore_pick_file'),
        label: _busy ? 'Einen Moment …' : 'Datei auswählen',
        icon: Icons.folder_open,
        onPressed: _busy ? null : () => unawaited(_restoreFromFile()),
      ),
      if (_outcome != null) ...[
        const SizedBox(height: 20),
        BackupOutcomeBox(outcome: _outcome!),
      ],
      const SizedBox(height: 20),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          key: const Key('restore_back'),
          onPressed: _busy ? null : () => setState(() => _step = _Step.asking),
          child: const Text('Zurück'),
        ),
      ),
      const SizedBox(height: 16),
      const SupportContact(
        subject: 'Neurohelp – Sicherung lässt sich nicht einspielen',
        context_: 'Ich wollte eine Sicherungsdatei einspielen.',
      ),
    ],
  );

  Widget _guided(ThemeData theme) {
    final found = _found;

    return ListView(
      children: [
        const SizedBox(height: 8),
        Text(
          !_searched
              ? 'Ich schau kurz nach …'
              : found != null
              ? 'Ich habe was gefunden'
              : 'Ich habe nichts gefunden',
          key: const Key('restore_guided_title'),
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (!_searched)
          Text(
            'Einen Moment.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else if (found != null) ...[
          Text(
            'Eine Sicherung vom ${HistoryLabels.moment(found.savedAt)}, '
            '${found.sizeLabel}. Wenn ich sie einspiele, ist alles wieder '
            'so, wie es damals war.',
            key: const Key('restore_found'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          BigActionButton(
            key: const Key('restore_apply'),
            label: _busy ? 'Einen Moment …' : 'Ja, hol das zurück',
            icon: Icons.restore,
            onPressed: _busy ? null : () => unawaited(_restoreFromVault()),
          ),
        ] else ...[
          Text(
            'An dem Platz, an dem die App selbst sichert, liegt nichts. Das '
            'heißt meistens: Die Sicherung deines Telefons hat die Datei '
            'nicht mitgenommen, oder es gab noch keine.',
            key: const Key('restore_empty'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mehr kann ich von hier aus nicht versuchen. Wenn du doch eine '
            'Datei irgendwo liegen hast, nimm den anderen Weg – sonst fangen '
            'wir neu an. Das ist kein Beinbruch.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('restore_switch_expert'),
            onPressed: () => setState(() => _step = _Step.expert),
            icon: const Icon(Icons.folder_open),
            label: const Text('Ich habe doch eine Datei'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
          const SizedBox(height: 12),
          BigActionButton(
            key: const Key('restore_start_fresh'),
            label: 'Neu anfangen',
            onPressed: () => unawaited(_skip()),
          ),
        ],
        if (_outcome != null) ...[
          const SizedBox(height: 20),
          BackupOutcomeBox(outcome: _outcome!),
        ],
        const SizedBox(height: 20),
        if (_searched && found == null) ...[
          const SupportContact(
            subject: 'Neurohelp – Sicherung nicht gefunden',
            context_:
                'Beim ersten Start hat die App am Standardplatz keine '
                'Sicherung gefunden.',
          ),
          const SizedBox(height: 16),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('restore_back'),
            onPressed: _busy
                ? null
                : () => setState(() => _step = _Step.asking),
            child: const Text('Zurück'),
          ),
        ),
      ],
    );
  }

  Widget _done(ThemeData theme) => ListView(
    children: [
      const SizedBox(height: 16),
      Icon(
        Icons.check_circle_outline,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      const SizedBox(height: 20),
      Text(
        'Alles wieder da',
        key: const Key('restore_done'),
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      Text(
        _outcome?.message ?? '',
        key: const Key('restore_done_summary'),
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 28),
      BigActionButton(
        key: const Key('restore_continue'),
        label: 'Weiter',
        onPressed: () => unawaited(_continue()),
      ),
    ],
  );
}
