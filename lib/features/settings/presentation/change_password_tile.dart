import 'package:flutter/material.dart';

import '../../../core/di/app_services.dart';
import '../../../shared/widgets/text_context_menu.dart';

/// „Passwort ändern" – in beiden Wegen durch die Einstellungen dieselbe Zeile.
///
/// **Das fehlte komplett.** Das Passwort ließ sich bis hierher nur über
/// „Passwort vergessen" im Einstieg ändern: Mail anfordern, Code abtippen,
/// neues Passwort setzen. Wer angemeldet war, kam an diesen Bildschirm gar
/// nicht mehr heran – er hätte sich erst abmelden müssen, um sein Passwort
/// zu ändern. Das ist keine Hürde, das ist eine Sackgasse.
///
/// Wer angemeldet ist, hat längst bewiesen, dass ihm das Konto gehört. Es
/// braucht deshalb keinen Code und keine Mail: ein Feld, fertig.
class ChangePasswordTile extends StatelessWidget {
  const ChangePasswordTile({
    required this.enabled,
    required this.onRun,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final bool enabled;

  /// Führt die Aktion mit der Fehlerbehandlung der aufrufenden Seite aus.
  final Future<void> Function(Future<void> Function() action) onRun;

  /// Wird gerufen, wenn das Passwort wirklich geändert wurde.
  final VoidCallback onChanged;

  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: const Key('settings_change_password'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.password_outlined),
      title: const Text('Passwort ändern'),
      subtitle: Text(
        subtitle ?? 'Ohne Code und ohne Mail – du bist ja angemeldet.',
      ),
      onTap: enabled ? () => _start(context) : null,
    );
  }

  Future<void> _start(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

    if (password == null || !context.mounted) return;

    await onRun(() async {
      await AppScope.of(context).account.changePassword(password);
      onChanged();
    });
  }
}

/// Zwei Felder, weil ein vertipptes Passwort sonst erst beim nächsten
/// Anmelden auffällt – und dann steht man vor der Reset-Mail.
///
/// Die Felder gehören dem Dialog selbst. Lägen sie außerhalb, müsste sie
/// jemand wegräumen – und der Dialog baut sich während des Ausblendens noch
/// einmal auf. Ein schon weggeräumter Controller fliegt einem dann um die
/// Ohren (dieselbe Falle wie beim eigenen KI-Schlüssel).
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  String? _problem;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _password.text;

    if (password.length < 8) {
      setState(() => _problem = 'Mindestens 8 Zeichen.');
      return;
    }
    if (password != _repeat.text) {
      setState(() => _problem = 'Die beiden stimmen nicht überein.');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Neues Passwort'),
      // Scrollbar: Auf einem kleinen Bildschirm mit offener Tastatur ist in
      // einem Dialog mit zwei Feldern sonst schnell kein Platz mehr.
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('settings_password_field'),
            contextMenuBuilder: noScanContextMenu,
            controller: _password,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Neues Passwort',
              helperText: 'Mindestens 8 Zeichen',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('settings_password_repeat'),
            contextMenuBuilder: noScanContextMenu,
            controller: _repeat,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Noch einmal'),
            onSubmitted: (_) => _submit(),
          ),
          if (_problem != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _problem!,
                key: const Key('settings_password_problem'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('settings_password_save'),
          onPressed: _submit,
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
