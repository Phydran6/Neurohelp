import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/history/data/sqlite_history_repository.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/core/history/domain/history_event.dart';
import 'package:neurohelp/features/messages/data/sqlite_message_repository.dart';
import 'package:neurohelp/features/messages/domain/message_draft.dart';
import 'package:neurohelp/features/messages/domain/message_flow.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late SqliteHistoryRepository history;
  late SqliteMessageRepository messages;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    var counter = 0;
    String nextId() => 'id-${++counter}';

    history = SqliteHistoryRepository(database.raw, idGenerator: nextId);
    messages = SqliteMessageRepository(
      database.raw,
      history,
      idGenerator: nextId,
    );
  });

  tearDown(() => database.close());

  Future<MessageDraft> readyDraft() async {
    final draft = await messages.create(subject: 'Neue Versichertenkarte');
    return messages.save(
      draft.copyWith(
        recipientType: 'Krankenkasse',
        recipient: 'service@aok.example',
        body: 'Meine Karte ist abgelaufen.',
      ),
    );
  }

  group('Anlegen', () {
    test('eröffnet einen Historien-Vorgang', () async {
      final draft = await messages.create(subject: 'Neue Karte');

      final entry = await history.entryById(draft.entryId);
      expect(entry!.feature, HistoryFeature.message);
      expect(draft.state, MessageState.draft);
      expect(draft.isReadyToSend, isFalse);
    });
  });

  group('Übergeben', () {
    test('verlangt Empfänger und Text', () async {
      final draft = await messages.create(subject: 'Neue Karte');

      expect(() => messages.handOver(draft.id), throwsStateError);
    });

    test('setzt den Vorgang auf übergeben, nicht auf erledigt', () async {
      final draft = await messages.handOver((await readyDraft()).id);

      expect(draft.state, MessageState.handedOver);
      expect(draft.needsFollowUp, isTrue);

      final entry = await history.entryById(draft.entryId);
      // Die App kann nicht wissen, ob wirklich gesendet wurde.
      expect(entry!.status, HistoryStatus.handedOver);
      expect(entry.isOpen, isTrue);
    });

    test('taucht in der Liste der offenen Nachfragen auf', () async {
      await messages.handOver((await readyDraft()).id);

      final open = await messages.awaitingConfirmation();
      expect(open, hasLength(1));
    });
  });

  group('Nachfrage', () {
    test('Ja schließt den Vorgang ab', () async {
      final handed = await messages.handOver((await readyDraft()).id);
      final answered = await messages.confirmSent(handed.id, sent: true);

      expect(answered.state, MessageState.confirmed);
      expect(
        (await history.entryById(handed.entryId))!.status,
        HistoryStatus.done,
      );
      expect(await messages.awaitingConfirmation(), isEmpty);
    });

    test('Nein lässt den Vorgang offen liegen, ohne Druck', () async {
      final handed = await messages.handOver((await readyDraft()).id);
      final answered = await messages.confirmSent(handed.id, sent: false);

      expect(answered.state, MessageState.notSent);

      final entry = await history.entryById(handed.entryId);
      expect(entry!.status, HistoryStatus.open);
      expect(entry.isOpen, isTrue);
      // Nachfragen sind auf drei begrenzt – das steckt in der Historie.
      expect(entry.mayFollowUp, isTrue);
    });

    test('wird protokolliert', () async {
      final handed = await messages.handOver((await readyDraft()).id);
      await messages.confirmSent(handed.id, sent: true);

      final kinds = (await history.eventsFor(
        handed.entryId,
      )).map((e) => e.kind);
      expect(kinds, contains(HistoryEventKind.handedOver));
      expect(kinds, contains(HistoryEventKind.followUpAnswered));
    });
  });

  group('Ablauf', () {
    test('verlangt den Inhalt vor dem Empfänger', () async {
      final draft = await messages.create(subject: '');
      var flow = MessageFlow(draft: draft);

      expect(flow.step, MessageStep.subject);
      expect(flow.canAdvance, isFalse);

      flow = flow.withDraft(draft.copyWith(subject: 'Neue Karte'));
      expect(flow.canAdvance, isTrue);

      // Der Historie-Check ist Arbeit der App und blockiert nie.
      flow = flow.advance();
      expect(flow.step, MessageStep.historyCheck);
      expect(flow.canAdvance, isTrue);

      // Erst der Typ, dann die Adresse.
      flow = flow.advance();
      expect(flow.step, MessageStep.recipientType);
      expect(flow.canAdvance, isFalse);
    });

    test('„weiß ich noch nicht" bringt den Ablauf trotzdem weiter', () async {
      final draft = await messages.create(subject: '');
      var flow = MessageFlow(draft: draft);

      // Ohne ausdrückliches „weiß ich nicht" bleibt der Schritt zu.
      expect(flow.canAdvance, isFalse);

      flow = flow.deferSubject();
      expect(flow.canAdvance, isTrue);

      // Und der Vermerk überlebt die nächsten Schritte, statt beim ersten
      // Weiter verlorenzugehen.
      flow = flow.advance().advance();
      expect(flow.step, MessageStep.recipientType);
      expect(flow.subjectDeferred, isTrue);
    });

    test('editAgain führt aus der Vorschau zurück zum Text', () async {
      final draft = await readyDraft();
      final flow = MessageFlow(draft: draft, step: MessageStep.review);

      expect(flow.canAdvance, isTrue);
      expect(flow.editAgain().step, MessageStep.compose);
      // Der Entwurf bleibt dabei unverändert – kein Datenverlust.
      expect(flow.editAgain().draft.body, draft.body);
    });
  });
}
