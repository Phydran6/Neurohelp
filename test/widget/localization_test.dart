import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/app/app.dart';

void main() {
  /// Baut eine App mit derselben Spracheinstellung wie Neurohelp und gibt
  /// den Kontext heraus, in dem die Wähler laufen.
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    late BuildContext captured;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: const [appLocale],
        locale: appLocale,
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    return captured;
  }

  group('Sprache', () {
    testWidgets('die Woche beginnt am Montag', (tester) async {
      final context = await pumpApp(tester);

      // 1 ist Montag. Ohne Sprachpaket stand hier die 0 – der Sonntag, und
      // damit eine Spalte Versatz im ganzen Kalenderblatt.
      expect(MaterialLocalizations.of(context).firstDayOfWeekIndex, 1);
    });

    testWidgets('die Wähler sprechen Deutsch', (tester) async {
      final context = await pumpApp(tester);
      final texte = MaterialLocalizations.of(context);

      expect(texte.cancelButtonLabel, 'Abbrechen');
      expect(texte.datePickerHelpText, isNot('SELECT DATE'));
    });
  });
}
