# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

## [0.1.0] - 2026-08-08

Phase 1 der Bau-Reihenfolge: Projekt-Setup Flutter + GitHub Actions
(siehe [docs/KONZEPT.md](docs/KONZEPT.md), Abschnitt 19, Punkt 1).

### Added

- Flutter-Projektgerüst für Android und iOS aus einer Codebasis
- Schichtstruktur `app` / `core` / `features` / `shared` mit Startseite als Platzhalter
- Build-Flavors `dev` / `staging` / `prod` über `--dart-define`
- Zentrale Theme-Definition (Material 3, Hell- und Dunkelmodus)
- CI-Pipeline: Formatprüfung, statische Analyse, Unit- und Widget-Tests, Debug-Builds
  für Android und iOS
- Release-Pipeline: signiertes AAB/APK und IPA per Tag `v*.*.*`, GitHub-Release mit
  automatisch aus diesem Changelog extrahierten Notizen
- Deploy-Pipeline: Google Play (Track `internal`) und TestFlight über fastlane
- Bootstrap-Skripte für Windows und macOS/Linux
- Projektdokumentation: Konzept, Architektur, Release-Prozess, Beitragsleitfaden,
  Sicherheitsrichtlinie
- Issue- und Pull-Request-Vorlagen, Dependabot für pub, GitHub Actions und Gradle
- MIT-Lizenz

[Unreleased]: https://github.com/Phydran6/Neurohelp/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0
