import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/openrouter/openrouter_api.dart';

/// Der Rücksprung aus dem Browser ist die Stelle, an der ein OAuth-Login
/// still scheitert: Der User meldet sich an, landet auf einer leeren Seite
/// und kommt nie zurück. Auffallen würde das nur auf einem echten Gerät –
/// und lokal wird hier nicht gebaut.
void main() {
  const scheme = OpenRouterApi.callbackScheme;

  test('Android kennt die Rücksprung-Activity', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('com.linusu.flutter_web_auth_2.CallbackActivity'),
      reason:
          'Ohne diese Activity landet der Code aus dem Login nirgends und '
          'der Rücksprung endet in einer leeren Browserseite.',
    );
    expect(manifest, contains('android:scheme="$scheme"'));
  });

  test('iOS kennt das Rücksprung-Schema', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      plist,
      contains('<string>$scheme</string>'),
      reason:
          'Ohne Eintrag in CFBundleURLSchemes ignoriert iOS die '
          'Rücksprung-Adresse.',
    );
  });

  test('das bestehende Schema für Reset-Mails bleibt erhalten', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    // Zwei Schemata nebeneinander: Das eine holt den User aus einer
    // Bestätigungs-Mail zurück, das andere aus dem KI-Login.
    expect(manifest, contains('android:scheme="will.neurohelp.help"'));
    expect(plist, contains('<string>will.neurohelp.help</string>'));
  });
}
