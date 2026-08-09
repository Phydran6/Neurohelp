import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/history/data/sqlite_history_repository.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/history/domain/history_event.dart';
import 'package:neurohelp/core/settings/data/sqlite_settings_repository.dart';
import 'package:neurohelp/features/calls/data/sqlite_call_repository.dart';
import 'package:neurohelp/features/calls/domain/call_companion.dart';
import 'package:neurohelp/features/calls/domain/call_plan.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SqliteHistoryRepository history;
  late SqliteCallRepository calls;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    var counter = 0;
    String nextId() => 'id-${++counter}';

    history = SqliteHistoryRepository(database.raw, idGenerator: nextId);
    calls = SqliteCallRepository(database.raw, history, idGenerator: nextId);
  });

  tearDown(() => database.close());

  Future<CallPlan> preparedCall() async {
    final plan = await calls.create(category: 'Arzt', topic: 'Sehtest');
    return calls.save(
      plan.copyWith(
        situation: 'Ich sehe schlechter als früher.',
        goal: 'Termin beim Optiker für einen Sehtest',
        contactName: 'Optik Müller',
        contactNumber: '030 1234567',
        talkingPoints: const [
          'Termin für Sehtest',
          'Nachmittags passt besser',
          'Versichertennummer bereithalten',
        ],
      ),
    );
  }

  group('Vorbereiten', () {
    test('eröffnet einen Historien-Vorgang mit Kategorie', () async {
      final plan = await calls.create(category: 'Arzt', topic: 'Sehtest');

      final entry = await history.entryById(plan.entryId);
      expect(entry!.feature, HistoryFeature.call);
      expect(entry.title, 'Sehtest');
      expect(entry.contact, 'Arzt');
      expect(plan.outcome, CallOutcome.open);
    });

    test('ohne Nummer oder Stichpunkte kein Anruf', () async {
      final plan = await calls.create(category: 'Arzt');

      expect(plan.isReadyToCall, isFalse);
      expect(() => calls.markCalled(plan.id), throwsStateError);
    });

    test('Historie-Check findet frühere Anrufe derselben Kategorie', () async {
      await calls.create(category: 'Arzt', topic: 'Sehtest');
      await calls.create(category: 'Arzt', topic: 'Rezept');
      await calls.create(category: 'Versicherung', topic: 'Beitrag');

      final frueher = await calls.previousInCategory('Arzt');

      expect(frueher, hasLength(2));
      expect(frueher.map((c) => c.category), everyElement('Arzt'));
    });
  });

  group('Stichpunkte', () {
    test('überleben das Speichern und Laden', () async {
      final plan = await preparedCall();
      final geladen = await calls.byId(plan.id);

      expect(geladen!.talkingPoints, [
        'Termin für Sehtest',
        'Nachmittags passt besser',
        'Versichertennummer bereithalten',
      ]);
      expect(geladen.isReadyToCall, isTrue);
    });
  });

  group('Nachbereitung', () {
    test('Ja schließt den Vorgang ab', () async {
      final plan = await calls.markCalled((await preparedCall()).id);
      final fertig = await calls.finish(plan.id, succeeded: true);

      expect(fertig.outcome, CallOutcome.succeeded);
      expect(fertig.isDone, isTrue);
      expect(
        (await history.entryById(plan.entryId))!.status,
        HistoryStatus.done,
      );
    });

    test('Nein lässt den Vorgang offen für Weiterhilfe', () async {
      final plan = await calls.markCalled((await preparedCall()).id);
      final fertig = await calls.finish(plan.id, succeeded: false);

      expect(fertig.outcome, CallOutcome.failed);

      final entry = await history.entryById(plan.entryId);
      expect(entry!.status, HistoryStatus.open);
      expect(entry.isOpen, isTrue);
    });

    test('nimmt die Notiz auf, die auf iOS erst hier entstehen kann', () async {
      final plan = await calls.markCalled((await preparedCall()).id);
      await calls.finish(
        plan.id,
        succeeded: true,
        note: 'Termin am 14.08. um 15:30 Uhr.',
      );

      final notes = (await history.eventsFor(
        plan.entryId,
      )).where((e) => e.kind == HistoryEventKind.noteAdded).map((e) => e.note);

      expect(notes, contains('Termin am 14.08. um 15:30 Uhr.'));
    });
  });

  group('Begleitung', () {
    test('die Wahl wird einmalig gemerkt', () async {
      final settings = SqliteSettingsRepository(database.raw);

      expect((await settings.load()).companionStyle, CompanionStyle.none);

      await settings.setCompanionStyle(CompanionStyle.overlay);
      expect((await settings.load()).companionStyle, CompanionStyle.overlay);
    });

    test('ohne Begleitung funktioniert der Anruf trotzdem', () async {
      const companion = NoCallCompanion();

      expect(companion.availableStyles, isEmpty);
      expect(companion.supportsLiveNotes, isFalse);
      expect(await companion.requestPermission(), isFalse);

      // Der Anruf selbst hängt nicht an der Begleitung.
      final plan = await calls.markCalled((await preparedCall()).id);
      expect(plan.calledAt, isNotNull);
    });
  });
}
