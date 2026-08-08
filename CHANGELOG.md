# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Added

- **Historie-Rückgrat** (Konzept, Abschnitt 12): lokale SQLite-Datenbank mit
  versionierten Migrationen, Vorgängen und lückenlosem Ereignis-Protokoll
- Nachfrage-Logik mit harter Obergrenze von 3 Nachfragen je Vorgang – danach
  bleibt der Vorgang still liegen, keine Schuldmechanik
- Log-Schicht als Ersatz für `print`
- **Supabase-Backend**: Schema für Konten und Wiederherstellungs-Codes mit Row
  Level Security; bewusst ohne Tabellen für Nutzerinhalte (lokal-first)
- **KI-Proxy** als Supabase Edge Function, anbieteragnostisch (Claude und
  OpenAI); Prompts liegen im Backend und sind ohne App-Update änderbar
- `AiClient`-Schnittstelle in der App – kennt nur Aufgabentypen, keinen
  Anbieter; `DisabledAiClient` für den KI-losen Betrieb
- **Onboarding** (Konzept, Abschnitt 16): Ablaufsteuerung über die fünf
  Schritte. KI-Toggle und App-Sperre sind Pflichtentscheidungen und lassen
  sich nicht stillschweigend überspringen
- Lokal gespeicherte Einstellungen (Tonfall, KI-Toggle, Art der App-Sperre)
  in der SQLite-Datenbank, Schemaversion 2
- PIN-Ablage als gesalzener, vielfach gehashter Wert – die PIN selbst wird
  nie gespeichert; Vergleich läuft ohne frühen Abbruch
- Schnittstellen für App-Sperre (`AppLock`) und Konto (`AccountRepository`),
  beide ohne Plattform- und Backend-Bezug
- **Aufgabe sortieren** (Konzept, Abschnitt 11): beliebig tiefe Baumstruktur,
  jeder Punkt mit eigener Notiz; Schemaversion 3
- Fokus-Modus als Grundfunktion – die App liefert immer nur den nächsten
  offenen Schritt, der Berg bleibt unsichtbar
- Abhaken ist endgültig; Punkte mit Unterpunkten gelten als erledigt, sobald
  alle ihre Unterpunkte erledigt sind
- Jeder angelegte und abgehakte Schritt landet in der Historie; der Vorgang
  schließt sich selbst, sobald nichts mehr offen ist

### Fixed

- Formatprüfung in der CI: Die SDK-Untergrenze in `pubspec.yaml` bestimmt den
  Stil von `dart format`. Sie liegt jetzt bei 3.8, damit lokal und CI
  denselben Stil verwenden

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
