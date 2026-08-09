# Mitwirken

## Leitplanken

Vor jeder Änderung: [docs/KONZEPT.md](../docs/KONZEPT.md), Abschnitt 4 (Designprinzipien) und
Abschnitt 23 (Projektgrundsätze). Die wichtigsten in Kurzform:

- Minimalistisch, reizarm, selbsterklärend
- **Kein Zwang** – keine Druck-Mechaniken, kein schlechtes Gewissen, keine Gamification
- Auswahl vor Eingabe
- Erst die App denken lassen, dann den User
- Alles wird geloggt (Historie ist das Rückgrat)
- Bei Unsicherheit: verschieben, nicht reinpacken

## Branches

| Branch | Zweck |
|---|---|
| `main` | immer releasefähig |
| `develop` | Integrationszweig |
| `feat/<name>` | neues Feature |
| `fix/<name>` | Fehlerbehebung |
| `chore/<name>` | Aufräumen, Abhängigkeiten, Werkzeuge |

## Commits

[Conventional Commits](https://www.conventionalcommits.org/de/):

```
feat(tasks): Mikroschritte lassen sich abhaken
fix(call): Overlay bleibt nach Anruf sichtbar
docs(readme): Deployment-Abschnitt ergänzt
chore(deps): flutter_lints auf 5.0.0
```

Typen: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.

## Vor dem Push

```bash
dart format . && flutter analyze --fatal-infos --fatal-warnings && flutter test
```

Genau das prüft auch die CI – lokal grün heißt CI grün.

## Changelog

Jede nutzersichtbare Änderung kommt unter `## [Unreleased]` in die [CHANGELOG.md](../CHANGELOG.md),
Format nach [Keep a Changelog](https://keepachangelog.com/de/1.1.0/):
`Added`, `Changed`, `Deprecated`, `Removed`, `Fixed`, `Security`.

## Code-Konventionen

- `flutter_lints` + die Zusatzregeln aus [analysis_options.yaml](../analysis_options.yaml) sind bindend
- Ein Ordner pro Feature unter `lib/features/`, getrennt in `data` / `domain` / `presentation`
- Querschnittliches (Theme, Config, DB, Services) nach `lib/core/`
- Keine `print`-Aufrufe – Logging läuft über die Log-Schicht
- Keine direkten Aufrufe an KI-Anbieter aus der App. **Immer** über die Backend-Schicht
  (Konzept, Abschnitt 17)

## Tests

| Art | Ort | Wofür |
|---|---|---|
| Unit | `test/unit/` | Logik, Modelle, Repositories |
| Widget | `test/widget/` | einzelne Screens und Widgets |
| Integration | `integration_test/` | Flows auf Gerät/Emulator |

## Niemals einchecken

Keystores, `key.properties`, `.env`, Service-Account-JSONs, `.p8`/`.p12`, Provisioning Profiles,
API-Schlüssel. Alles davon läuft über GitHub-Secrets – siehe [docs/RELEASE.md](../docs/RELEASE.md).
