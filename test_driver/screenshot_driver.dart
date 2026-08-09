// Gegenstück zu integration_test/screenshots_test.dart.
//
// Der Test läuft auf dem Gerät, dieses Skript läuft auf dem Rechner daneben
// und schreibt die Bilder, die von dort herüberkommen, als PNG auf die Platte.

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      final directory = Directory('build/screenshots');
      await directory.create(recursive: true);

      final file = File('${directory.path}/$name.png');
      await file.writeAsBytes(bytes);

      stdout.writeln('Bild geschrieben: ${file.path} (${bytes.length} Bytes)');
      return true;
    },
  );
}
