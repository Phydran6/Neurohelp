import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/app/app.dart';
import 'package:neurohelp/core/ai/ai_client.dart';
import 'package:neurohelp/core/config/app_config.dart';
import 'package:neurohelp/features/home/domain/greetings.dart';
import 'package:neurohelp/features/home/presentation/main_menu_page.dart';

void main() {
  setUp(() {
    AppConfig.overrideForTesting(
      const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
    );
  });

  testWidgets('zeigt Logo, Spruch und genau einen großen Knopf', (
    tester,
  ) async {
    await tester.pumpWidget(const NeurohelpApp());

    expect(find.byKey(const Key('start_logo')), findsOneWidget);
    expect(find.byKey(const Key('start_greeting')), findsOneWidget);

    // Konzept, Abschnitt 6: ein einziger großer Button.
    expect(find.byKey(const Key('start_button')), findsOneWidget);

    // Kein leeres Eingabefeld, das den User anstarrt.
    expect(find.byType(EditableText), findsNothing);
  });

  testWidgets('der Spruch kommt aus dem Katalog', (tester) async {
    await tester.pumpWidget(const NeurohelpApp());

    final text = tester.widget<Text>(find.byKey(const Key('start_greeting')));
    expect(Greetings.lines, contains(text.data));
  });

  testWidgets('der Knopf führt ins Hauptmenü', (tester) async {
    await tester.pumpWidget(const NeurohelpApp());

    await tester.tap(find.byKey(const Key('start_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('menu_title')), findsOneWidget);
    for (final entry in MainMenuPage.entries) {
      expect(
        find.byKey(Key('menu_${entry.id}')),
        findsOneWidget,
        reason: entry.id,
      );
    }
  });
}
