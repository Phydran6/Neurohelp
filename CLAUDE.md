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

`android/` und `ios/` liegen im Repository. Handgepflegt sind dort nur die
`fastlane/`-Ordner und die Release-Signatur in `android/app/build.gradle.kts`;
alles andere stammt aus `flutter create`.

Kein `CircularProgressIndicator` für lokale Ladevorgänge: Er flackert nur und
bringt `pumpAndSettle` in Widget-Tests zum Hängen.

## Widget-Tests mit Datenbank

Vier Fallen, alle schon getreten:

- `databaseFactoryFfiNoIsolate` statt `databaseFactoryFfi`. In Widget-Tests
  läuft die Zeit simuliert; ein Future, der über eine Isolate-Grenze
  zurückkommt, wird dort nie eingelöst.
- Nach einem Seitenwechsel `pumpAndSettle`, bevor getippt wird. Ein Widget
  ist schon vorhanden, während es noch hereingeschoben wird – ein Tap trifft
  dann daneben, ohne dass der Test es merkt.
- Nicht auf `find.text` warten, wenn derselbe Text im Eingabefeld steht.
  Sonst ist der Test grün, obwohl nichts passiert ist. Auf Schlüssel warten.
- `pumpAndSettle` wartet auf Animationen, nicht auf Futures.
