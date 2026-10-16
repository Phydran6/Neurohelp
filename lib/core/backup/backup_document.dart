import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Eine Sicherung als Datenstruktur – noch ohne Datei, ohne Datenbank.
///
/// **Der Punkt dieser Klasse ist die Versionstoleranz.** Eine Sicherung soll
/// sich auch dann einspielen lassen, wenn sie aus einer älteren oder einer
/// neueren App stammt. Deshalb steht hier nicht „Objekt Termin", sondern
/// schlicht: Tabelle, Spaltenname, Wert. Kommt eine Spalte dazu, fehlt sie in
/// alten Sicherungen und bekommt beim Einspielen ihren Standardwert. Fällt
/// eine weg, wird sie beim Einspielen übergangen. Beides ohne Migration.
///
/// Was hier **nicht** hineingehört: die PIN, die Wiederherstellungs-Codes und
/// der KI-Zugang. Die liegen im Schlüsselbund des Geräts, nicht in der
/// Datenbank – und eine Sicherungsdatei, die den Zugang zum Gerät gleich
/// mitliefert, wäre das Gegenteil von Sicherheit.
class BackupDocument {
  const BackupDocument({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.tables,
  });

  /// Kennung im Kopf der Datei. Damit lässt sich eine fremde Datei erkennen,
  /// bevor irgendetwas geschrieben wird.
  static const String format = 'neurohelp.backup';

  /// Version des **Dateiformats**, nicht des Datenbankschemas.
  ///
  /// Sie ändert sich nur, wenn sich der Aufbau der Datei selbst ändert. Neue
  /// Tabellen oder Spalten ändern sie nicht – genau dafür ist der Aufbau so
  /// schlicht.
  static const int formatVersion = 1;

  /// Schemaversion der Datenbank, aus der gesichert wurde. Rein zur
  /// Nachvollziehbarkeit: Eingespielt wird über Spaltennamen, nicht über
  /// diese Zahl.
  final int schemaVersion;

  /// App-Version zum Zeitpunkt der Sicherung. Steht in der Anzeige, damit der
  /// User zwei Dateien auseinanderhalten kann.
  final String appVersion;

  final DateTime createdAt;

  /// Tabellenname -> Zeilen, Zeile als Spaltenname -> Wert.
  final Map<String, List<Map<String, Object?>>> tables;

  /// Wie viele Zeilen insgesamt drinstehen.
  int get rowCount => tables.values.fold(0, (sum, rows) => sum + rows.length);

  /// Zeilen je Tabelle, leere Tabellen weggelassen – für die Anzeige.
  Map<String, int> get rowCounts => {
    for (final entry in tables.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value.length,
  };

  Map<String, Object?> toJson() {
    final payload = _payload();
    return {
      'format': format,
      'formatVersion': formatVersion,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
      // Die Prüfsumme deckt genau den Nutzdatenteil ab. Eine abgeschnittene
      // oder halb übertragene Datei fällt damit auf, bevor sie eingespielt
      // wird – statt als halb eingespielte Historie zu enden.
      'checksum': checksumOf(payload),
      'tables': payload,
    };
  }

  static Map<String, Object?> _tableJson(
    Map<String, List<Map<String, Object?>>> tables,
  ) => {for (final entry in tables.entries) entry.key: entry.value};

  Map<String, Object?> _payload() => _tableJson(tables);

  /// SHA-256 über die Nutzdaten in ihrer JSON-Form.
  static String checksumOf(Map<String, Object?> payload) {
    final bytes = utf8.encode(jsonEncode(payload));
    return sha256.convert(bytes).toString();
  }

  /// Liest eine Sicherung aus ihrer JSON-Form.
  ///
  /// Wirft [BackupFormatException], wenn das keine Neurohelp-Sicherung ist
  /// oder die Datei unterwegs beschädigt wurde.
  static BackupDocument fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const BackupFormatException(
        BackupProblem.notABackup,
        'Diese Datei ist keine Sicherung von Neurohelp.',
      );
    }

    if (raw['format'] != format) {
      throw const BackupFormatException(
        BackupProblem.notABackup,
        'Diese Datei ist keine Sicherung von Neurohelp.',
      );
    }

    final fileFormat = raw['formatVersion'];
    if (fileFormat is int && fileFormat > formatVersion) {
      throw BackupFormatException(
        BackupProblem.tooNew,
        'Diese Sicherung stammt aus einer neueren Version von Neurohelp. '
        'Aktualisiere die App, dann lässt sie sich einspielen.',
        technical: 'formatVersion $fileFormat > $formatVersion',
      );
    }

    final rawTables = raw['tables'];
    if (rawTables is! Map<String, Object?>) {
      throw const BackupFormatException(
        BackupProblem.damaged,
        'In der Datei stehen keine Daten.',
      );
    }

    final expected = raw['checksum'];
    if (expected is String && expected.isNotEmpty) {
      final actual = checksumOf(rawTables);
      if (actual != expected) {
        throw const BackupFormatException(
          BackupProblem.damaged,
          'Die Datei ist unterwegs beschädigt worden. Nimm eine andere '
          'Sicherung – diese hier lässt sich nicht mehr einspielen.',
        );
      }
    }

    final tables = <String, List<Map<String, Object?>>>{};
    for (final entry in rawTables.entries) {
      final rows = entry.value;
      if (rows is! List) continue;

      tables[entry.key] = [
        for (final row in rows)
          if (row is Map<String, Object?>) Map<String, Object?>.from(row),
      ];
    }

    return BackupDocument(
      schemaVersion: (raw['schemaVersion'] as int?) ?? 0,
      appVersion: (raw['appVersion'] as String?) ?? 'unbekannt',
      createdAt:
          DateTime.tryParse((raw['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      tables: tables,
    );
  }
}

/// Woran das Einlesen gescheitert ist.
enum BackupProblem {
  /// Die Datei gehört zu einem anderen Programm.
  notABackup,

  /// Prüfsumme passt nicht, Datei abgeschnitten oder halb übertragen.
  damaged,

  /// Neueres Dateiformat, als diese App lesen kann.
  tooNew,

  /// Die Datei war gar nicht lesbar – kein Zugriff, Ordner weg.
  unreadable,
}

/// Mit dieser Datei ist etwas nicht in Ordnung.
///
/// [reason] ist der Satz, der auf den Bildschirm darf. [technical] ist für das
/// aufklappbare Kleingedruckte und darf beliebig kryptisch sein.
class BackupFormatException implements Exception {
  const BackupFormatException(this.problem, this.reason, {this.technical});

  final BackupProblem problem;
  final String reason;
  final String? technical;

  @override
  String toString() => 'BackupFormatException(${problem.name}): $reason';
}
