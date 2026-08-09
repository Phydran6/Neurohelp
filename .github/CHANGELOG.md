# Änderungen in .github/

Verbindlich fürs Release ist die [große CHANGELOG.md](../CHANGELOG.md).

## [Unreleased]

## [0.1.0-alpha.2] - 2026-08-09

- Release-Artefakte heißen jetzt sprechend, z.B.
  `Neurohelp-0.1.0-alpha.2-android.apk` statt `app-release.apk`
- `CONTRIBUTING.md` und `SECURITY.md` von der Wurzel hierher verschoben –
  GitHub findet sie hier genauso, die Startseite wird ruhiger
- `README.md` für diesen Bereich, mit einer Übersicht der Secrets

## [0.1.0-alpha.1] - 2026-08-09

- `release.yml` verpackt die iOS-App ohne Apple-Zugang als unsigniertes IPA,
  damit auch dort ein Artefakt im Release liegt
- Das Release wartet nicht mehr auf iOS; Android genügt
- `ci.yml` gibt Analysefehler als Annotation aus, damit sie ohne Zugriff auf
  die Logdateien lesbar sind
- `ensure_platforms.sh` läuft vor `flutter pub get`, sonst fehlt die
  Plugin-Registrierung
