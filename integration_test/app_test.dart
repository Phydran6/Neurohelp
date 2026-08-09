import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:neurohelp/app/app.dart';
import 'package:neurohelp/core/config/app_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App startet und zeigt die Startseite', (tester) async {
    AppConfig.initFromEnvironment();

    await tester.pumpWidget(const NeurohelpApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('start_button')), findsOneWidget);
  });
}
