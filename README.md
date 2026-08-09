# Neurohelp

Eine App, die neurodivergenten Menschen im Alltag hilft – als hilfsbereiter Freund, ruhiger
Assistent und Werkzeugkasten in einem.

**Kernprinzip:** Hilfe zur Selbsthilfe. Nur wenn es wirklich nicht geht, übernimmt die App.

[![CI](https://github.com/Phydran6/Neurohelp/actions/workflows/ci.yml/badge.svg)](https://github.com/Phydran6/Neurohelp/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> Vollständiges Konzept: [docs/KONZEPT.md](docs/KONZEPT.md) – das ist das führende Dokument.

---

## Stack

| Komponente | Technologie |
|---|---|
| App | Flutter (Dart) – Android + iOS aus einer Codebasis |
| Lokale DB | SQLite (Drift / sqflite) |
| Backend | Supabase (Auth, Mailversand, KI-Proxy) |
| KI-Anbindung | Über Backend, anbieteragnostisch (Claude, OpenAI, weitere) |
| Anrufbegleitung Android | Overlay-Berechtigung / Split-Screen |
| Anrufbegleitung iOS | Live Activity + Dynamic Island (ActivityKit) |
| Build & Deployment | GitHub Actions + fastlane |

**Datenhaltung ist lokal-first:** Nutzerdaten liegen auf dem Gerät. Über das Backend laufen nur
KI-Verarbeitung, Reset-Mails und Kontoverwaltung.

---

## Schnellstart

```bash
git clone https://github.com/Phydran6/Neurohelp.git
cd Neurohelp
```

```bash
flutter pub get
```

> Voraussetzung: Flutter SDK (stable). `android/` und `ios/` liegen im
> Repository – die Bootstrap-Skripte unter `scripts/` werden nur gebraucht,
> wenn die Plattform-Ordner neu erzeugt werden müssen.

App starten:

```bash
flutter run --dart-define=FLAVOR=dev
```

---

## Projektstruktur

```
lib/
├─ main.dart                 Einstiegspunkt
├─ app/                      App-Wurzel, MaterialApp, globales Setup
├─ core/                     Querschnitt: Config, Theme, Routing, DB, Services
│  ├─ account/               Konto (Supabase Auth dahinter)
│  ├─ ai/                    KI-Schnittstelle (kennt keinen Anbieter)
│  ├─ config/                Build-Flavors und --dart-define-Werte
│  ├─ db/                    SQLite: Schema, Migrationen, Zugang
│  ├─ history/               Historie – das Rückgrat der App
│  ├─ logging/               Log-Schicht (`print` ist verboten)
│  ├─ router/                Navigation
│  ├─ security/              App-Sperre, PIN-Ablage
│  ├─ settings/              Tonfall, KI-Toggle, Art der Sperre
│  └─ theme/                 Farben, Typografie, Themes
├─ features/                 Ein Ordner pro Feature (Abschnitt 7 des Konzepts)
│  └─ <feature>/
│     ├─ data/               Repositories, lokale/entfernte Datenquellen
│     ├─ domain/             Modelle, Geschäftslogik
│     └─ presentation/       Screens, Widgets, State
└─ shared/                   Feature-übergreifend wiederverwendbare Widgets

test/          Unit- und Widget-Tests
integration_test/  End-to-End-Tests auf Gerät/Emulator
android/       Native Android-Schale + fastlane
ios/           Native iOS-Schale + fastlane
supabase/      Schema, Migrationen, Edge Functions (KI-Proxy)
docs/          Konzept, Architektur, Supabase, Release-Prozess
scripts/       Bootstrap und Hilfsskripte
```

---

## Entwicklungsbefehle

```bash
flutter pub get
```

```bash
dart format .
```

```bash
flutter analyze --fatal-infos --fatal-warnings
```

```bash
flutter test --coverage
```

```bash
flutter test integration_test
```

---

## Build-Flavors

Konfiguration kommt über `--dart-define`, siehe [lib/core/config/app_config.dart](lib/core/config/app_config.dart).

```bash
flutter run --dart-define=FLAVOR=dev --dart-define=API_BASE_URL=https://dev.example
```

| Flavor | Zweck |
|---|---|
| `dev` | lokale Entwicklung, Debug-Banner an |
| `staging` | interne Tests gegen Staging-Backend |
| `prod` | Release-Builds |

---

## Deployment

Vollständig automatisiert über GitHub Actions – Details in [docs/RELEASING.md](docs/RELEASING.md).

| Workflow | Auslöser | Ergebnis |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | Push / PR | Format, Analyse, Tests, Debug-Builds |
| [`release.yml`](.github/workflows/release.yml) | Tag `v*.*.*` | Signiertes AAB/APK + IPA, GitHub-Release |
| [`deploy.yml`](.github/workflows/deploy.yml) | nach Release / manuell | Play Store (internal), TestFlight |

Ein Release auslösen:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

---

## Bau-Reihenfolge

Nach Abschnitt 19 des Konzepts:

1. ✅ Projekt-Setup Flutter + GitHub Actions
2. 🟡 Supabase (Schema + Migrationen fertig, Projekt anlegen steht aus → [docs/SUPABASE.md](docs/SUPABASE.md))
3. ✅ Lokale DB + Historie-Rückgrat
4. 🟡 Onboarding + Konto + Sicherheit (Logik fertig, Plattform-Anbindung offen)
5. ✅ Backend-Schicht: KI-Proxy, anbieteragnostisch
6. 🟡 Feature „Aufgabe sortieren" (Logik fertig, Oberfläche offen)
7. 🟡 Feature „Nachricht schreiben" (Logik fertig, Oberfläche offen)
8. 🟡 Feature „Anruf erledigen" + Anrufbegleitung (Logik fertig, Oberfläche
   und native Begleitung offen)
9. 🟡 Feature „Termin klären" (Logik fertig, Oberfläche offen)
10. 🟡 Info- & Hilfe-Bereich (Logik fertig, Oberfläche offen)
11. ⬜ Apple Developer Account
12. ⬜ Alpha-Verteilung als APK

---

## Mitwirken

Siehe [CONTRIBUTING.md](CONTRIBUTING.md). Änderungen kommen unter `[Unreleased]` in die
[CHANGELOG.md](CHANGELOG.md).

## Lizenz

[MIT](LICENSE) © 2026 Philipp Fischer
