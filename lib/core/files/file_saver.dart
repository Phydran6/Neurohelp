import 'dart:io';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Gibt eine Datei aus der App heraus.
///
/// Bewusst über das System-Blatt statt in einen festen Ordner: Auf Android
/// liegt der Ordner der App app-privat, dort findet der User die Datei nie
/// wieder. Über das Blatt entscheidet er selbst – Dateien-App,
/// Passwort-Manager, Kalender, Cloud, an sich selbst schicken.
abstract interface class FileSaver {
  /// Bietet [content] unter [fileName] zum Speichern an.
  ///
  /// [origin] ist der Bereich, aus dem das Blatt aufklappt – auf dem iPad ein
  /// Pflichtwert, sonst erscheint es in der Ecke.
  Future<void> save({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
    String? subject,
    Rect? origin,
  });
}

/// Schreibt die Datei in den temporären Ordner und reicht sie weiter.
class ShareFileSaver implements FileSaver {
  const ShareFileSaver();

  @override
  Future<void> save({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
    String? subject,
    Rect? origin,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));

    await file.writeAsString(content, flush: true);

    // share_plus 13: ein Parameterobjekt statt vieler Argumente.
    // `Share.shareXFiles` gibt es noch, ist aber abgekündigt.
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: mimeType, name: fileName)],
        subject: subject,
        sharePositionOrigin: origin,
      ),
    );
  }
}

/// Tut nichts – für Tests und für Plattformen ohne System-Blatt.
class NoFileSaver implements FileSaver {
  const NoFileSaver();

  @override
  Future<void> save({
    required String fileName,
    required String content,
    String mimeType = 'text/plain',
    String? subject,
    Rect? origin,
  }) async {}
}
