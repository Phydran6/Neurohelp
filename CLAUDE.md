# Neurohelp – Arbeitsanweisungen

## Kontext

Flutter-App (Android + iOS) für neurodivergente Menschen. Das führende Dokument ist
[docs/KONZEPT.md](docs/KONZEPT.md) – bei Widersprüchen gewinnt das Konzept.

Gebaut wird strikt nach der **Bau-Reihenfolge in Abschnitt 19** des Konzepts. Ein Feature
richtig gut, bevor das nächste kommt.

## Harte Regeln

- **Kein Zwang:** keine Gamification, keine Streaks, keine Schuldmechanik, kein Druck
- **Kein direkter KI-Aufruf aus der App.** Immer über die Backend-Schicht (Supabase)
- **Lokal-first:** Nutzerdaten bleiben auf dem Gerät. Neue Cloud-Speicherung ist begründungspflichtig
- **Jedes Feature startet mit einem Historie-Check**, bevor der User etwas eingeben muss
- **Jeder KI-Pfad braucht einen Weg ohne KI** (KI-Toggle im Onboarding)
- **Plattformen nicht zueinander zwingen:** Android Overlay, iOS Live Activity – bewusst verschieden
- **Bei Unsicherheit: verschieben, nicht reinpacken**
- Keine Secrets, Keystores oder API-Schlüssel ins Repository

## Vor jedem Commit

```bash
dart format . && flutter analyze --fatal-infos --fatal-warnings && flutter test
```

## Konventionen

- Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:` …)
- Nutzersichtbare Änderungen unter `[Unreleased]` in `CHANGELOG.md`
- Neue Features als eigener Ordner unter `lib/features/<name>/` mit `data`/`domain`/`presentation`
- Querschnittliches nach `lib/core/`, wiederverwendbare Widgets nach `lib/shared/`
- Kein `print` – Logging über die Log-Schicht
- Deutsche Kommentare und Dokumentation, englische Bezeichner im Code

## Hinweis

`android/` und `ios/` werden von `flutter create` erzeugt (siehe `scripts/bootstrap.ps1`).
Handgepflegt sind dort nur die `fastlane/`-Ordner und die Signatur-Konfiguration.
