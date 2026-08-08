/// Schema der lokalen SQLite-Datenbank.
///
/// Grundsatz aus dem Konzept (Abschnitt 14): **Alle Nutzerdaten liegen lokal
/// auf dem Gerät.** Diese Datei ist die einzige Stelle, an der DDL steht.
///
/// Migrationen werden **nie** verändert, nur angehängt. Jede neue Version
/// bekommt einen neuen Eintrag in [migrations].
abstract final class DbSchema {
  /// Aktuelle Schemaversion. Muss der Anzahl der Migrationen entsprechen.
  static const int version = 5;

  static const String tableEntries = 'history_entries';
  static const String tableEvents = 'history_events';
  static const String tableSettings = 'settings';
  static const String tableTaskNodes = 'task_nodes';
  static const String tableMessages = 'messages';
  static const String tableCalls = 'calls';

  /// Migration je Zielversion. Index 0 führt von „leer" auf Version 1.
  static const List<List<String>> migrations = [_v1, _v2, _v3, _v4, _v5];

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

  /// Version 3: zerlegte Aufgaben als Baum (Konzept, Abschnitt 11).
  ///
  /// `parent_id` verweist auf dieselbe Tabelle – dadurch beliebig tief.
  static const List<String> _v3 = [
    '''
    CREATE TABLE $tableTaskNodes (
      id         TEXT    PRIMARY KEY,
      entry_id   TEXT    NOT NULL,
      parent_id  TEXT,
      title      TEXT    NOT NULL,
      note       TEXT,
      position   INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      done_at    INTEGER,
      FOREIGN KEY (entry_id) REFERENCES $tableEntries (id) ON DELETE CASCADE,
      FOREIGN KEY (parent_id) REFERENCES $tableTaskNodes (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_task_nodes_entry ON $tableTaskNodes (entry_id)',
    'CREATE INDEX idx_task_nodes_parent '
        'ON $tableTaskNodes (parent_id, position)',
  ];

  /// Version 4: verfasste Nachrichten (Konzept, Abschnitt 10).
  ///
  /// Gespeichert wird der verfasste Text, der Empfänger, das Datum und der
  /// Status. Ob eine Mail tatsächlich rausging, kann die App nicht wissen –
  /// daher der Zwischenstand „übergeben".
  static const List<String> _v4 = [
    '''
    CREATE TABLE $tableMessages (
      id             TEXT    PRIMARY KEY,
      entry_id       TEXT    NOT NULL,
      subject        TEXT    NOT NULL,
      channel        TEXT    NOT NULL,
      recipient_type TEXT,
      recipient      TEXT,
      body           TEXT    NOT NULL DEFAULT '',
      compose_mode   TEXT    NOT NULL,
      state          TEXT    NOT NULL,
      created_at     INTEGER NOT NULL,
      handed_over_at INTEGER,
      FOREIGN KEY (entry_id) REFERENCES $tableEntries (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_messages_entry ON $tableMessages (entry_id)',
    'CREATE INDEX idx_messages_state ON $tableMessages (state)',
  ];

  /// Version 5: vorbereitete Anrufe (Konzept, Abschnitt 8).
  ///
  /// Die Stichpunkte stehen als eine Zeile pro Punkt in `talking_points` –
  /// einfacher als JSON und beim Hineinschauen lesbar.
  static const List<String> _v5 = [
    '''
    CREATE TABLE $tableCalls (
      id             TEXT    PRIMARY KEY,
      entry_id       TEXT    NOT NULL,
      category       TEXT    NOT NULL,
      situation      TEXT    NOT NULL DEFAULT '',
      goal           TEXT,
      contact_name   TEXT,
      contact_number TEXT,
      talking_points TEXT    NOT NULL DEFAULT '',
      note           TEXT,
      outcome        TEXT    NOT NULL,
      created_at     INTEGER NOT NULL,
      called_at      INTEGER,
      FOREIGN KEY (entry_id) REFERENCES $tableEntries (id) ON DELETE CASCADE
    )
    ''',
    'CREATE INDEX idx_calls_entry ON $tableCalls (entry_id)',
    'CREATE INDEX idx_calls_category ON $tableCalls (category)',
  ];
}
