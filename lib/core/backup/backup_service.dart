import 'package:sqflite/sqflite.dart';

import '../config/app_version.dart';
import '../db/schema.dart';
import '../logging/app_logger.dart';
import 'backup_document.dart';

/// Wie eine Sicherung eingespielt wird.
enum RestoreMode {
  /// Alles auf dem Gerät wird durch die Sicherung ersetzt.
  ///
  /// Der Normalfall nach einer Neuinstallation: Es ist ohnehin nichts da.
  replace,

  /// Die Sicherung wird dazugelegt.
  ///
  /// Gleiche Vorgänge – gleiche Id – werden dabei überschrieben. Ein zweites
  /// Einspielen derselben Datei ändert deshalb nichts, statt alles zu
  /// verdoppeln.
  merge,
}

/// Was beim Einspielen herausgekommen ist.
///
/// Wird angezeigt: Wer eine Sicherung einspielt, will wissen, ob wirklich
/// alles da ist – „fertig" allein ist zu wenig.
class RestoreReport {
  const RestoreReport({
    required this.restored,
    required this.skippedTables,
    required this.skippedRows,
  });

  /// Tabellenname -> übernommene Zeilen.
  final Map<String, int> restored;

  /// Tabellen aus der Datei, die diese App nicht (mehr) kennt.
  ///
  /// Der Fall „Sicherung aus einer neueren App": Was hier steht, ist
  /// verloren, und das wird gesagt statt verschwiegen.
  final List<String> skippedTables;

  /// Einzelne Zeilen, die nicht in die Datenbank passten.
  final int skippedRows;

  int get rowCount => restored.values.fold(0, (sum, count) => sum + count);

  bool get isComplete => skippedTables.isEmpty && skippedRows == 0;
}

/// Sicherung schreiben und einspielen.
///
/// Die Schicht kennt keine Datei und keinen Speicherort – nur die Datenbank
/// und ein [BackupDocument]. Wohin die Datei geht, entscheidet die
/// Oberfläche (Konzept, Abschnitt 14: lokal-first, der User bestimmt).
class BackupService {
  BackupService(this._db, {DateTime Function()? clock, String? appVersion})
    : _now = clock ?? DateTime.now,
      _appVersion = appVersion ?? AppVersion.name;

  final Database _db;
  final DateTime Function() _now;
  final String _appVersion;

  /// Einstellungen, die **nicht** mitgesichert werden.
  ///
  /// Die App-Sperre gehört dazu. Die PIN selbst liegt im Schlüsselbund des
  /// Geräts und kommt bewusst nicht in die Datei – eine Sicherung, die den
  /// Zugang zum Gerät mitliefert, wäre das Gegenteil von Sicherheit. Stünde
  /// aber die Sperre drin und die PIN nicht, verlangte die App nach dem
  /// Einspielen eine PIN, die es nirgends gibt. Also bleibt beides draußen
  /// und wird auf dem neuen Gerät neu eingerichtet.
  static const Set<String> excludedSettings = {'lock_method'};

  /// Liest alle Nutzerdaten aus der Datenbank.
  Future<BackupDocument> create() async {
    final tables = <String, List<Map<String, Object?>>>{};

    for (final table in DbSchema.userTables) {
      final rows = await _db.query(table);
      tables[table] = [
        for (final row in rows)
          if (!_isExcluded(table, row)) Map<String, Object?>.from(row),
      ];
    }

    final document = BackupDocument(
      schemaVersion: DbSchema.version,
      appVersion: _appVersion,
      createdAt: _now(),
      tables: tables,
    );

    AppLogger.info(
      'Sicherung erstellt: ${document.rowCount} Zeilen',
      scope: 'backup',
    );
    return document;
  }

  static bool _isExcluded(String table, Map<String, Object?> row) {
    if (table != DbSchema.tableSettings) return false;
    return excludedSettings.contains(row['key']);
  }

  /// Spielt [document] ein.
  ///
  /// **Versionstolerant:** Spalten, die es in dieser App nicht gibt, werden
  /// weggelassen; Spalten, die die Sicherung nicht kennt, bekommen ihren
  /// Standardwert. Deshalb lässt sich eine Sicherung aus jeder Version
  /// einspielen, ohne dass hier Migrationen stehen müssten.
  Future<RestoreReport> restore(
    BackupDocument document, {
    RestoreMode mode = RestoreMode.replace,
  }) async {
    final known = DbSchema.userTables.toSet();
    final skippedTables = [
      for (final table in document.tables.keys)
        if (!known.contains(table) && document.tables[table]!.isNotEmpty) table,
    ];

    final columns = <String, Set<String>>{};
    for (final table in DbSchema.userTables) {
      columns[table] = await _columnsOf(table);
    }

    // Fremdschlüssel für die Dauer des Einspielens abschalten. Die
    // Unterpunkte einer Aufgabe zeigen auf dieselbe Tabelle; in welcher
    // Reihenfolge sie in der Datei stehen, weiß niemand. Ohne das müsste die
    // Sicherung sortiert sein, um einspielbar zu sein.
    await _db.execute('PRAGMA foreign_keys = OFF');

    final restored = <String, int>{};
    var skippedRows = 0;

    try {
      await _db.transaction((txn) async {
        if (mode == RestoreMode.replace) {
          for (final table in DbSchema.userTables) {
            await txn.delete(table);
          }
        }

        // Eltern vor Kindern: [DbSchema.userTables] steht in Löschreihenfolge,
        // also Kinder zuerst. Beim Schreiben gilt sie umgekehrt.
        for (final table in DbSchema.userTables.reversed) {
          final rows = document.tables[table];
          if (rows == null || rows.isEmpty) continue;

          var written = 0;
          for (final row in rows) {
            if (_isExcluded(table, row)) continue;

            final values = <String, Object?>{
              for (final entry in row.entries)
                if (columns[table]!.contains(entry.key))
                  entry.key: _sqlValue(entry.value),
            };
            if (values.isEmpty) {
              skippedRows++;
              continue;
            }

            try {
              await txn.insert(
                table,
                values,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              written++;
            } on DatabaseException catch (error) {
              // Eine einzelne kaputte Zeile darf nicht die ganze Sicherung
              // zu Fall bringen. Sie wird gezählt und am Ende gemeldet.
              skippedRows++;
              AppLogger.warning(
                'Zeile in $table übersprungen: $error',
                scope: 'backup',
              );
            }
          }
          restored[table] = written;
        }
      });
    } finally {
      await _db.execute('PRAGMA foreign_keys = ON');
    }

    final report = RestoreReport(
      restored: restored,
      skippedTables: skippedTables,
      skippedRows: skippedRows,
    );

    AppLogger.info(
      'Sicherung eingespielt: ${report.rowCount} Zeilen, '
      '${report.skippedRows} übersprungen',
      scope: 'backup',
    );
    return report;
  }

  /// Die Spalten, die diese App in [table] hat.
  Future<Set<String>> _columnsOf(String table) async {
    final info = await _db.rawQuery('PRAGMA table_info($table)');
    return {for (final row in info) row['name']! as String};
  }

  /// JSON kennt weniger Typen als SQLite.
  ///
  /// Wahrheitswerte kommen als `true`/`false` zurück, SQLite will 1 und 0.
  /// Alles, was keine Zahl, kein Text und kein `null` ist, wird zu Text –
  /// besser ein lesbarer Wert als eine abgelehnte Zeile.
  static Object? _sqlValue(Object? value) => switch (value) {
    null || int() || double() || String() => value,
    bool() => value ? 1 : 0,
    _ => value.toString(),
  };
}
