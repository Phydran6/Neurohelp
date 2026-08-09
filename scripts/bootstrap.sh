#!/usr/bin/env bash
# Bootstrap für macOS / Linux. Siehe scripts/bootstrap.ps1 für Windows.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Flutter prüfen"
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter nicht gefunden. Installation: https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi
flutter --version

echo "==> Plattform-Ordner erzeugen (android, ios)"
# Achtung: Das ergibt die ID `will.neurohelp.neurohelp`. Die echte ID lautet
# `will.neurohelp.help` und ist bei Apple und Google so registriert – sie muss
# danach in android/app/build.gradle.kts, MainActivity.kt und
# ios/Runner.xcodeproj/project.pbxproj nachgezogen werden. `flutter create`
# kann sie nicht direkt erzeugen, weil das Dart-Paket `neurohelp` heisst.
flutter create \
  --project-name neurohelp \
  --org will.neurohelp \
  --platforms android,ios \
  --overwrite \
  .

echo "==> Kuratierte Projektdateien wiederherstellen"
for path in lib test integration_test pubspec.yaml analysis_options.yaml README.md .gitignore; do
  [ -e "$path" ] && git checkout -- "$path" 2>/dev/null || true
done

echo "==> Abhängigkeiten holen"
flutter pub get

echo "==> Formatieren"
dart format .

echo "==> Analyse & Tests"
flutter analyze
flutter test

echo
echo "Fertig. Nächste Schritte (Details: docs/RELEASING.md):"
echo "  - android/ und ios/ committen (ab jetzt Teil des Repos)"
echo "  - android/app/build.gradle.kts um die Release-Signatur ergänzen"
echo "  - GitHub-Secrets für Play Store / TestFlight hinterlegen"
