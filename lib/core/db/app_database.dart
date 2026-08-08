import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../logging/app_logger.dart';
import 'schema.dart';

/// Zugang zur lokalen SQLite-Datenbank.
///
/// Die Datenbank ist der einzige Speicherort für Nutzerdaten (Konzept,
/// Abschnitt 14 – lokal-first). Nichts davon verlässt das Gerät.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  Database get raw => _db;

  static const String defaultFileName = 'neurohelp.db';

  /// Öffnet die Datenbank und wendet ausstehende Migrationen an.
  ///
  /// [path] überschreibt den Standardort – für Tests kann
  /// `inMemoryDatabasePath` übergeben werden.
  static Future<AppDatabase> open({String? path}) async {
    final location = path ?? p.join(await getDatabasesPath(), defaultFileName);

    final db = await openDatabase(
      location,
      version: DbSchema.version,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return AppDatabase._(db);
  }

  static Future<void> _onConfigure(Database db) async {
    // Ohne das greifen die ON DELETE CASCADE-Regeln nicht.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Datenbank wird neu angelegt (v$version)', scope: 'db');
    await _applyMigrations(db, from: 0, to: version);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    AppLogger.info('Datenbank-Migration $from -> $to', scope: 'db');
    await _applyMigrations(db, from: from, to: to);
  }

  static Future<void> _applyMigrations(
    Database db, {
    required int from,
    required int to,
  }) async {
    for (var version = from; version < to; version++) {
      for (final statement in DbSchema.migrations[version]) {
        await db.execute(statement);
      }
    }
  }

  Future<void> close() => _db.close();
}
