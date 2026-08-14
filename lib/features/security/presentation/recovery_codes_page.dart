import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/di/app_services.dart';
import '../../../core/security/recovery_codes.dart';
import '../../../shared/widgets/big_action_button.dart';
import '../domain/security_backup.dart';

/// Wiederherstellungs-Codes neu erzeugen (Konzept, Abschnitt 13).
///
/// Der Nachholweg für alle, die bei der Einrichtung „Später" gedrückt haben
/// oder ihre Codes aufgebraucht haben. Ein neuer Satz ersetzt den alten
/// vollständig – halbe Sätze aus zwei Zetteln wären nicht auseinanderzuhalten.
class RecoveryCodesPage extends StatefulWidget {
  const RecoveryCodesPage({required this.remaining, super.key});

  /// Wie viele Codes gerade noch offen sind.
  final int remaining;

  @override
  State<RecoveryCodesPage> createState() => _RecoveryCodesPageState();
}

class _RecoveryCodesPageState extends State<RecoveryCodesPage> {
  List<String> _codes = const [];
  Account? _account;
  bool _busy = false;
  String? _note;

  Future<void> _generate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _note = null;
    });

    final services = AppScope.of(context);
    final account = services.account.isConfigured
        ? await services.account.currentAccount()
        : null;

    final generated = RecoveryCodes.generate();
    await services.lock.setRecoveryCodes(generated.stored);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _account = account;
      _codes = generated.plain;
    });
  }

  SecurityBackup _backup() => SecurityBackup(
    createdAt: DateTime.now(),
    accountEmail: _account?.email,
    recoveryCodes: _codes,
  );

  Future<void> _saveFile() async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    try {
      final backup = _backup();
      await AppScope.of(context).files.save(
        fileName: backup.fileName,
        content: backup.toText(),
        subject: 'Neurohelp – Wiederherstellungs-Codes',
        origin: origin,
      );
      if (!mounted) return;
      setState(() => _note = 'Sicherung ist raus.');
    } on Exception {
      if (!mounted) return;
      setState(
        () => _note =
            'Das Speichern hat nicht geklappt. Kopier die Codes stattdessen.',
      );
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _backup().toText()));
    if (!mounted) return;
    setState(() => _note = 'Codes in der Zwischenablage.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fresh = _codes.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wiederherstellungs-Codes'),
        automaticallyImplyLeading: !fresh,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      fresh
                          ? 'Hier sind sie. Nur dieses eine Mal.'
                          : widget.remaining > 0
                          ? 'Du hast noch ${widget.remaining} offene Codes.'
                          : 'Du hast gerade keine Codes.',
                      key: const Key('recovery_status'),
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fresh
                          ? 'Sicher die Datei weg oder schreib die Codes ab. '
                                'Jeder funktioniert genau einmal, und die '
                                'alten gelten ab jetzt nicht mehr.'
                          : 'Damit kommst du an der App-Sperre vorbei, wenn '
                                'PIN und Fingerabdruck nicht mehr gehen – zum '
                                'Beispiel nach einem Gerätewechsel.\n\n'
                                'Ein neuer Satz ersetzt alle alten Codes.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (fresh) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final code in _codes)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: SelectableText(
                                  code,
                                  key: Key('recovery_code_$code'),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_note != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _note!,
                        key: const Key('recovery_note'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (fresh) ...[
                BigActionButton(
                  key: const Key('recovery_save'),
                  label: 'Als Datei sichern',
                  icon: Icons.download_outlined,
                  onPressed: _saveFile,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('recovery_copy'),
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Stattdessen kopieren'),
                ),
                TextButton(
                  key: const Key('recovery_done'),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Hab ich – fertig'),
                ),
              ] else
                BigActionButton(
                  key: const Key('recovery_generate'),
                  label: widget.remaining > 0
                      ? 'Neue Codes erzeugen'
                      : 'Codes erzeugen',
                  onPressed: _busy ? null : () => unawaited(_generate()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
