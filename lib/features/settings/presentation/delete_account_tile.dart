import 'package:flutter/material.dart';

import '../../../core/account/account_repository.dart';
import '../../../core/di/app_services.dart';

/// „Alles weg" – an beiden Wegen durch die Einstellungen dieselbe Zeile.
///
/// Bewusst ein eigenes Widget: Das Löschen ist der einzige Vorgang in dieser
/// App, der sich nicht rückgängig machen lässt. Zwei Abschriften davon wären
/// zwei Orte, an denen die Reihenfolge – erst Server, dann Gerät – oder der
/// Wortlaut auseinanderlaufen können.
///
/// Der Ablauf: nachfragen, Konto beim Backend löschen, **danach** das Gerät
/// leerräumen, bestätigen, zurück an den Anfang. Andersherum stünde der User
/// ohne seine Sachen da, während das Konto noch existiert.
class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({
    required this.enabled,
    required this.onRun,
    required this.onDeleted,
    this.subtitle,
    super.key,
  });

  final bool enabled;

  /// Führt die Aktion mit der Fehlerbehandlung der aufrufenden Seite aus.
  final Future<void> Function(Future<void> Function() action) onRun;

  /// Wird gerufen, wenn wirklich gelöscht wurde. [emailed] sagt, ob das
  /// Backend zusätzlich eine Bestätigung verschickt hat.
  final void Function({required bool emailed}) onDeleted;

  /// Übersteuert den Untertitel – im geführten Weg steht dort mehr.
  final String? subtitle;

  static const String defaultSubtitle =
      'Löscht restlos alles, was serverseitig zu dir gehört. Du bekommst '
      'eine Bestätigung per Mail.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      key: const Key('settings_delete_account'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      title: Text(
        'Konto löschen',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      subtitle: Text(subtitle ?? defaultSubtitle),
      isThreeLine: subtitle != null,
      onTap: enabled ? () => _start(context) : null,
    );
  }

  Future<void> _start(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konto wirklich löschen?'),
        content: const Text(
          'Dein Konto und alles, was serverseitig dazugehört, wird '
          'gelöscht – Profil, Zwei-Faktor, Wiederherstellungs-Codes.\n\n'
          'Danach räumt die App auch dieses Gerät leer: alle Vorgänge, die '
          'Historie, deine Einstellungen, die PIN und die Sicherung auf '
          'diesem Gerät. Übrig bleibt nur, was die App gar nicht in der Hand '
          'hat – etwa eine Mail, die schon in deiner Mail-App liegt, oder '
          'eine Sicherungsdatei, die du selbst woanders abgelegt hast.\n\n'
          'Das lässt sich nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            key: const Key('settings_delete_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Doch nicht'),
          ),
          FilledButton(
            key: const Key('settings_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ja, löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await onRun(() async {
      final services = AppScope.of(context);
      final emailed = await services.account.deleteAccount();

      // Erst wenn das Backend wirklich gelöscht hat, wird das Gerät geräumt.
      await services.wipeLocalData();
      if (!context.mounted) return;

      onDeleted(emailed: emailed);
      await _confirm(context, emailed: emailed);
    });
  }

  /// Sagt in einem Satz, was passiert ist, und geht dann aus der App heraus.
  ///
  /// Ohne Konto und ohne Daten weiter in der angemeldeten Ansicht zu stehen,
  /// ergibt keinen Sinn: Nach dem Hinweis liegt die App wieder am Anfang.
  static Future<void> _confirm(
    BuildContext context, {
    required bool emailed,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('settings_deleted_dialog'),
        title: const Text('Alles gelöscht'),
        content: Text(
          'Dein Konto ist weg, und auf diesem Gerät ist nichts mehr von dir '
          'gespeichert – keine Vorgänge, keine Historie, keine '
          'Einstellungen.'
          '${emailed ? '\n\nEine Bestätigung liegt gleich in deinem Postfach.' : ''}'
          '\n\nDu bist damit auch abgemeldet. Die App fängt wieder von vorn '
          'an – du kannst sie einfach weiter benutzen oder liegen lassen.',
        ),
        actions: [
          FilledButton(
            key: const Key('settings_deleted_ok'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    // Zurück an den Anfang: Dort entscheidet die App neu, was zu sehen ist –
    // ohne abgeschlossenes Onboarding ist das der Einstieg.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// Übersetzt eine fehlgeschlagene Konto-Aktion in einen ruhigen Satz.
///
/// Steht hier, weil beide Einstellungs-Wege dieselben Fehler bekommen.
({String message, String? technical}) describeAccountError(
  AccountException error,
) => (
  message: error.details ?? 'Das hat gerade nicht geklappt.',
  technical: error.technical,
);
