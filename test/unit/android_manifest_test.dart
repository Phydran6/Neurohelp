import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft das Android-Manifest.
///
/// Anlass: Der erste Alpha-Build konnte kein Konto anlegen. Flutter legt die
/// Internet-Berechtigung nur in den Debug- und Profile-Manifesten an – im
/// Release fehlte sie, die App hatte schlicht keinen Netzzugriff. Der Fehler
/// fällt in keinem Test und in keinem Emulator-Debuglauf auf.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  group('AndroidManifest', () {
    test('erlaubt Netzzugriff auch im Release', () {
      final content = manifest.readAsStringSync();

      expect(
        content,
        contains('android.permission.INTERNET'),
        reason:
            'Ohne diese Berechtigung schlagen Konto, Reset-Mail und KI-Proxy '
            'im Release-Build fehl – im Debug-Build aber nicht.',
      );
    });

    test('kennt den Rückweg aus einer Bestätigungs-Mail', () {
      final content = manifest.readAsStringSync();

      // Die App arbeitet mit sechsstelligen Codes, weil Links aus Mail-Apps
      // im falschen Browser landen. Der Link steht trotzdem in jeder Mail –
      // ohne dieses Schema passiert beim Antippen gar nichts.
      expect(
        content,
        contains('android:scheme="will.neurohelp.help"'),
        reason:
            'Muss zur Site-URL des Supabase-Projekts passen, '
            'siehe docs/BACKEND.md.',
      );
      expect(content, contains('android.intent.category.BROWSABLE'));
    });

    test('fragt keine Berechtigungen, die die App nicht braucht', () {
      final content = manifest.readAsStringSync();

      // Die App liest keine Kontakte und keinen Standort. Wer das ergänzt,
      // soll darüber stolpern.
      expect(content, isNot(contains('READ_CONTACTS')));
      expect(content, isNot(contains('ACCESS_FINE_LOCATION')));
      expect(content, isNot(contains('READ_EXTERNAL_STORAGE')));
    });
  });
}
