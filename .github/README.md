# .github/ – Automatisierung und Projektregeln

[← Technische Doku](../docs/TECHNIK.md) · [Änderungen](CHANGELOG.md)

---

## Workflows

| Datei | Auslöser | Ergebnis |
|---|---|---|
| [`ci.yml`](workflows/ci.yml) | Push / PR auf `main` oder `develop` | Format, Analyse, Tests, Debug-Builds für beide Plattformen |
| [`release.yml`](workflows/release.yml) | Tag `v*.*.*` | APK, AAB, IPA + GitHub-Release mit Notizen aus dem Changelog |
| [`deploy.yml`](workflows/deploy.yml) | nach Release / manuell | Play Store (Track `internal`), TestFlight |

Die Build-Nummer ist immer `github.run_number` – dadurch steigt sie monoton,
wie es beide Stores verlangen.

**Fehlende Secrets brechen nichts ab.** Der betroffene Schritt warnt und baut
unsigniert weiter.

---

## Secrets

| Secret | Wofür | Gesetzt |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | Signatur des Play-Store-Pakets | ⬜ |
| `ANDROID_KEYSTORE_PASSWORD` | dazu | ⬜ |
| `ANDROID_KEY_ALIAS` | dazu | ⬜ |
| `ANDROID_KEY_PASSWORD` | dazu | ⬜ |
| `PLAY_SERVICE_ACCOUNT_JSON` | Hochladen in die Play Console | ⬜ |
| `APPSTORE_API_KEY_ID` | App Store Connect | ⬜ |
| `APPSTORE_API_ISSUER_ID` | dazu | ⬜ |
| `APPSTORE_API_PRIVATE_KEY` | dazu | ⬜ |
| `MATCH_PASSWORD` / `MATCH_GIT_URL` | fastlane match | ⬜ |

Solange die Android-Secrets fehlen, wird mit dem Debug-Schlüssel signiert:
zum Ausprobieren brauchbar, für den Play Store nicht.

---

## Weiteres in diesem Ordner

| Datei | Inhalt |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Beitragsleitfaden |
| [`SECURITY.md`](SECURITY.md) | Wie man Sicherheitslücken meldet |
| [`dependabot.yml`](dependabot.yml) | Abhängigkeiten für pub, Actions und Gradle |
| `ISSUE_TEMPLATE/`, `PULL_REQUEST_TEMPLATE.md` | Vorlagen |
