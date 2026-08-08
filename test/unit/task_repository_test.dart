import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/history/data/sqlite_history_repository.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/history/domain/history_event.dart';
import 'package:neurohelp/features/tasks/data/sqlite_task_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SqliteHistoryRepository history;
  late SqliteTaskRepository tasks;
  late int idCounter;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    idCounter = 0;
    String nextId() => 'id-${++idCounter}';

    history = SqliteHistoryRepository(database.raw, idGenerator: nextId);
    tasks = SqliteTaskRepository(database.raw, history, idGenerator: nextId);
  });

  tearDown(() => database.close());

  group('Anlegen', () {
    test('eröffnet einen Historien-Vorgang', () async {
      final entryId = await tasks.createTask('Umzug organisieren');

      final entry = await history.entryById(entryId);
      expect(entry, isNotNull);
      expect(entry!.feature, HistoryFeature.task);
      expect(entry.title, 'Umzug organisieren');
      expect(entry.isOpen, isTrue);
    });

    test(
      'addSteps legt die Schritte in der gegebenen Reihenfolge an',
      () async {
        final entryId = await tasks.createTask('Umzug');
        await tasks.addSteps(
          entryId,
          titles: ['Kartons besorgen', 'Kündigung schreiben', 'Umzug anmelden'],
        );

        final tree = await tasks.loadTree(entryId);
        expect(tree.roots.map((n) => n.title), [
          'Kartons besorgen',
          'Kündigung schreiben',
          'Umzug anmelden',
        ]);
      },
    );
  });

  group('Baumstruktur', () {
    test('trägt beliebig tiefe Unterpunkte', () async {
      final entryId = await tasks.createTask('Steuer');
      final unterlagen = await tasks.addStep(entryId, title: 'Unterlagen');
      final lohn = await tasks.addStep(
        entryId,
        title: 'Lohnbescheinigung',
        parentId: unterlagen.id,
      );
      final suchen = await tasks.addStep(
        entryId,
        title: 'Im Ordner nachsehen',
        parentId: lohn.id,
        note: 'Blauer Ordner im Regal.',
      );

      final tree = await tasks.loadTree(entryId);

      expect(tree.roots.single.title, 'Unterlagen');
      expect(tree.childrenOf(unterlagen.id).single.id, lohn.id);
      expect(tree.pathTo(suchen.id).map((n) => n.title), [
        'Unterlagen',
        'Lohnbescheinigung',
        'Im Ordner nachsehen',
      ]);
      expect(tree.nodeById(suchen.id)!.note, 'Blauer Ordner im Regal.');
    });

    test('nur die untersten Punkte sind ausführbare Schritte', () async {
      final entryId = await tasks.createTask('Steuer');
      final oben = await tasks.addStep(entryId, title: 'Unterlagen');
      await tasks.addStep(entryId, title: 'Lohn', parentId: oben.id);
      await tasks.addStep(entryId, title: 'Spenden', parentId: oben.id);

      final tree = await tasks.loadTree(entryId);
      expect(tree.steps.map((n) => n.title), ['Lohn', 'Spenden']);
    });
  });

  group('Fokus-Modus', () {
    test('liefert immer nur den nächsten offenen Schritt', () async {
      final entryId = await tasks.createTask('Umzug');
      final steps = await tasks.addSteps(
        entryId,
        titles: ['Kartons', 'Kündigung', 'Ummelden'],
      );

      expect((await tasks.nextStep(entryId))!.title, 'Kartons');

      await tasks.completeStep(entryId, steps[0].id);
      expect((await tasks.nextStep(entryId))!.title, 'Kündigung');

      await tasks.completeStep(entryId, steps[1].id);
      await tasks.completeStep(entryId, steps[2].id);
      expect(await tasks.nextStep(entryId), isNull);
    });

    test('steigt in Unterpunkte ab', () async {
      final entryId = await tasks.createTask('Steuer');
      final oben = await tasks.addStep(entryId, title: 'Unterlagen');
      final lohn = await tasks.addStep(
        entryId,
        title: 'Lohn raussuchen',
        parentId: oben.id,
      );

      expect((await tasks.nextStep(entryId))!.id, lohn.id);
    });
  });

  group('Abhaken', () {
    test('ist endgültig und lässt sich nicht wiederholen', () async {
      final entryId = await tasks.createTask('Wäsche');
      final step = await tasks.addStep(entryId, title: 'Waschen');

      await tasks.completeStep(entryId, step.id);

      expect(() => tasks.completeStep(entryId, step.id), throwsStateError);
    });

    test('Punkte mit Unterpunkten sind nicht direkt abhakbar', () async {
      final entryId = await tasks.createTask('Steuer');
      final oben = await tasks.addStep(entryId, title: 'Unterlagen');
      await tasks.addStep(entryId, title: 'Lohn', parentId: oben.id);

      expect(() => tasks.completeStep(entryId, oben.id), throwsStateError);
    });

    test(
      'Elternpunkt gilt als erledigt, wenn alle Kinder erledigt sind',
      () async {
        final entryId = await tasks.createTask('Steuer');
        final oben = await tasks.addStep(entryId, title: 'Unterlagen');
        final a = await tasks.addStep(
          entryId,
          title: 'Lohn',
          parentId: oben.id,
        );
        final b = await tasks.addStep(
          entryId,
          title: 'Spenden',
          parentId: oben.id,
        );

        var tree = await tasks.completeStep(entryId, a.id);
        expect(tree.isDone(oben.id), isFalse);

        tree = await tasks.completeStep(entryId, b.id);
        expect(tree.isDone(oben.id), isTrue);
        expect(tree.isComplete, isTrue);
      },
    );

    test('schließt den Vorgang ab, sobald nichts mehr offen ist', () async {
      final entryId = await tasks.createTask('Wäsche');
      final step = await tasks.addStep(entryId, title: 'Waschen');

      await tasks.completeStep(entryId, step.id);

      final entry = await history.entryById(entryId);
      expect(entry!.status, HistoryStatus.done);
      expect(entry.isOpen, isFalse);
    });
  });

  group('Protokoll', () {
    test('schreibt jeden angelegten und abgehakten Schritt mit', () async {
      final entryId = await tasks.createTask('Umzug');
      final step = await tasks.addStep(entryId, title: 'Kartons');
      await tasks.completeStep(entryId, step.id);

      final kinds = (await history.eventsFor(entryId)).map((e) => e.kind);

      expect(
        kinds,
        containsAllInOrder([
          HistoryEventKind.created,
          HistoryEventKind.stepAdded,
          HistoryEventKind.stepDone,
          HistoryEventKind.closed,
        ]),
      );
    });

    test('hält den Fortschritt für die Historie fest', () async {
      final entryId = await tasks.createTask('Umzug');
      final steps = await tasks.addSteps(entryId, titles: ['A', 'B']);

      await tasks.completeStep(entryId, steps[0].id);

      final event = (await history.eventsFor(
        entryId,
      )).lastWhere((e) => e.kind == HistoryEventKind.stepDone);

      expect(event.data['done'], 1);
      expect(event.data['total'], 2);
    });
  });

  group('Bearbeiten', () {
    test('ändert Titel und Notiz', () async {
      final entryId = await tasks.createTask('Umzug');
      final step = await tasks.addStep(entryId, title: 'Kartons');

      final updated = await tasks.editStep(
        step.id,
        title: 'Kartons besorgen',
        note: 'Im Baumarkt fragen.',
      );

      expect(updated.title, 'Kartons besorgen');
      expect(updated.note, 'Im Baumarkt fragen.');
    });

    test('removeStep entfernt den Punkt samt Unterpunkten', () async {
      final entryId = await tasks.createTask('Steuer');
      final oben = await tasks.addStep(entryId, title: 'Unterlagen');
      await tasks.addStep(entryId, title: 'Lohn', parentId: oben.id);

      await tasks.removeStep(entryId, oben.id);

      expect((await tasks.loadTree(entryId)).isEmpty, isTrue);
    });
  });
}
