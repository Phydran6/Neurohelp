import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hält die iOS-Mindestversion an allen Stellen zusammen.
///
/// Anlass: Apple hat den Upload von Build 7 mit ITMS-90068 beanstandet – die
/// App meldete MinimumOSVersion 13.0, ab Frühjahr 2027 sind mindestens 15.0
/// Pflicht. Der Wert steht im Xcode-Projekt und im Podfile; weicht einer der
/// beiden ab, baut alles durch und Apple meldet sich erst nach dem Upload.
void main() {
  /// Untergrenze laut Apple (ITMS-90068), gültig ab Frühjahr 2027.
  const required = 15.0;

  group('iOS-Mindestversion', () {
    test('das Xcode-Projekt zielt auf mindestens $required', () {
      final content = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      final targets = RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);')
          .allMatches(content)
          .map((match) => double.parse(match.group(1)!))
          .toList();

      expect(
        targets,
        isNotEmpty,
        reason: 'Ohne IPHONEOS_DEPLOYMENT_TARGET entscheidet Xcode selbst.',
      );
      for (final target in targets) {
        expect(
          target,
          greaterThanOrEqualTo(required),
          reason:
              'Apple lehnt Uploads unter $required ab (ITMS-90068). '
              'Gefunden: $target.',
        );
      }
    });

    test('das Podfile zielt auf dieselbe Version', () {
      final content = File('ios/Podfile').readAsStringSync();

      final match = RegExp(r"platform :ios, '([0-9.]+)'").firstMatch(content);

      expect(
        match,
        isNotNull,
        reason:
            'Ohne platform-Zeile nehmen die Pods ihr eigenes, niedrigeres '
            'Ziel – das zieht die MinimumOSVersion wieder nach unten.',
      );
      expect(double.parse(match!.group(1)!), greaterThanOrEqualTo(required));
    });
  });
}
