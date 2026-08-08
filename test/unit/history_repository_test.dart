import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/history/data/sqlite_history_repository.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/history/domain/history_event.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SqliteHistoryRepository repository;
  late DateTime now;
  late int idCounter;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    now = DateTime.utc(2026, 8, 8, 12);
    idCounter = 0;
    repository = SqliteHistoryRepository(
      database.raw,
      clock: () => now,
      idGenerator: () => 'id-${++idCounter}',
    );
  });

  tearDown(() => database.close());

  group('Vorgang anlegen', () {
    test('legt den Eintrag an und protokolliert ihn', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Umzug organisieren',
      );

      expect(entry.status, HistoryStatus.open);
      expect(entry.isOpen, isTrue);
      expect(await repository.entryById(entry.id), isNotNull);

      final events = await repository.eventsFor(entry.id);
      expect(events, hasLength(1));
      expect(events.single.kind, HistoryEventKind.created);
      expect(events.single.note, 'Umzug organisieren');
    });
  });

  group('Historie-Check', () {
    test('openEntries liefert nur unabgeschlossene Vorgänge', () async {
      final offen = await repository.startEntry(
        feature: HistoryFeature.call,
        title: 'Optiker anrufen',
      );
      final fertig = await repository.startEntry(
        feature: HistoryFeature.call,
        title: 'Zahnarzt anrufen',
      );
      await repository.closeEntry(fertig.id);

      final open = await repository.openEntries();

      expect(open.map((e) => e.id), [offen.id]);
    });

    test('openEntries filtert nach Feature', () async {
      await repository.startEntry(
        feature: HistoryFeature.call,
        title: 'Optiker anrufen',
      );
      final nachricht = await repository.startEntry(
        feature: HistoryFeature.message,
        title: 'Mail an die Krankenkasse',
      );

      final result = await repository.openEntries(
        feature: HistoryFeature.message,
      );

      expect(result.map((e) => e.id), [nachricht.id]);
    });
  });

  group('Suche', () {
    test('findet über Titel und Kontakt', () async {
      await repository.startEntry(
        feature: HistoryFeature.message,
        title: 'Mail an die Krankenkasse',
        contact: 'AOK',
      );

      // LIKE ist in SQLite für ASCII ohne Rücksicht auf Groß-/Kleinschreibung.
      expect(await repository.search('krankenkasse'), hasLength(1));
      expect(await repository.search('Kranken'), hasLength(1));
      expect(await repository.search('AOK'), hasLength(1));
      expect(await repository.search('   '), isEmpty);
    });

    test('behandelt LIKE-Sonderzeichen als normalen Text', () async {
      await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Steuer 100% erledigen',
      );
      await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Wäsche',
      );

      expect(await repository.search('100%'), hasLength(1));
    });
  });

  group('Status', () {
    test('closeEntry setzt Endzustand und Abschlusszeitpunkt', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Steuer',
      );

      final closed = await repository.closeEntry(entry.id);

      expect(closed.status, HistoryStatus.done);
      expect(closed.closedAt, now);
      expect(closed.isOpen, isFalse);

      final events = await repository.eventsFor(entry.id);
      expect(events.last.kind, HistoryEventKind.closed);
    });

    test('closeEntry weist Nicht-Endzustände ab', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Steuer',
      );

      expect(
        () => repository.closeEntry(entry.id, status: HistoryStatus.active),
        throwsArgumentError,
      );
    });

    test('Wiederöffnen räumt den Abschlusszeitpunkt weg', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Steuer',
      );
      await repository.closeEntry(entry.id);

      final reopened = await repository.updateStatus(
        entry.id,
        HistoryStatus.active,
      );

      expect(reopened.closedAt, isNull);
      expect(reopened.isOpen, isTrue);
    });
  });

  group('Nachfragen', () {
    test('hört nach maxFollowUps von selbst auf', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.message,
        title: 'Mail an die Krankenkasse',
      );
      await repository.updateStatus(entry.id, HistoryStatus.handedOver);

      for (var round = 1; round <= HistoryEntry.maxFollowUps; round++) {
        final due = await repository.entriesDueForFollowUp();
        expect(due, hasLength(1), reason: 'Runde $round');

        await repository.registerFollowUp(entry.id);
        now = now.add(const Duration(days: 3));
      }

      expect(await repository.entriesDueForFollowUp(), isEmpty);

      final current = await repository.entryById(entry.id);
      expect(current!.followUpCount, HistoryEntry.maxFollowUps);
      expect(current.mayFollowUp, isFalse);
      // Der Vorgang bleibt offen liegen – keine Schuldmechanik.
      expect(current.isOpen, isTrue);
    });

    test('respektiert die Pause zwischen zwei Nachfragen', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.message,
        title: 'Mail an den Vermieter',
      );

      await repository.registerFollowUp(entry.id);

      expect(await repository.entriesDueForFollowUp(), isEmpty);

      now = now.add(const Duration(days: 3));
      expect(await repository.entriesDueForFollowUp(), hasLength(1));
    });

    test('abgeschlossene Vorgänge werden nicht nachgefragt', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Steuer',
      );
      await repository.closeEntry(entry.id);

      expect(await repository.entriesDueForFollowUp(), isEmpty);
    });
  });

  group('Protokoll', () {
    test('speichert Zusatzdaten und liefert sie in Reihenfolge', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Umzug',
      );

      await repository.logEvent(
        entry.id,
        HistoryEventKind.stepDone,
        note: 'Kartons besorgt',
        data: {'step': 1, 'total': 7},
      );

      final events = await repository.eventsFor(entry.id);

      expect(events, hasLength(2));
      expect(events.last.kind, HistoryEventKind.stepDone);
      expect(events.last.data['step'], 1);
      expect(events.last.data['total'], 7);
    });

    test('deleteEntry löscht das Protokoll mit', () async {
      final entry = await repository.startEntry(
        feature: HistoryFeature.task,
        title: 'Umzug',
      );

      await repository.deleteEntry(entry.id);

      expect(await repository.entryById(entry.id), isNull);
      expect(await repository.eventsFor(entry.id), isEmpty);
    });
  });
}
