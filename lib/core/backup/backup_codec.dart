import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'backup_document.dart';

/// Zwischen [BackupDocument] und den Bytes einer Datei.
///
/// **Warum gzip und nicht zip:** Eine Sicherung ist genau eine Datei, kein
/// Ordner. Ein Zip-Archiv bräuchte dafür ein zusätzliches Paket und würde ein
/// Verzeichnis nachbilden, in dem eine einzige Datei liegt. Gzip steckt in
/// Dart schon drin und packt dieselben Daten auf etwa ein Zehntel.
///
/// **Warum trotzdem lesbar:** Wer die Datei entpackt, findet reines JSON –
/// nachvollziehbar, durchsuchbar, im Notfall von Hand reparierbar. Und beim
/// Einlesen wird auch ungepacktes JSON angenommen: Manche Cloud-Dienste und
/// Mail-Programme packen Anhänge unterwegs selbst aus.
abstract final class BackupCodec {
  /// Endung der Sicherungsdatei.
  ///
  /// Bewusst eine eigene: `.json.gz` würde jedes Archivprogramm anfassen
  /// wollen, `.zip` verspricht einen Ordner. So ist am Namen erkennbar, wozu
  /// die Datei gehört.
  static const String fileExtension = 'nhbackup';

  /// Was der Dateiauswahl-Dialog anbietet.
  ///
  /// Nicht nur die eigene Endung: Mail- und Cloud-Programme benennen Anhänge
  /// gern um, und dann findet der User seine eigene Datei nicht mehr.
  static const List<String> knownExtensions = [fileExtension, 'json', 'gz'];

  static const String mimeType = 'application/gzip';

  /// Die ersten zwei Bytes jeder gzip-Datei.
  static const int _gzipFirst = 0x1f;
  static const int _gzipSecond = 0x8b;

  static Uint8List encode(BackupDocument document) {
    final json = jsonEncode(document.toJson());
    return Uint8List.fromList(gzip.encode(utf8.encode(json)));
  }

  /// Liest Bytes zurück in eine Sicherung.
  ///
  /// Nimmt gepacktes und ungepacktes JSON an. Wirft
  /// [BackupFormatException], wenn beides nicht aufgeht.
  static BackupDocument decode(List<int> bytes) {
    if (bytes.isEmpty) {
      throw const BackupFormatException(
        BackupProblem.damaged,
        'Die Datei ist leer.',
      );
    }

    // Ob die Datei gepackt ankam, entscheidet mit, wie ein Lesefehler zu
    // deuten ist: Wer den gzip-Kopf hat, ist eine Sicherung – dann ist ein
    // unlesbarer Inhalt Beschädigung und keine fremde Datei. Das ist kein
    // Haarspalten: „Nimm eine andere Sicherung" und „das ist nicht unsere
    // Datei" schicken den User an völlig verschiedene Orte.
    final packed =
        bytes.length > 1 && bytes[0] == _gzipFirst && bytes[1] == _gzipSecond;

    final text = _text(bytes, packed: packed);

    final Object? raw;
    try {
      raw = jsonDecode(text);
    } on FormatException catch (error) {
      throw BackupFormatException(
        packed ? BackupProblem.damaged : BackupProblem.notABackup,
        packed
            ? 'Die Datei ist unterwegs beschädigt worden. Nimm eine andere '
                  'Sicherung – diese hier lässt sich nicht mehr einspielen.'
            : 'Diese Datei ist keine Sicherung von Neurohelp.',
        technical: error.message,
      );
    }

    return BackupDocument.fromJson(raw);
  }

  static String _text(List<int> bytes, {required bool packed}) {
    try {
      return utf8.decode(packed ? gzip.decode(bytes) : bytes);
    } on FormatException catch (error) {
      throw BackupFormatException(
        BackupProblem.damaged,
        'Die Datei ist unterwegs beschädigt worden.',
        technical: error.message,
      );
    }
  }

  /// Ein Dateiname mit Datum drin, damit mehrere Sicherungen nebeneinander
  /// liegen können, ohne sich gegenseitig zu überschreiben.
  static String fileNameFor(DateTime moment) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp =
        '${moment.year}-${two(moment.month)}-${two(moment.day)}'
        '-${two(moment.hour)}${two(moment.minute)}';
    return 'neurohelp-sicherung-$stamp.$fileExtension';
  }
}
