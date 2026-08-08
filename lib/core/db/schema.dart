/// Schema der lokalen SQLite-Datenbank.
///
/// Grundsatz aus dem Konzept (Abschnitt 14): **Alle Nutzerdaten liegen lokal
/// auf dem Gerät.** Diese Datei ist die einzige Stelle, an der DDL steht.
///
/// Migrationen werden **nie** verändert, nur angehängt. Jede neue Version
/// bekommt einen neuen Eintrag in [migrations].
abstract final class DbSchema {
  /// Aktuelle Schemaversion. Muss der Anzahl der Migrationen entsprechen.
  static const int version = 2;

  static const String tableEntries = 'history_entries';
  static const String tableEvents = 'history_events';
  static const String tableSettings = 'settings';

  /// Migration je Zielversion. Index 0 führt von „leer" auf Version 1.
  static const List<List<String>> migrations = [_v1, _v2];

  static const List<String> _v1 = [
    '''
    CREATE TABLE $tableEntries (
      id            TEXT    PRIMARY KEY,
      feature       TEXT    NOT NULL,
      title         TEXT    NOT NULL,
      contact       TEXT,
      status        TEXT    NOT NULL,
      created_at    INTEGER NOT NULL,
      updated_at    INTEGER NOT NULL,
      closed_at     INTEGER,
      follow_up_count    INTEGER NOT NULL DEFAULT 0,
      last_follow_up_at  INTEGER
    )
    ''',
    '''
    CREATE TABLE $tableEvents (
      id         TEXT    PRIMARY KEY,
      entry_id   TEXT    NOT NULL,
      kind       TEXT    NOT NULL,
      note       TEXT,
      data       TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (entry_id) REFERENCES $tableEntries (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_entries_feature ON $tableEntries (feature)',
    'CREATE INDEX idx_entries_status ON $tableEntries (status)',
    'CREATE INDEX idx_entries_updated ON $tableEntries (updated_at DESC)',
    'CREATE INDEX idx_events_entry ON $tableEvents (entry_id, created_at)',
  ];

  /// Version 2: Einstellungen und Onboarding-Zustand.
  ///
  /// Bewusst ein schlichter Schlüssel/Wert-Speicher – Einstellungen sind
  /// wenige Zeilen und ändern sich häufiger als ein Schema.
  static const List<String> _v2 = [
    '''
    CREATE TABLE $tableSettings (
      key        TEXT    PRIMARY KEY,
      value      TEXT    NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''',
  ];
}
