import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Gilt für **jeden** Widget-Test (`flutter test` lädt diese Datei von selbst).
///
/// Anlass: Der Gerätetest meldete reihenweise „da passiert nichts, wenn ich
/// drauftippe". In den Tests war davon nichts zu sehen – ein Tipp, der
/// danebengeht, weil der Knopf unter dem Blattrand liegt, hat bis dahin nur
/// eine Warnung gedruckt und den Test trotzdem grün gelassen. Genau der Fall,
/// den der Tester auf dem Telefon erlebt.
///
/// Ab hier ist ein Tipp ins Leere ein Fehler. Wer einen Knopf antippen will,
/// der weiter unten liegt, scrollt ihn vorher hin – wie ein echter Nutzer
/// auch.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  WidgetController.hitTestWarningShouldBeFatal = true;
  await testMain();
}
