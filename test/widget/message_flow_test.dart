import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/features/messages/domain/message_draft.dart';
import 'package:neurohelp/features/messages/domain/message_sender.dart';
import 'package:neurohelp/features/messages/presentation/message_start_page.dart';
import 'package:neurohelp/shared/widgets/big_action_button.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Merkt sich, was übergeben wurde, statt eine echte App zu öffnen.
class _RecordingSender implements MessageSender {
  MessageDraft? handedOver;

  @override
  Future<bool> handOver(MessageDraft draft, {String? senderName}) async {
    handedOver = draft;
    return true;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Siehe CLAUDE.md: In Widget-Tests kommt ein Future über eine
    // Isolate-Grenze nie an.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late _RecordingSender sender;

  /// Stellbare Uhr: Die Pause zwischen zwei Nachfragen zählt in Tagen. Ohne
  /// sie ließe sich nicht prüfen, dass die App irgendwann von selbst aufhört.
  late DateTime now;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    sender = _RecordingSender();
    now = DateTime(2026, 8, 14, 10);
    services = AppServices.from(database, sender: sender, clock: () => now);
  });

  tearDown(() => database.close());

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    int tries = 40,
  }) async {
    for (var attempt = 0; attempt < tries; attempt++) {
      if (finder.evaluate().isNotEmpty) {
        await tester.pumpAndSettle();
        return;
      }
      await tester.pump(const Duration(milliseconds: 32));
    }
    fail('Nicht gefunden: $finder');
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: MessageStartPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('msg_new')));
  }

  /// „Neue Nachricht" – und auf die Eingangsfrage: Ich weiß es.
  Future<void> startNew(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('msg_new')));
    await pumpUntil(tester, find.byKey(const Key('msg_know')));
    await tester.tap(find.byKey(const Key('msg_know')));
    await tester.pumpAndSettle();
  }

  /// Beantwortet eine Frage und geht weiter.
  Future<void> answer(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('msg_field')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('msg_next')));
    await tester.pumpAndSettle();
  }

  testWidgets('fragt nach dem Inhalt, bevor es um den Empfänger geht', (
    tester,
  ) async {
    await pumpApp(tester);
    await startNew(tester);

    // Konzept, Abschnitt 10, Schritt 1: Inhalt zuerst, nicht Empfänger.
    expect(find.text('Worum geht es?'), findsOneWidget);

    await answer(tester, 'Neue Versichertenkarte');

    // Erst der Typ …
    expect(find.text('An wen ungefähr?'), findsOneWidget);
    await answer(tester, 'Krankenkasse');

    // … dann die Adresse.
    expect(find.text('Und wohin genau?'), findsOneWidget);
  });

  testWidgets('fragt zuerst, ob man es überhaupt noch weiß', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('msg_new')));
    await pumpUntil(tester, find.byKey(const Key('msg_know')));

    // Kein leeres Feld als erstes Bild – erst die Wahl.
    expect(find.byKey(const Key('msg_recall')), findsOneWidget);
    expect(find.byKey(const Key('msg_field')), findsNothing);

    await tester.tap(find.byKey(const Key('msg_know')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('msg_field')), findsOneWidget);
  });

  testWidgets('gräbt in der Historie, statt das Gedächtnis anzustupsen', (
    tester,
  ) async {
    // Ein früherer Vorgang, an den sich der User nur dunkel erinnert.
    final earlier = await services.messages.create(subject: 'Zuzahlung');
    await services.messages.save(
      earlier.copyWith(recipient: 'service@aok.example', body: 'Text'),
    );
    await services.messages.handOver(earlier.id);

    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('msg_new')));
    await pumpUntil(tester, find.byKey(const Key('msg_recall')));
    await tester.tap(find.byKey(const Key('msg_recall')));
    await pumpUntil(
      tester,
      find.byKey(Key('history_entry_${earlier.entryId}')),
    );

    // Erst gräbt die App: Der Fund steht da, ohne dass jemand tippen musste.
    await tester.tap(find.byKey(Key('history_entry_${earlier.entryId}')));
    await tester.pumpAndSettle();

    // Angetippt heißt: Thema übernommen und einen Schritt weiter.
    expect(find.text('An wen ungefähr?'), findsOneWidget);
  });

  testWidgets('lässt auch weiter, wenn gar nichts kommt', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const Key('msg_new')));
    await pumpUntil(tester, find.byKey(const Key('msg_recall')));
    await tester.tap(find.byKey(const Key('msg_recall')));
    await pumpUntil(tester, find.byKey(const Key('msg_nudges')));

    // Ohne Fund führt die App anders heran – und der Weg bleibt offen,
    // auch wenn nichts im Feld steht.
    final next = tester.widget<BigActionButton>(
      find.byKey(const Key('msg_next')),
    );
    expect(next.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('msg_next')));
    await tester.pumpAndSettle();
    expect(find.text('An wen ungefähr?'), findsOneWidget);
  });

  testWidgets('holt den Text aus der Zwischenablage ins Feld', (tester) async {
    // Statt „Text scannen" im Auswahlmenü: ein eigener Knopf für das, was man
    // an dieser Stelle wirklich will.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? <String, dynamic>{'text': 'Meine Karte ist abgelaufen.'}
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpApp(tester);
    await startNew(tester);

    await answer(tester, 'Neue Karte');
    await answer(tester, 'Krankenkasse');
    await answer(tester, 'service@aok.example');

    await tester.tap(find.byKey(const Key('msg_paste')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('msg_field')));
    expect(field.controller!.text, 'Meine Karte ist abgelaufen.');
  });

  testWidgets('setzt den Floskel-Rahmen in der Vorschau', (tester) async {
    await pumpApp(tester);
    await startNew(tester);

    await answer(tester, 'Neue Karte');
    await answer(tester, 'Krankenkasse');
    await answer(tester, 'service@aok.example');
    await answer(tester, 'Meine Karte ist abgelaufen.');

    final preview = tester.widget<Text>(find.byKey(const Key('msg_preview')));

    expect(preview.data, contains('Guten Tag,'));
    expect(preview.data, contains('Meine Karte ist abgelaufen.'));
    expect(preview.data, contains('Mit freundlichen Grüßen'));
  });

  testWidgets('übergibt an die System-App und merkt sich das als offen', (
    tester,
  ) async {
    await pumpApp(tester);
    await startNew(tester);

    await answer(tester, 'Neue Karte');
    await answer(tester, 'Krankenkasse');
    await answer(tester, 'service@aok.example');
    await answer(tester, 'Meine Karte ist abgelaufen.');

    await tester.tap(find.byKey(const Key('msg_send')));
    await pumpUntil(tester, find.byKey(const Key('msg_new')));

    expect(sender.handedOver, isNotNull);

    // Übergeben heißt nicht gesendet – der Vorgang bleibt offen.
    //
    // Geprüft wird der Vorgang selbst, nicht `awaitingConfirmation`: Die
    // Startseite hat die Nachfrage beim Zurückkommen schon gestellt und
    // gezählt. Sie kommt bewusst erst nach einer Pause wieder – höchstens
    // drei Nachfragen insgesamt (Konzept, Abschnitt 10, Schritt 7).
    final draft = (await services.messages.unfinished()).firstOrNull;
    expect(
      draft,
      isNull,
      reason: 'übergeben ist kein liegengebliebener Entwurf',
    );

    final entry = await services.history.entryById(sender.handedOver!.entryId);
    expect(entry!.status, HistoryStatus.handedOver);
    expect(entry.isOpen, isTrue);
  });

  testWidgets('hört nach drei Nachfragen von selbst auf', (tester) async {
    final draft = await services.messages.create(subject: 'Neue Karte');
    await services.messages.save(
      draft.copyWith(recipient: 'a@b.example', body: 'Text'),
    );
    await services.messages.handOver(draft.id);

    // Drei Nachfragen, wie sie beim Anzeigen der Karte gezählt werden – je
    // eine pro Woche, damit die Pause dazwischen nicht der Grund ist.
    for (var round = 0; round < HistoryEntry.maxFollowUps; round++) {
      expect(
        await services.messages.awaitingConfirmation(),
        hasLength(1),
        reason: 'Nachfrage ${round + 1} ist noch erlaubt',
      );
      await services.messages.registerAsked(draft);
      now = now.add(const Duration(days: 7));
    }

    // Danach ist Schluss. Kein Endlos-Gebettel, keine Schuld – der Vorgang
    // bleibt still als offene Aufgabe liegen.
    expect(await services.messages.awaitingConfirmation(), isEmpty);

    await pumpApp(tester);
    expect(find.byKey(Key('msg_followup_${draft.id}')), findsNothing);

    final entry = await services.history.entryById(draft.entryId);
    expect(entry!.isOpen, isTrue);
  });

  testWidgets('fragt beim nächsten Öffnen sanft nach, mit Ausweg', (
    tester,
  ) async {
    final draft = await services.messages.create(subject: 'Neue Karte');
    await services.messages.save(
      draft.copyWith(
        recipientType: 'Krankenkasse',
        recipient: 'service@aok.example',
        body: 'Text',
      ),
    );
    await services.messages.handOver(draft.id);

    await pumpApp(tester);

    expect(find.byKey(Key('msg_followup_${draft.id}')), findsOneWidget);
    expect(find.textContaining('hat das geklappt?'), findsOneWidget);
    // Immer mit Ausweg.
    expect(find.byKey(Key('msg_later_${draft.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('msg_no_${draft.id}')));
    await tester.pumpAndSettle();

    // Nein heißt: bleibt als offene Aufgabe liegen, ohne Druck.
    final entry = await services.history.entryById(draft.entryId);
    expect(entry!.status, HistoryStatus.open);
    expect(entry.isOpen, isTrue);
  });

  testWidgets('Ja schließt den Vorgang ab', (tester) async {
    final draft = await services.messages.create(subject: 'Neue Karte');
    await services.messages.save(
      draft.copyWith(recipient: 'a@b.example', body: 'Text'),
    );
    await services.messages.handOver(draft.id);

    await pumpApp(tester);
    await tester.tap(find.byKey(Key('msg_yes_${draft.id}')));
    await tester.pumpAndSettle();

    final entry = await services.history.entryById(draft.entryId);
    expect(entry!.status, HistoryStatus.done);
  });
}
