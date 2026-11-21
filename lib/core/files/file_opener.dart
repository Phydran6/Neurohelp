import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../logging/app_logger.dart';

/// Eine Datei, die der User ausgesucht hat.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Lässt den User eine Datei vom Gerät auswählen.
///
/// Das Gegenstück zu [FileSaver]: Der speichert, wohin der User will, dieser
/// holt von dort wieder. Beides über die Auswahl des Systems – damit erreicht
/// die App auch iCloud Drive, Google Drive und Dropbox, ohne einen einzigen
/// Cloud-Dienst zu kennen.
abstract interface class FileOpener {
  /// Öffnet die Dateiauswahl. `null` heißt: abgebrochen – kein Fehler.
  ///
  /// [extensions] ist nur ein Vorschlag an das System. Auf manchen Geräten
  /// lässt sich die Auswahl damit nicht einschränken; dann kommt eben eine
  /// beliebige Datei zurück, und das Einlesen sagt Bescheid.
  Future<PickedFile?> pick({List<String> extensions = const []});
}

/// Die Dateiauswahl des Systems.
class SystemFileOpener implements FileOpener {
  const SystemFileOpener();

  @override
  Future<PickedFile?> pick({List<String> extensions = const []}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        // Ohne das liefert die Auswahl auf Android nur einen Pfad, den die
        // App nicht lesen darf – die Datei liegt bei einem anderen Programm.
        withData: true,
        type: extensions.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: extensions.isEmpty ? null : extensions,
      );

      final file = result?.files.singleOrNull;
      final bytes = file?.bytes;
      if (file == null || bytes == null) return null;

      return PickedFile(name: file.name, bytes: bytes);
    } on Exception catch (error, stackTrace) {
      // Manche Geräte lehnen eine eingeschränkte Auswahl ab. Dann lieber
      // alles anbieten als gar nichts.
      AppLogger.error(
        'Dateiauswahl nicht möglich',
        scope: 'backup',
        error: error,
        stackTrace: stackTrace,
      );
      if (extensions.isEmpty) return null;
      return pick();
    }
  }
}

/// Liefert immer dieselbe Datei – für Tests.
class FixedFileOpener implements FileOpener {
  FixedFileOpener([this.file]);

  PickedFile? file;
  int calls = 0;

  @override
  Future<PickedFile?> pick({List<String> extensions = const []}) async {
    calls++;
    return file;
  }
}
