import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/message_draft.dart';
import '../domain/message_sender.dart';

/// Öffnet die System-App über einen `mailto:`- bzw. `https:`-Verweis.
class UrlLauncherMessageSender implements MessageSender {
  const UrlLauncherMessageSender();

  @override
  Future<bool> handOver(MessageDraft draft, {String? senderName}) async {
    final target = _buildUri(draft, senderName: senderName);
    if (target == null) return false;

    try {
      return await launchUrl(target, mode: LaunchMode.externalApplication);
    } on Exception catch (error, stackTrace) {
      AppLogger.error(
        'Übergabe an die System-App fehlgeschlagen',
        scope: 'messages',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Uri? _buildUri(MessageDraft draft, {String? senderName}) {
    final recipient = draft.recipient?.trim();
    if (recipient == null || recipient.isEmpty) return null;

    switch (draft.channel) {
      case MessageChannel.email:
      case MessageChannel.free:
        return Uri(
          scheme: 'mailto',
          path: recipient,
          queryParameters: {
            'subject': draft.subject,
            'body': draft.fullText(senderName: senderName),
          },
        );

      case MessageChannel.webForm:
        // Beim Kontaktformular kann die App nur die Seite öffnen. Das
        // Ausfüllen selbst ist laut Konzept (Abschnitt 21) noch offen.
        final parsed = Uri.tryParse(recipient);
        return parsed != null && parsed.hasScheme ? parsed : null;
    }
  }
}
