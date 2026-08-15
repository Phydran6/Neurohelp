/// Version und Build-Nummer der laufenden App.
///
/// Anlass: Im Info-Bereich stand fest verdrahtet „0.1.0 (1)" – egal, was
/// tatsächlich installiert war. Eine falsche Versionsnummer ist schlimmer als
/// keine: Fehlermeldungen aus der Alpha lassen sich damit keinem Build
/// zuordnen.
///
/// Zwei Quellen, in dieser Reihenfolge:
///
///  1. `--dart-define=APP_VERSION=…` bzw. `APP_BUILD_NUMBER` – so baut die CI.
///     Dort steht die wirklich veröffentlichte Version, inklusive der
///     Lauf-Nummer als Build.
///  2. Die Konstanten hier – für lokale Läufe. `test/unit/app_version_test.dart`
///     hält sie mit `pubspec.yaml` zusammen, damit sie nicht davonlaufen.
abstract final class AppVersion {
  /// Muss zur `version:` in pubspec.yaml passen (Teil vor dem `+`).
  static const String fallbackName = '0.1.0-alpha.7';

  /// Muss zur `version:` in pubspec.yaml passen (Teil nach dem `+`).
  static const String fallbackBuild = '1';

  static const String _definedName = String.fromEnvironment('APP_VERSION');
  static const String _definedBuild = String.fromEnvironment(
    'APP_BUILD_NUMBER',
  );

  /// Bewusst `const` und kein Getter: So lässt sich der Wert als Standardwert
  /// eines `const`-Konstruktors benutzen.
  // Vergleich mit '' statt `.isEmpty`: Ein Eigenschaftszugriff ist in einem
  // konstanten Ausdruck nicht erlaubt, ein Gleichheitsvergleich schon.
  static const String name = _definedName == '' ? fallbackName : _definedName;

  static const String build = _definedBuild == ''
      ? fallbackBuild
      : _definedBuild;

  /// Wie es im Info-Bereich steht: `0.1.0-alpha.5 (12)`.
  static const String label = '$name ($build)';
}
