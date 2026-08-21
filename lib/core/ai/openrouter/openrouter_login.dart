import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../logging/app_logger.dart';

/// Schickt den User zum Login und fängt den Rücksprung wieder ein.
///
/// Eigene Schnittstelle, damit Tests ohne Browser auskommen – und damit die
/// Ablauf-Logik nicht am Paket klebt.
abstract interface class OpenRouterLogin {
  /// Öffnet [url] und liefert die Adresse, mit der der Browser zurückkommt.
  ///
  /// `null` heißt: Der User hat abgebrochen. Das ist kein Fehler und darf
  /// nichts auslösen.
  Future<Uri?> authorize(Uri url, {required String callbackScheme});
}

/// Der echte Login: Systembrowser auf, Rücksprung über das eigene URL-Schema.
///
/// Der User meldet sich **im Browser** an, nicht in der App. Die App sieht
/// dadurch nie Zugangsdaten – nur den Code, den sie danach gegen ihren
/// eigenen Schlüssel tauscht.
class WebOpenRouterLogin implements OpenRouterLogin {
  const WebOpenRouterLogin();

  @override
  Future<Uri?> authorize(Uri url, {required String callbackScheme}) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackScheme,
      );
      return Uri.parse(result);
    } on Exception catch (error) {
      // Abbruch durch den User kommt hier ebenfalls als Ausnahme an. Beides
      // führt an dieselbe Stelle: Es passiert einfach nichts weiter.
      AppLogger.info('Login abgebrochen: $error', scope: 'openrouter');
      return null;
    }
  }
}
