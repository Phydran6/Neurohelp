import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/app/app.dart';
import 'package:neurohelp/core/config/app_config.dart';
import 'package:neurohelp/core/db/app_database.dart';
import 'package:neurohelp/core/di/app_services.dart';
import 'package:neurohelp/features/home/domain/greetings.dart';
import 'package:neurohelp/features/home/presentation/main_menu_page.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late AppDatabase database;
  late AppServices services;

  setUp(() async {
    AppConfig.overrideForTesting(
      const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
    );
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    services = AppServices.from(database);

    // Ohne abgeschlossenes Onboarding landet die App dort statt auf der
    // Startseite. Ohne eingerichtete Sperre gibt es nichts zu entsperren.
    await services.settings.setOnboardingCompleted(completed: true);
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
      AppScope(services: services, child: const NeurohelpApp()),
    );
    await pumpUntil(tester, find.byKey(const Key('start_logo')));
  }

  testWidgets('zeigt Logo, Spruch und genau einen großen Knopf', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const Key('start_greeting')), findsOneWidget);

    // Konzept, Abschnitt 6: ein einziger großer Button.
    expect(find.byKey(const Key('start_button')), findsOneWidget);

    // Kein leeres Eingabefeld, das den User anstarrt.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('der Spruch kommt aus dem Katalog', (tester) async {
    await pumpApp(tester);

    final text = tester.widget<Text>(find.byKey(const Key('start_greeting')));
    expect(Greetings.lines, contains(text.data));
  });

  testWidgets('der Knopf führt ins Hauptmenü', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const Key('start_button')));
    await pumpUntil(tester, find.byKey(const Key('menu_title')));

    for (final entry in MainMenuPage.entries) {
      expect(
        find.byKey(Key('menu_${entry.id}')),
        findsOneWidget,
        reason: entry.id,
      );
    }
  });
}
