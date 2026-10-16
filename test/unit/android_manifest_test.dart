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

    test('nimmt die Sicherung in die Gerätesicherung mit', () {
      final content = manifest.readAsStringSync();

      // Ohne diese drei Zeilen überlebt keine Sicherung eine
      // Neuinstallation – und der Einstieg beim ersten Start findet dann
      // nie etwas. Das fällt in keinem Emulator-Lauf auf.
      expect(content, contains('android:allowBackup="true"'));
      expect(
        content,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
      expect(
        content,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
        reason: 'Ab Android 12 gelten die alten Regeln nicht mehr.',
      );
    });
  });

  group('Sicherungsregeln', () {
    final rules = File('android/app/src/main/res/xml/backup_rules.xml');
    final extraction = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );

    test('nehmen nur die Sicherungsdatei mit, nichts sonst', () {
      // Erlaubnisliste statt Sperrliste: Ohne diese Dateien würde Android
      // die gesamte App nach Google sichern, inklusive der Datenbank. Das
      // wäre eine Cloud-Speicherung, um die niemand gebeten hat
      // (Konzept, Abschnitt 14).
      for (final file in [rules, extraction]) {
        // Ohne die Kommentare: Dort steht die Begründung, warum Datenbank
        // und Einstellungen draußen bleiben – und genau diese Wörter würde
        // die Prüfung sonst finden.
        final content = file.readAsStringSync().replaceAll(
          RegExp(r'<!--.*?-->', dotAll: true),
          '',
        );

        expect(
          content,
          contains('<include domain="file" path="Sicherungen/" />'),
          reason: 'Muss zu DeviceBackupVault.folderName passen.',
        );
        expect(
          content,
          isNot(contains('database')),
          reason:
              'Die Datenbank steckt bereits in der Sicherungsdatei, und '
              'zwar in einer Form, die eine andere Schemaversion übersteht.',
        );
        expect(
          content,
          isNot(contains('sharedpref')),
          reason: 'Dort liegen PIN und Wiederherstellungs-Codes.',
        );
      }
    });

    test('decken Cloud-Sicherung und Gerätewechsel getrennt ab', () {
      final content = extraction.readAsStringSync();

      // Android 12 trennt beides, und was nicht dasteht, wird nicht
      // mitgenommen.
      expect(content, contains('<cloud-backup>'));
      expect(content, contains('<device-transfer>'));
    });
  });
}
