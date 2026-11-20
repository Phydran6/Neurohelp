import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/appointments/presentation/appointment_start_page.dart';
import 'package:neurohelp/features/calls/presentation/call_start_page.dart';
import 'package:neurohelp/features/help/presentation/help_page.dart';
import 'package:neurohelp/features/history/presentation/history_page.dart';
import 'package:neurohelp/features/home/presentation/main_menu_page.dart';
import 'package:neurohelp/features/home/presentation/start_page.dart';
import 'package:neurohelp/features/messages/presentation/message_start_page.dart';
import 'package:neurohelp/features/onboarding/presentation/onboarding_page.dart';
import 'package:neurohelp/features/settings/presentation/settings_page.dart';
import 'package:neurohelp/features/tasks/presentation/task_start_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Jede Seite bei großer Schrift.
///
/// Für diese App ist das kein Randfall: Wer die Systemschrift hochstellt, tut
/// das dauerhaft, und ein Teil der Zielgruppe tut es. Trotzdem waren die
/// Seiten nur bei einfacher Größe geprüft – „Termin klären" verlor bei
/// doppelter Schrift über 700 Pixel nach unten, das Onboarding 152. Was unten
/// aus dem Bild läuft, nimmt den großen Knopf mit; die Seite sieht dann heil
/// aus und ist es nicht.
///
/// Ein Überlauf lässt einen Widget-Test von selbst scheitern – mehr braucht
/// es hier nicht.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });
  late AppDatabase database;
  setUp(
    () async => database = await AppDatabase.open(path: inMemoryDatabasePath),
  );
  tearDown(() => database.close());

  final pages = <String, Widget>{
    'Start': const StartPage(),
    'Hauptmenue': const MainMenuPage(),
    'Aufgabe': const TaskStartPage(),
    'Anruf': const CallStartPage(),
    'Nachricht': const MessageStartPage(),
    'Termin': const AppointmentStartPage(),
    'Einstellungen': const SettingsPage(),
    'Hilfe': const HelpPage(),
    'Historie': const HistoryPage(),
  };

  for (final entry in pages.entries) {
    for (final scale in [1.3, 1.6, 2.0]) {
      testWidgets('${entry.key} bei Textgroesse $scale', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          AppScope(
            services: AppServices.from(database),
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: entry.value,
              ),
            ),
          ),
        );
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 32));
        }
      });
    }
  }

  for (final scale in [1.3, 1.6, 2.0]) {
    testWidgets('Onboarding bei Textgroesse $scale', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          services: AppServices.from(database),
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: OnboardingPage(onDone: () {}),
            ),
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
    });
  }
}
