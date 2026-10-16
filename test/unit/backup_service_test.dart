import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/backup/backup_document.dart';
import 'package:neurohelp/core/backup/backup_service.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/db/schema.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/settings/app_settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prüft das Sichern und Einspielen gegen eine echte Datenbank.
///
/// Der Kern ist die **Versionstoleranz**: Eine Sicherung aus einer älteren
/// oder einer neueren App muss sich einspielen lassen. Ohne diesen Test
/// merkt man das erst, wenn jemand nach einem Update ohne seine Daten
/// dasteht – und dann ist es zu spät.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late AppServices services;
  late BackupService backup;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    services = AppServices.from(database);
    backup = services.backup;
  });

  tearDown(() => database.close());

  Future<HistoryEntry> seedEntry(String title) =>
      services.history.startEntry(feature: HistoryFeature.task, title: title);

  group('Sichern', () {
    test('nimmt Vorgänge, Protokoll und Einstellungen mit', () async {
      final entry = await seedEntry('Umzug organisieren');
      await services.tasks.addSteps(entry.id, titles: ['Kartons besorgen']);
      await services.settings.setTone(AiTone.sachlich);

      final document = await backup.create();

      expect(document.schemaVersion, DbSchema.version);
      expect(document.tables[DbSchema.tableEntries], hasLength(1));
      expect(document.tables[DbSchema.tableTaskNodes], hasLength(1));
      expect(
        document.tables[DbSchema.tableSettings]!.map((row) => row['key']),
        contains('tone'),
      );
    });

    test('lässt die App-Sperre draußen', () async {
      // Die PIN selbst liegt im Schlüsselbund und kommt nicht mit. Stünde
      // die Sperre trotzdem in der Datei, verlangte die App nach dem
      // Einspielen eine PIN, die es nirgends gibt.
      await services.settings.setLockMethod(LockMethod.pin);

      final document = await backup.create();
      final keys = document.tables[DbSchema.tableSettings]!
          .map((row) => row['key'])
          .toList();

      expect(keys, isNot(contains('lock_method')));
    });
  });

  group('Einspielen', () {
    test('holt alles zurück, nachdem das Gerät leergeräumt wurde', () async {
      final entry = await seedEntry('Zahnarzt anrufen');
      await services.settings.setTone(AiTone.neutral);
      final document = await backup.create();

      await services.wipeLocalData();
      expect(await services.history.entryById(entry.id), isNull);

      final report = await backup.restore(document);
      await services.settings.load();

      expect(report.isComplete, isTrue);
      expect(
        (await services.history.entryById(entry.id))?.title,
        'Zahnarzt anrufen',
      );
      expect(services.settings.current.tone, AiTone.neutral);
    });

    test('ersetzt standardmäßig, statt zu verdoppeln', () async {
      await seedEntry('Alter Vorgang');
      final document = await backup.create();

      await seedEntry('Dazugekommen');
      expect(await services.history.recentEntries(), hasLength(2));

      await backup.restore(document);
      final left = await services.history.recentEntries();

      expect(left, hasLength(1));
      expect(left.single.title, 'Alter Vorgang');
    });

    test('legt auf Wunsch dazu, statt wegzuwerfen', () async {
      await seedEntry('Alter Vorgang');
      final document = await backup.create();

      await seedEntry('Dazugekommen');
      await backup.restore(document, mode: RestoreMode.merge);

      final titles = (await services.history.recentEntries())
          .map((entry) => entry.title)
          .toList();
      expect(titles, containsAll(['Alter Vorgang', 'Dazugekommen']));
    });

    test('zweimal dieselbe Datei ändert beim Dazulegen nichts', () async {
      await seedEntry('Nur einmal da');
      final document = await backup.create();

      await backup.restore(document, mode: RestoreMode.merge);
      await backup.restore(document, mode: RestoreMode.merge);

      expect(await services.history.recentEntries(), hasLength(1));
    });

    test('übergeht Spalten, die es in dieser App nicht gibt', () async {
      // Der Fall „Sicherung aus einer neueren App": Dort hatte die Tabelle
      // ein Feld mehr. Es wird weggelassen, der Rest kommt an.
      final entry = await seedEntry('Aus der Zukunft');
      final document = await backup.create();
      document.tables[DbSchema.tableEntries]!.single['sternzeichen'] = 'Waage';

      await services.wipeLocalData();
      final report = await backup.restore(document);

      expect(report.skippedRows, 0);
      expect(
        (await services.history.entryById(entry.id))?.title,
        'Aus der Zukunft',
      );
    });

    test('füllt Spalten, die die Sicherung nicht kannte', () async {
      // Der Fall „Sicherung aus einer älteren App": Dort gab es das Feld
      // noch nicht. Es bekommt den Standardwert aus dem Schema.
      final entry = await seedEntry('Aus der Vergangenheit');
      final document = await backup.create();
      document.tables[DbSchema.tableEntries]!.single.remove('follow_up_count');

      await services.wipeLocalData();
      await backup.restore(document);

      expect((await services.history.entryById(entry.id))?.followUpCount, 0);
    });

    test('meldet Tabellen, die diese App nicht kennt', () async {
      final document = BackupDocument(
        schemaVersion: 99,
        appVersion: '9.9.9',
        createdAt: DateTime(2030),
        tables: {
          DbSchema.tableEntries: const [],
          'tagebuch': [
            {'id': 'x', 'text': 'aus einer neueren Version'},
          ],
        },
      );

      final report = await backup.restore(document);

      expect(report.skippedTables, ['tagebuch']);
      expect(report.isComplete, isFalse);
    });

    test('eine kaputte Zeile reißt nicht die ganze Sicherung mit', () async {
      await seedEntry('Heile Zeile');
      final document = await backup.create();

      // Ohne Pflichtfeld: Diese eine Zeile kann nicht geschrieben werden.
      document.tables[DbSchema.tableEntries]!.add({'id': 'kaputt'});

      await services.wipeLocalData();
      final report = await backup.restore(document);

      expect(report.skippedRows, 1);
      expect(await services.history.recentEntries(), hasLength(1));
    });

    test(
      'bringt Unterpunkte mit, egal in welcher Reihenfolge sie stehen',
      () async {
        // Unterpunkte zeigen auf dieselbe Tabelle. Stünde das Kind vor dem
        // Elternteil in der Datei, würde der Fremdschlüssel greifen – deshalb
        // schaltet das Einspielen ihn für die Dauer ab.
        final entry = await seedEntry('Steuer');
        final parent = await services.tasks.addStep(
          entry.id,
          title: 'Unterlagen',
        );
        await services.tasks.addStep(
          entry.id,
          title: 'Lohnbescheinigung suchen',
          parentId: parent.id,
        );

        final document = await backup.create();
        document.tables[DbSchema.tableTaskNodes] = document
            .tables[DbSchema.tableTaskNodes]!
            .reversed
            .toList();

        await services.wipeLocalData();
        final report = await backup.restore(document);

        expect(report.skippedRows, 0);
        expect((await services.tasks.loadTree(entry.id)).steps, hasLength(1));
      },
    );
  });
}
