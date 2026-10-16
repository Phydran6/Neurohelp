import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';
import 'backup_codec.dart';

/// Wann eine Sicherung am Standardplatz entstanden ist und wie groß sie ist.
class StoredBackup {
  const StoredBackup({
    required this.path,
    required this.savedAt,
    required this.sizeInBytes,
  });

  final String path;
  final DateTime savedAt;
  final int sizeInBytes;

  /// Für die Anzeige: „12 KB".
  String get sizeLabel {
    if (sizeInBytes < 1024) return '$sizeInBytes Bytes';
    final kb = sizeInBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// Der Standardplatz für die Sicherung – für alle, die sich um Dateien nicht
/// kümmern wollen oder können.
///
/// **Warum das überhaupt beim Neuinstallieren etwas nützt:** Der Ordner liegt
/// im Dokumentenbereich der App. Android nimmt ihn in seine automatische
/// Sicherung zu Google auf (siehe `android/app/src/main/res/xml/backup_rules.xml`),
/// iOS in die Gerätesicherung nach iCloud bzw. auf den Rechner. Richtet der
/// User sein Gerät neu ein oder installiert die App neu, liegt die Datei
/// wieder da – und die App fragt beim ersten Start danach.
///
/// **Was das nicht kann:** Hat der User die Gerätesicherung abgeschaltet oder
/// wechselt er von Android zu iPhone, ist die Datei weg. Dafür gibt es den
/// zweiten Weg: die Datei selbst irgendwohin legen, wo sie bleibt.
abstract interface class BackupVault {
  /// Die zuletzt am Standardplatz abgelegte Sicherung, oder `null`.
  Future<StoredBackup?> latest();

  /// Legt [bytes] am Standardplatz ab und ersetzt eine vorhandene Datei.
  Future<StoredBackup> write(Uint8List bytes);

  Future<Uint8List> read(String path);

  /// Wirft die Sicherung am Standardplatz weg.
  Future<void> clear();
}

/// Der echte Standardplatz auf dem Gerät.
class DeviceBackupVault implements BackupVault {
  const DeviceBackupVault();

  /// Fester Name statt Zeitstempel: Am Standardplatz liegt **eine** Datei,
  /// die immer die neueste ist. Eine wachsende Sammlung von Sicherungen wäre
  /// genau die Entscheidung, die dieser Weg dem User abnehmen soll.
  static const String fileName =
      'neurohelp-letzte-sicherung.'
      '${BackupCodec.fileExtension}';

  static const String folderName = 'Sicherungen';

  Future<Directory> _folder() async {
    final documents = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(documents.path, folderName));
    if (!folder.existsSync()) await folder.create(recursive: true);
    return folder;
  }

  @override
  Future<StoredBackup?> latest() async {
    try {
      final folder = await _folder();
      final file = File(p.join(folder.path, fileName));
      if (!file.existsSync()) return null;

      final stat = await file.stat();
      return StoredBackup(
        path: file.path,
        savedAt: stat.modified,
        sizeInBytes: stat.size,
      );
    } on FileSystemException catch (error, stackTrace) {
      // Kein Zugriff auf den Ordner ist kein Grund, die App anzuhalten: Dann
      // gibt es eben nichts einzuspielen.
      AppLogger.error(
        'Standardplatz nicht lesbar',
        scope: 'backup',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<StoredBackup> write(Uint8List bytes) async {
    final folder = await _folder();
    final file = File(p.join(folder.path, fileName));

    await file.writeAsBytes(bytes, flush: true);
    final stat = await file.stat();

    return StoredBackup(
      path: file.path,
      savedAt: stat.modified,
      sizeInBytes: stat.size,
    );
  }

  @override
  Future<Uint8List> read(String path) => File(path).readAsBytes();

  @override
  Future<void> clear() async {
    final folder = await _folder();
    final file = File(p.join(folder.path, fileName));
    if (file.existsSync()) await file.delete();
  }
}

/// Standardplatz im Arbeitsspeicher – für Tests und für Plattformen ohne
/// eigenen Dokumentenordner.
class InMemoryBackupVault implements BackupVault {
  InMemoryBackupVault({this.clock});

  final DateTime Function()? clock;

  Uint8List? _bytes;
  StoredBackup? _stored;

  static const String path = 'speicher://letzte-sicherung';

  @override
  Future<StoredBackup?> latest() async => _stored;

  @override
  Future<StoredBackup> write(Uint8List bytes) async {
    _bytes = bytes;
    return _stored = StoredBackup(
      path: path,
      savedAt: (clock ?? DateTime.now)(),
      sizeInBytes: bytes.length,
    );
  }

  @override
  Future<Uint8List> read(String path) async {
    final bytes = _bytes;
    if (bytes == null) throw const FileSystemException('Nichts abgelegt');
    return bytes;
  }

  @override
  Future<void> clear() async {
    _bytes = null;
    _stored = null;
  }
}
