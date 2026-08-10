import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:neurohelp/core/config/app_version.dart';

/// Hält die angezeigte Version mit pubspec.yaml zusammen.
///
/// Anlass: Im Info-Bereich stand dauerhaft „0.1.0 (1)". Wer eine Alpha-Meldung
/// bekommt, kann sie damit keinem Build zuordnen – und merkt die Abweichung
/// nie, weil beides für sich plausibel aussieht.
void main() {
  test('die Ausweichversion passt zu pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml hat keine version:');

    final parts = match!.group(1)!.split('+');
    expect(
      AppVersion.fallbackName,
      parts.first,
      reason:
          'AppVersion.fallbackName muss der Version aus pubspec.yaml '
          'entsprechen, sonst zeigt der Info-Bereich etwas Falsches an.',
    );
    expect(
      AppVersion.fallbackBuild,
      parts.length > 1 ? parts[1] : '1',
      reason: 'AppVersion.fallbackBuild muss zur Build-Nummer passen.',
    );
  });
}
