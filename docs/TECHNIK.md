# Technische Dokumentation

Alles, was zum Bauen, Testen und Ausliefern nötig ist.
Für die Beschreibung der App selbst: [← zurück zur Startseite](../README.md).

---

## Inhalt

| Dokument | Worum es geht |
|---|---|
| [KONZEPT.md](KONZEPT.md) | **Das führende Dokument.** Bei Widersprüchen gewinnt es |
| [ARCHITEKTUR.md](ARCHITEKTUR.md) | Schichten, Datenfluss, Entscheidungen |
| [BACKEND.md](BACKEND.md) | Supabase: Schema, Migrationen, KI-Proxy |
| [RELEASE.md](RELEASE.md) | Branches, Versionen, Veröffentlichen |

---

## Stack

| Komponente | Technologie |
|---|---|
| App | Flutter (Dart) – Android + iOS aus einer Codebasis |
| Lokale Datenbank | SQLite über `sqflite`, eigene Migrationen |
| Backend | Supabase (Auth, Mailversand, KI-Proxy) |
| KI-Anbindung | Über das Backend, anbieteragnostisch (Claude, OpenAI) |
| Anrufbegleitung Android | Overlay-Berechtigung / Split-Screen *(offen)* |
| Anrufbegleitung iOS | Live Activity + Dynamic Island *(offen)* |
| Build & Auslieferung | GitHub Actions + fastlane |

**Lokal-first:** Nutzerdaten liegen auf dem Gerät. Über das Backend laufen nur
Kontoverwaltung, Reset-Mails und KI-Aufrufe. Neue Cloud-Speicherung ist
begründungspflichtig.

### Mindestversionen

| Plattform | Ab |
|---|---|
| iOS | 15.0 |
| Android | was Flutter vorgibt (`flutter.minSdkVersion`) |

Die iOS-Untergrenze steht an zwei Stellen und muss an beiden gleich sein:
`IPHONEOS_DEPLOYMENT_TARGET` in
[project.pbxproj](../ios/Runner.xcodeproj/project.pbxproj) und `platform :ios`
im [Podfile](../ios/Podfile). Weicht eine ab, baut Xcode trotzdem – und Apple
meldet sich erst nach dem Upload mit **ITMS-90068**. Genau das ist bei Build 7
passiert, damals mit 13.0.
[ios_deployment_target_test.dart](../test/unit/ios_deployment_target_test.dart)
hält beide zusammen.

---

## Schnellstart

```bash
git clone https://github.com/Phydran6/Neurohelp.git
```

```bash
flutter pub get
```

```bash
flutter run --dart-define=FLAVOR=dev
```

Voraussetzung ist das Flutter SDK (Kanal `stable`). `android/` und `ios/`
liegen im Repository; die Skripte unter [scripts/](../scripts/) werden nur
gebraucht, wenn die Plattform-Ordner neu entstehen müssen.

---

## Aufbau des Repositories

| Bereich | Inhalt |
|---|---|
| [lib/](../lib/) | Der gesamte Dart-Code der App |
| [test/](../test/) | Unit- und Widget-Tests |
| [integration_test/](../integration_test/) | End-to-End-Tests auf Gerät oder Emulator |
| [supabase/](../supabase/) | Schema, Migrationen, Edge Functions |
| [scripts/](../scripts/) | Bootstrap und Hilfsskripte |
| [tool/](../tool/) | Entwicklerwerkzeuge, z.B. die Icon-Aufbereitung |
| [docs/](.) | Diese Dokumentation |
| [.github/](../.github/UEBERSICHT.md) | Workflows, Vorlagen, Beitragsleitfaden |
| `android/`, `ios/` | Native Schalen, handgepflegt nur `fastlane/` und die Signatur |

Jeder Bereich hat eine eigene `README.md` und ein eigenes `CHANGELOG.md`.
Verbindlich fürs Release ist die große [CHANGELOG.md](../CHANGELOG.md).

### Innerhalb von `lib/`

```
lib/
├─ main.dart      Einstiegspunkt, Verdrahtung der Dienste
├─ app/           App-Wurzel, MaterialApp, Einstiegs-Weiche
├─ core/          Querschnitt: DB, Historie, Konto, KI, Sicherheit, Theme
├─ features/      Ein Ordner pro Feature, je data / domain / presentation
└─ shared/        Feature-übergreifende Widgets
```

Details in [ARCHITEKTUR.md](ARCHITEKTUR.md), Regeln in
[lib/README.md](../lib/README.md).

---

## Befehle

Vor jedem Commit alle drei, in dieser Reihenfolge:

```bash
dart format .
```

```bash
flutter analyze --fatal-infos --fatal-warnings
```

```bash
flutter test
```

Weitere:

```bash
flutter test --coverage
```

```bash
flutter test integration_test
```

---

## Build-Flavors

Konfiguration kommt über `--dart-define`, siehe
[app_config.dart](../lib/core/config/app_config.dart).

```bash
flutter run --dart-define=FLAVOR=dev
```

| Flavor | Zweck |
|---|---|
| `dev` | Lokale Entwicklung |
| `staging` | Interne Tests gegen ein Staging-Backend |
| `prod` | Release-Builds |

| Define | Vorgabe |
|---|---|
| `FLAVOR` | `dev` |
| `SUPABASE_URL` | das produktive Projekt |
| `SUPABASE_KEY` | der öffentliche `sb_publishable_…`-Schlüssel |
| `APP_VERSION` | `AppVersion.fallbackName` aus `pubspec.yaml` |
| `APP_BUILD_NUMBER` | `AppVersion.fallbackBuild` aus `pubspec.yaml` |

`APP_VERSION` und `APP_BUILD_NUMBER` setzt die CI beim Release. Sie landen im
Info-Bereich der App. Ohne sie greift die Konstante in
[app_version.dart](../lib/core/config/app_version.dart), die
[app_version_test.dart](../test/unit/app_version_test.dart) mit `pubspec.yaml`
zusammenhält – eine falsche Versionsnummer ist schlimmer als keine, weil sich
Fehlermeldungen aus der Alpha dann keinem Build zuordnen lassen.

Der öffentliche Schlüssel darf im Repository stehen – er steckt ohnehin in
jeder ausgelieferten App. Geschützt wird über Row Level Security. Der geheime
Schlüssel bleibt ausschließlich im Backend.

---

## App-Icon

Quelle ist `assets/icons/app_icon.png` (1024 × 1024). Daraus entstehen zwei
Zwischenstufen, weil beide Plattformen Unterschiedliches verlangen:

```bash
dart run tool/make_icons.dart
```

```bash
dart run flutter_launcher_icons
```

| Datei | Wofür |
|---|---|
| `app_icon_square.png` | randlos und deckend – iOS rundet selbst und verträgt keine Transparenz |
| `app_icon_foreground.png` | Motiv freigestellt und eingerückt – Vordergrund des adaptiven Android-Icons |

Die erzeugten Dateien liegen unter `android/` und `ios/` und sind eingecheckt.
Die CI braucht dadurch kein zusätzliches Werkzeug.

**Beim Austausch des Icons** beide Befehle nacheinander ausführen. Nur das
Original ersetzen – die zwei Zwischenstufen entstehen automatisch neu.

---

## Branches

| Branch | Zweck |
|---|---|
| `main` | Produktiv. Nur von hier wird getaggt und veröffentlicht |
| `develop` | Entwicklung und Tests |

Mehr braucht es nicht. Beide durchlaufen dieselbe CI.

---

## Auslieferung

| Workflow | Auslöser | Ergebnis |
|---|---|---|
| [`ci.yml`](../.github/workflows/ci.yml) | Push / PR auf `main` oder `develop` | Format, Analyse, Tests, Debug-Builds |
| [`release.yml`](../.github/workflows/release.yml) | Tag `v*.*.*` | APK, AAB, IPA + GitHub-Release |
| [`deploy.yml`](../.github/workflows/deploy.yml) | nach Release / manuell | Play Store (internal), TestFlight |

Ein Release auslösen:

```bash
git tag v0.1.0-alpha.2 && git push origin v0.1.0-alpha.2
```

Fehlende Store-Secrets führen nicht zum Abbruch: Die betroffenen Schritte
warnen und bauen unsigniert weiter. Einzelheiten in [RELEASE.md](RELEASE.md).

---

## Harte Regeln

Diese Punkte sind keine Stilfrage. Wer sie bricht, bricht das Versprechen der
App:

- **Kein Zwang** – keine Gamification, keine Streaks, keine Schuldmechanik
- **Kein direkter KI-Aufruf aus der App** – immer über das Backend
- **Lokal-first** – Nutzerdaten bleiben auf dem Gerät
- **Jedes Feature startet mit einem Historie-Check**, bevor der User tippt
- **Jeder KI-Pfad braucht einen Weg ohne KI**
- **Plattformen nicht zueinander zwingen** – Android und iOS dürfen sich
  bewusst unterscheiden
- **Bei Unsicherheit: verschieben, nicht reinpacken**
- Keine Secrets, Keystores oder API-Schlüssel im Repository

---

## Bau-Reihenfolge

Nach Abschnitt 19 des Konzepts:

| | Schritt | Stand |
|---|---|---|
| 1 | Projekt-Setup Flutter + GitHub Actions | ✅ |
| 2 | Supabase-Backend | ✅ |
| 3 | Lokale DB + Historie-Rückgrat | ✅ |
| 4 | Onboarding + Konto + Sicherheit | ✅ |
| 5 | Backend-Schicht: KI-Proxy | ✅ |
| 6 | Feature „Aufgabe sortieren" | ✅ |
| 7 | Feature „Nachricht schreiben" | ✅ |
| 8 | Feature „Anruf erledigen" | 🟡 bedienbar, native Begleitung offen |
| 9 | Feature „Termin klären" | ✅ |
| 10 | Info- & Hilfe-Bereich | ✅ |
| 11 | Apple Developer Account | 🟡 vorhanden, CI-Secrets fehlen |
| 12 | Alpha-Verteilung | ✅ als APK im Release |

---

## Mitwirken

[Beitragsleitfaden](../.github/CONTRIBUTING.md) ·
[Sicherheitsrichtlinie](../.github/SECURITY.md)

Nutzersichtbare Änderungen kommen unter `[Unreleased]` in die
[CHANGELOG.md](../CHANGELOG.md).

---

[← zurück zur Startseite](../README.md)
