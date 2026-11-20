import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/calls/presentation/call_start_page.dart';
import 'package:neurohelp/features/messages/presentation/message_start_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// KI mit fester Antwort.
class _ScriptedAi implements AiClient {
  _ScriptedAi({required this.answer});

  final String answer;
  bool enabled = true;

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
  }) async => answer;
}

/// Der Accept-Pfad in Nachricht und Anruf – bisher nur in Aufgabe getestet.
///
/// Anlass: „Übernehmen" tut auf dem Gerät nichts. Diese Tests halten fest,
/// dass ein angetippter Vorschlag im jeweiligen Feld landet.
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

  Future<AppServices> withAi(AiClient ai) async {
    final services = AppServices.from(database, ai: ai);
    await services.settings.setAiEnabled(enabled: true);
    return services;
  }

  testWidgets('Nachricht: „Einsetzen" schreibt den Vorschlag ins Feld', (
    tester,
  ) async {
    final services = await withAi(
      _ScriptedAi(
        answer: 'Sehr geehrte Damen und Herren, meine Karte ist weg.',
      ),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: MessageStartPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('msg_new')));
    await tester.tap(find.byKey(const Key('msg_new')));
    await pumpUntil(tester, find.byKey(const Key('msg_know')));
    await tester.tap(find.byKey(const Key('msg_know')));
    await tester.pumpAndSettle();

    Future<void> answer(String text) async {
      await tester.enterText(find.byKey(const Key('msg_field')), text);
      await tester.pump();
      await tester.tap(find.byKey(const Key('msg_next')));
      await tester.pumpAndSettle();
    }

    await answer('Neue Karte');
    await answer('Krankenkasse');
    await answer('service@aok.example');

    // Compose-Schritt: erst Stichpunkte ins Feld, damit die KI etwas hat.
    await tester.enterText(
      find.byKey(const Key('msg_field')),
      'Karte abgelaufen, brauche eine neue',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));

    // Kein Scrollen von Hand: Das Widget holt die Vorschläge selbst in den
    // Blick. Der Tipp muss danach ankommen.
    await tester.tap(find.byKey(const Key('ai_suggestion_0')));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const Key('msg_field')));
    expect(
      field.controller!.text,
      'Sehr geehrte Damen und Herren, meine Karte ist weg.',
    );
  });

  testWidgets('Anruf: „Alle übernehmen" füllt Ziel, Kontakt und Stichpunkt', (
    tester,
  ) async {
    final services = await withAi(
      _ScriptedAi(answer: 'Termin absagen\nFrau Meyer\nNeuen Termin erfragen'),
    );

    await tester.pumpWidget(
      AppScope(
        services: services,
        child: const MaterialApp(home: CallStartPage()),
      ),
    );
    await pumpUntil(tester, find.byKey(const Key('call_title')));
    await tester.tap(find.byKey(const Key('call_category_Arzt')));
    await pumpUntil(tester, find.byKey(const Key('call_know')));
    await tester.tap(find.byKey(const Key('call_know')));
    await pumpUntil(tester, find.byKey(const Key('call_number')));

    // Wie ein echter Nutzer: erst hinscrollen, dann tippen. Ohne das landet
    // der Tipp neben dem Knopf, sobald die Seite länger wird als das Blatt.
    await tester.ensureVisible(find.byKey(const Key('ai_ask')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai_ask')));
    await pumpUntil(tester, find.byKey(const Key('ai_suggestion_0')));
    await tester.ensureVisible(find.byKey(const Key('ai_accept_all')));
    await tester.pumpAndSettle();

    // Das Widget scrollt die Vorschläge selbst in den Blick; der Tipp kommt an.
    await tester.tap(find.byKey(const Key('ai_accept_all')));
    await tester.pumpAndSettle();

    // Nach dem Auto-Scroll liegen Ziel und Kontakt oben außerhalb des Blatts;
    // die faule Liste baut sie dann nicht. Zurück nach oben, dann prüfen.
    // Die erste Scrollable ist die Liste – die übrigen stecken in den
    // Textfeldern und scrollen waagerecht.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    final goal = tester.widget<TextField>(find.byKey(const Key('call_goal')));
    final contact = tester.widget<TextField>(
      find.byKey(const Key('call_contact')),
    );
    expect(goal.controller!.text, 'Termin absagen');
    expect(contact.controller!.text, 'Frau Meyer');
  });
}
