import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_version.dart';
import '../../core/logging/app_logger.dart';
import '../../features/help/domain/about_info.dart';

/// „Wenn gar nichts geht: schreib mir."
///
/// **Zwei Wege, und das ist Absicht.** Wer mit GitHub umgehen kann, macht
/// dort ein Ticket auf – öffentlich, nachlesbar, und andere haben etwas
/// davon. Alle anderen schreiben eine Mail. Einen der beiden Wege
/// wegzulassen hieße, eine der beiden Gruppen auszuschließen; genau davon
/// handelt diese App.
class SupportContact extends StatelessWidget {
  const SupportContact({
    super.key,
    this.title = 'Es geht trotzdem nicht?',
    this.subject = 'Neurohelp',
    this.context_,
  });

  final String title;

  /// Betreff der Mail – sagt, worum es geht, bevor jemand sie öffnet.
  final String subject;

  /// Worum es gerade ging. Landet vorformuliert in der Mail, damit der User
  /// nicht vor einem leeren Feld sitzt.
  final String? context_;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ohne eingelesene Konfiguration (Widget-Test) bleibt der GitHub-Weg.
    final email = AppConfig.instanceOrNull?.supportEmail ?? '';

    // Material, nicht Container: Die Zeilen darunter malen ihren Tipp-Effekt
    // auf das nächste Material. Läge dazwischen nur eine eingefärbte Box,
    // verschluckt sie ihn – Flutter meldet das im Test als Fehler.
    return Material(
      key: const Key('support_contact'),
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              'Kein Formular, keine Warteschleife. Nimm den Weg, der dir '
              'leichter fällt – beide landen bei derselben Person.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (email.isNotEmpty)
              ListTile(
                key: const Key('support_mail'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.mail_outline),
                title: const Text('Mir direkt eine Mail schreiben'),
                subtitle: Text(email),
                onTap: () => _openMail(context, email),
              ),
            ListTile(
              key: const Key('support_issue'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Auf GitHub melden'),
              subtitle: const Text(
                'Wenn dir das nichts sagt, nimm den Weg darüber.',
              ),
              onTap: () =>
                  _open(context, Uri.parse('${AboutInfo.repository}/issues')),
            ),
          ],
        ),
      ),
    );
  }

  /// Vorformuliert, inklusive Version.
  ///
  /// Ohne die Version ist eine Fehlermeldung kaum zu gebrauchen – und danach
  /// zu fragen, wenn jemand gerade nicht weiterkommt, ist eine Zumutung.
  Future<void> _openMail(BuildContext context, String email) {
    final body = [
      if (context_ != null) context_!,
      if (context_ != null) '',
      'Was ich gemacht habe:',
      '',
      'Was passiert ist:',
      '',
      '---',
      'Version: ${AppVersion.label}',
    ].join('\n');

    return _open(
      context,
      Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {'subject': subject, 'body': body},
      ),
    );
  }

  static Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on Exception catch (error, stackTrace) {
      AppLogger.error(
        'Kontaktweg ließ sich nicht öffnen',
        scope: 'help',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // Keine Mail-App eingerichtet: Dann wenigstens die Adresse zeigen, statt
    // wortlos nichts zu tun.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          uri.scheme == 'mailto'
              ? 'Keine Mail-App gefunden. Die Adresse ist ${uri.path}'
              : 'Konnte nicht geöffnet werden: $uri',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
