import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/tasks/presentation/task_steps_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// KI mit fester Antwort.
class _ScriptedAi implements AiClient {
  _ScriptedAi({required this.answer});

  final String answer;

  /// Der Schalter aus den Einstellungen zieht das nach.
  bool enabled = true;

  AiTask? lastTask;
  String? lastInput;
  AiTone? lastTone;

  @override
  bool get isEnabled => enabled;

  @override
  void setEnabled({required bool enabled}) => this.enabled = enabled;

  @override
  Future<void> probe() async {}

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async {
    lastTask = task;
    lastInput = input;
    lastTone = tone;
    return answer;
  }
}

/// KI, die gerade nicht erreichbar ist.
class _BrokenAi implements AiClient {
  @override
  bool get isEnabled => true;

  @override
  void setEnabled({required bool enabled}) {}

  @override
  Future<void> probe() async => throw const AiUnavailableException('kein Netz');

  @override
  Future<String> run(
    AiTask task, {
    required String input,
    AiTone tone = AiTone.locker,
  }) async => throw const AiUnavailableException('Die KI ist gerade weg.');
}

/// Der Moment der KI-Hilfe innerhalb eines Ablaufs.
///
/// Anlass: Der KI-Schalter ließ sich umlegen, aber in der App passierte
/// danach nichts – es gab schlicht keine Stelle, an der die KI etwas tat.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
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

  /// Dienste mit eingeschalteter KI.
  ///
  /// Der Schalter muss auch in den Einstellungen stehen: Der KI-Client zieht
  /// ihn bei jeder Änderung nach – genau deshalb wirkt er zur Laufzeit.
  Future<AppServices> withAi(AiClient ai) async {
    final services = AppServices.from(database, ai: ai);
    await services.settings.setAiEnabled(enabled: true);
    return services;
  }

  Future<void> pumpSteps(WidgetTester tester, AppServices services) async {
    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: TaskStepsPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('task_title_field')));
  }

  testWidgets('ohne KI gibt es den Block gar nicht', (tester) async {
    final services = AppServices.from(database);
    await pumpSteps(tester, services);

    // Jeder Ablauf muss ohne KI vollständig funktionieren.
    expect(find.byKey(const Key('ai_box')), findsNothing);
  });

  testWidgets('mit KI landen die Vorschläge in der Auswahlliste', (
    tester,
  ) async {
    final ai = _ScriptedAi(
      answer: '1. Kartons besorgen\n2. Kündigung schreiben',
    );
    final services = await withAi(ai);
    await pumpSteps(tester, services);

    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Umzug organisieren',
    );
    await tester.pump();

    expect(find.byKey(const Key('ai_box')), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

    expect(ai.lastTask, AiTask.splitTask);
    expect(ai.lastInput, 'Umzug organisieren');
    expect(find.text('Kartons besorgen'), findsOneWidget);

    // Übernommen wird nur, was der User antippt.
    expect(find.byKey(const Key('task_step_0')), findsNothing);
    await tester.tap(find.byKey(const Key('ai_accept_all')));
    await pumpUntil(tester, find.byKey(const Key('task_step_1')));
  });

  testWidgets('ein einzelner Vorschlag lässt sich übernehmen', (tester) async {
    final services = await withAi(
      _ScriptedAi(answer: '- Kartons besorgen\n- Kündigung schreiben'),
    );
    await pumpSteps(tester, services);

    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Umzug organisieren',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_suggestion_1')));

    await tester.tap(find.byKey(const Key('ai_suggestion_1')));
    await pumpUntil(tester, find.byKey(const Key('task_step_0')));

    expect(find.byKey(const Key('task_step_1')), findsNothing);
  });

  testWidgets('ohne Titel fragt die KI erst gar nicht', (tester) async {
    final ai = _ScriptedAi(answer: 'egal');
    final services = await withAi(ai);
    await pumpSteps(tester, services);

    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_error')));

    expect(ai.lastTask, isNull);
  });

  testWidgets('eine unerreichbare KI stoppt den Ablauf nicht', (tester) async {
    final services = await withAi(_BrokenAi());
    await pumpSteps(tester, services);

    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Umzug organisieren',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_error')));

    // Kein Fehler des Users – und der Weg ohne KI steht weiter offen.
    expect(find.text('Die KI ist gerade weg.'), findsOneWidget);
    expect(find.byKey(const Key('task_step_field')), findsOneWidget);
  });

  testWidgets('der gewählte Ton geht an die KI mit', (tester) async {
    final ai = _ScriptedAi(answer: 'Kartons besorgen');
    final services = await withAi(ai);
    await services.settings.setTone(AiTone.sachlich);

    await pumpSteps(tester, services);
    await tester.enterText(
      find.byKey(const Key('task_title_field')),
      'Umzug organisieren',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

    expect(ai.lastTone, AiTone.sachlich);
  });
}
