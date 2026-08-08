import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/app/app.dart';
import 'package:neurohelp/core/config/app_config.dart';

void main() {
  setUp(() {
    AppConfig.overrideForTesting(
      const AppConfig(flavor: Flavor.dev, apiBaseUrl: ''),
    );
  });

  testWidgets('zeigt Titel und aktuellen Flavor', (tester) async {
    await tester.pumpWidget(const NeurohelpApp());

    expect(find.text('Neurohelp'), findsAtLeastNWidgets(1));
    expect(find.byKey(const Key('home_flavor_label')), findsOneWidget);
    expect(find.text('Flavor: dev'), findsOneWidget);
  });
}
