import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/backup/backup_codec.dart';
import 'package:neurohelp/core/backup/backup_vault.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/core/files/file_opener.dart';
import 'package:neurohelp/core/history/domain/history_entry.dart';
import 'package:neurohelp/features/backup/presentation/restore_gate_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Prüft den allerersten Bildschirm nach einer Neuinstallation
/// (Konzept, Abschnitt 14a).
///
/// Zwei Wege, wie überall in dieser App: selbst eine Datei heraussuchen,
/// oder die App am Standardplatz nachsehen lassen. Der wichtigste Fall ist
/// der dritte – **es ist nichts da**. Dann muss die App das ruhig sagen und
/// einen Kontaktweg anbieten, statt den User mit einer leeren Seite
/// stehenzulassen.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    // Siehe CLAUDE.md: In Widget-Tests kommt ein Future über eine
    // Isolate-Grenze nie an.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;
  late InMemoryBackupVault vault;
  late FixedFileOpener opener;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    vault = InMemoryBackupVault();
    opener = FixedFileOpener();
    services = AppServices.from(database, vault: vault, fileOpener: opener);
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

  Future<void> pumpGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: RestoreGatePage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('restore_question')));
  }

  /// Legt einen Vorgang an und macht daraus eine Sicherung.
  Future<Uint8List> seedAndBackUp(String title) async {
    await services.history.startEntry(
      feature: HistoryFeature.task,
      title: title,
    );
    await services.settings.setTone(AiTone.sachlich);

    final bytes = BackupCodec.encode(await services.backup.create());
    await services.wipeLocalData();
    return bytes;
  }

  testWidgets('fragt zuerst, ob es überhaupt etwas zurückzuholen gibt', (
    tester,
  ) async {
    await pumpGate(tester);

    expect(find.byKey(const Key('restore_guided')), findsOneWidget);
    expect(find.byKey(const Key('restore_expert')), findsOneWidget);
    expect(find.byKey(const Key('restore_skip')), findsOneWidget);
  });

  testWidgets('„Nein, ich fange neu an" fragt danach nie wieder', (
    tester,
  ) async {
    await pumpGate(tester);

    await tester.tap(find.byKey(const Key('restore_skip')));
    await tester.pumpAndSettle();

    expect((await services.settings.load()).restoreOffered, isTrue);
  });

  testWidgets('der geführte Weg findet die Sicherung am Standardplatz', (
    tester,
  ) async {
    final bytes = await seedAndBackUp('Zahnarzt anrufen');
    await vault.write(bytes);

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('restore_guided')));
    await pumpUntil(tester, find.byKey(const Key('restore_found')));

    await tester.tap(find.byKey(const Key('restore_apply')));
    await pumpUntil(tester, find.byKey(const Key('restore_done')));

    final entries = await services.history.recentEntries();
    expect(entries.single.title, 'Zahnarzt anrufen');
    // Die Einstellungen kommen mit – darum ist dieser Bildschirm vor dem
    // Onboarding und nicht danach.
    expect(services.settings.current.tone, AiTone.sachlich);
  });

  testWidgets('und sagt ruhig Bescheid, wenn dort nichts liegt', (
    tester,
  ) async {
    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('restore_guided')));
    await pumpUntil(tester, find.byKey(const Key('restore_empty')));

    // Kein Schuldton, und vor allem: nicht einfach eine leere Seite. Es
    // steht da, was jetzt noch geht.
    expect(find.byKey(const Key('restore_switch_expert')), findsOneWidget);
    expect(find.byKey(const Key('restore_start_fresh')), findsOneWidget);
    expect(find.byKey(const Key('support_contact')), findsOneWidget);
  });

  testWidgets('der Expertenweg spielt eine selbst gewählte Datei ein', (
    tester,
  ) async {
    final bytes = await seedAndBackUp('Umzug organisieren');
    opener.file = PickedFile(
      name: 'neurohelp-sicherung.nhbackup',
      bytes: bytes,
    );

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('restore_expert')));
    await pumpUntil(tester, find.byKey(const Key('restore_pick_file')));

    await tester.tap(find.byKey(const Key('restore_pick_file')));
    await pumpUntil(tester, find.byKey(const Key('restore_done')));

    expect(opener.calls, 1);
    final entries = await services.history.recentEntries();
    expect(entries.single.title, 'Umzug organisieren');
  });

  testWidgets('eine fremde Datei wird abgelehnt, ohne etwas kaputtzumachen', (
    tester,
  ) async {
    await services.history.startEntry(
      feature: HistoryFeature.task,
      title: 'Was Bestehendes',
    );
    opener.file = PickedFile(
      name: 'urlaubsfoto.jpg',
      bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
    );

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('restore_expert')));
    await pumpUntil(tester, find.byKey(const Key('restore_pick_file')));

    await tester.tap(find.byKey(const Key('restore_pick_file')));
    await pumpUntil(tester, find.byKey(const Key('backup_outcome')));

    expect(
      find.textContaining('keine Sicherung von Neurohelp'),
      findsOneWidget,
    );
    // Nichts angefasst: Was da war, ist noch da.
    expect(await services.history.recentEntries(), hasLength(1));
  });

  testWidgets('ein Abbruch in der Dateiauswahl ist keine Fehlermeldung', (
    tester,
  ) async {
    opener.file = null;

    await pumpGate(tester);
    await tester.tap(find.byKey(const Key('restore_expert')));
    await pumpUntil(tester, find.byKey(const Key('restore_pick_file')));

    await tester.tap(find.byKey(const Key('restore_pick_file')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('backup_outcome')), findsNothing);
  });
}
