import 'dart:io';
import 'dart:typed_data';
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
///
/// Damit ist auch die Frage „Sicherung in die Cloud?" beantwortet, ohne dass
/// die App einen einzigen Cloud-Dienst kennen muss: Im Blatt stehen iCloud
/// Drive, Google Drive, Dropbox und alles andere, was auf dem Gerät
/// installiert ist. Der User wählt.
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

  /// Dasselbe für Binärdaten – die gepackte Sicherungsdatei.
  Future<void> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
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
    final file = await _write(fileName, (file) => file.writeAsString(content));
    await _share(file, fileName, mimeType, subject, origin);
  }

  @override
  Future<void> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? subject,
    Rect? origin,
  }) async {
    final file = await _write(fileName, (file) => file.writeAsBytes(bytes));
    await _share(file, fileName, mimeType, subject, origin);
  }

  static Future<File> _write(
    String fileName,
    Future<File> Function(File file) writer,
  ) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, fileName));
    return writer(file);
  }

  static Future<void> _share(
    File file,
    String fileName,
    String mimeType,
    String? subject,
    Rect? origin,
  ) {
    return Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType, name: fileName)],
      subject: subject,
      sharePositionOrigin: origin,
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

  @override
  Future<void> saveBytes({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
    String? subject,
    Rect? origin,
  }) async {}
}
