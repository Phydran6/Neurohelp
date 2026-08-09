import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/call_launcher.dart';

/// Startet das Telefonat über einen `tel:`-Verweis.
class UrlLauncherCallLauncher implements CallLauncher {
  const UrlLauncherCallLauncher();

  @override
  Future<bool> dial(String number) async {
    // Leerzeichen und Trennzeichen stören manche Telefon-Apps.
    final cleaned = number.replaceAll(RegExp(r'[\s/()-]'), '');
    if (cleaned.isEmpty) return false;

    try {
      return await launchUrl(Uri(scheme: 'tel', path: cleaned));
    } on Exception catch (error, stackTrace) {
      AppLogger.error(
        'Telefon-App ließ sich nicht öffnen',
        scope: 'calls',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
