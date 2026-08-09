# Veröffentlichen: App Store und Play Store

Was im Repository steht, ist fertig. Was hier steht, muss ein Mensch klicken –
Apple und Google lassen sich beides nicht per Skript anlegen.

**Ein eigener Mac ist nicht nötig.** Alle Builds laufen auf dem macOS-Runner von
GitHub Actions.

---

## Was schon fertig ist

| | |
|:--|:--|
| Bundle-ID / Package | `will.neurohelp.help`, auf beiden Plattformen gleich |
| Signatur-Ablauf | [ios-signing.yml](../.github/workflows/ios-signing.yml), einmalig per Knopfdruck |
| Release-Build | [release.yml](../.github/workflows/release.yml), signiertes IPA bei jedem Tag |
| TestFlight | [deploy.yml](../.github/workflows/deploy.yml), automatisch nach dem Release |
| Bildschirmfotos | [store-screenshots.yml](../.github/workflows/store-screenshots.yml), 1320×2868 vom Simulator |
| Store-Texte | [ios/fastlane/metadata/](../ios/fastlane/metadata/), versioniert |
| Export-Einstellungen | [ios/ExportOptions.plist](../ios/ExportOptions.plist) |
| Exportregelung | `ITSAppUsesNonExemptEncryption = false` in der Info.plist |
| Datenschutzerklärung | [DATENSCHUTZ.md](DATENSCHUTZ.md) |
| App-Icon 1024×1024 | im Asset-Katalog, ohne Transparenz |

---

## Apple: die Reihenfolge

### 1. Secrets in GitHub setzen

`Settings → Secrets and variables → Actions → New repository secret`

**Für den Build – ohne die geht nichts:**

| Secret | Woher |
|:--|:--|
| `APPSTORE_API_KEY_ID` | App Store Connect → Users and Access → Integrations |
| `APPSTORE_API_ISSUER_ID` | dieselbe Seite, oben |
| `APPSTORE_API_PRIVATE_KEY` | die `.p8`-Datei, **base64-kodiert** |
| `MATCH_PASSWORD` | frei wählbar – verschlüsselt die Zertifikate im Repo |
| `MATCH_GIT_URL` | HTTPS-URL des privaten Zertifikats-Repositorys |
| `MATCH_GIT_TOKEN` | Personal Access Token mit `repo`-Recht, damit CI dort hineinkommt |

Die `.p8` kodieren, Ergebnis landet direkt in der Zwischenablage:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

**Für die Einreichung – erst vor dem Store nötig, nicht für TestFlight:**

| Secret | Inhalt |
|:--|:--|
| `REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME` | Ansprechpartner für Apple |
| `REVIEW_PHONE`, `REVIEW_EMAIL` | Rückfragen des Prüfers |
| `REVIEW_DEMO_USER`, `REVIEW_DEMO_PASSWORD` | **Testkonto.** Ohne das lehnt Apple ab – die App verlangt eine Anmeldung |

Das Testkonto vorher in der App anlegen und ausprobieren. Es muss zum Zeitpunkt
der Prüfung funktionieren.

### 2. Bundle-ID registrieren

developer.apple.com → Certificates, Identifiers & Profiles → Identifiers → **+**

- App IDs → App
- Description: `Neurohelp`
- Bundle ID: **Explicit** → `will.neurohelp.help`
- Capabilities: keine anhaken. Die App braucht keine

### 3. Signatur einrichten

Privates Repository für die Zertifikate anlegen, zum Beispiel
`Phydran6/neurohelp-certificates`. Leer lassen, `match` füllt es.

Dann in GitHub: `Actions → iOS Signatur einrichten → Run workflow`.

Der Lauf erzeugt bei Apple ein Distributionszertifikat und ein
App-Store-Profil und legt beides verschlüsselt ab. **Einmalig** – alle späteren
Builds holen es nur noch.

Scheitert der Lauf mit „Diese Secrets fehlen noch", ist Schritt 1 unvollständig.

### 4. App in App Store Connect anlegen

appstoreconnect.apple.com → Apps → **+** → New App

- Plattform: iOS
- Name: `Neurohelp`
- Primärsprache: **Deutsch**
- Bundle ID: `will.neurohelp.help`
- SKU: frei wählbar

### 5. Bildschirmfotos erzeugen

`Actions → Store-Bildschirmfotos → Run workflow`

Nach dem Lauf das Artefakt `store-screenshots` herunterladen – sechs PNG in
1320×2868. Für den App Store reicht diese eine Größe: Apple rechnet sie für
kleinere Geräte selbst herunter.

Meldet der Lauf eine falsche Größe, ein anderes Gerät wählen. Nötig ist ein
6,9-Zoll-iPhone.

### 6. Was nur von Hand geht

Diese vier Dinge fragt Apple in einem Formular ab, das `fastlane` nicht
zuverlässig bedienen kann. Einmal ausgefüllt, bleiben sie stehen:

**Alterseinstufung** (App Information → Age Rating): überall „Keine" bzw. „Nein".
Die App enthält keine Gewalt, keinen Sex, kein Glücksspiel, keine Drogen, keinen
unbeschränkten Internetzugang und keine nutzergenerierten Inhalte, die andere
sehen können. Erwartetes Ergebnis: **4+**.

**App-Datenschutz** (App Privacy). Antworten, die zum Code passen:

| Frage | Antwort |
|:--|:--|
| Erfasst die App Daten? | **Ja** |
| Kontaktinfo → E-Mail-Adresse | Ja, für *App-Funktionalität* und *Kontoverwaltung*. **Mit Identität verknüpft**, nicht zum Tracking |
| Identifikatoren → Nutzer-ID | Ja, für *App-Funktionalität*. Mit Identität verknüpft, nicht zum Tracking |
| Nutzerinhalte → Andere Nutzerinhalte | Ja, für *App-Funktionalität* – der KI-Text. **Nicht** mit Identität verknüpft, nicht zum Tracking |
| Standort, Kontakte, Gesundheit, Finanzen, Fotos, Verlauf, Diagnose, Werbedaten | **Nein**, alles |
| Wird zum Tracking genutzt? | **Nein** |

Die Aufgaben, Termine und Anrufe gehören **nicht** ins Formular: Sie verlassen
das Gerät nie, und Apple fragt nur nach Übertragung.

**Preis:** kostenlos.

**Datenschutz-URL:**
`https://github.com/Phydran6/Neurohelp/blob/main/docs/DATENSCHUTZ.md`

### 7. TestFlight

Passiert von selbst: Ein Tag `v0.1.0` startet Release, danach läuft Deploy und
schickt den Build zu TestFlight. Verarbeitung dauert 15–60 Minuten.

Interne Tester (bis 100, kein Review nötig) unter Users and Access hinzufügen.

### 8. Texte hochladen und einreichen

Bildschirmfotos nach `ios/fastlane/screenshots/de-DE/` legen, dann auf einem
Rechner mit `fastlane`:

```bash
cd ios && fastlane metadata_only
```

Das schiebt Beschreibung, Untertitel, Schlagwörter und Bilder hoch, ohne etwas
einzureichen. Ergebnis in App Store Connect prüfen.

Zur Prüfung einreichen:

```bash
cd ios && fastlane release_store version:0.1.0 build_number:42
```

---

## Google Play

1. Play Console → App erstellen, Package **`will.neurohelp.help`**
2. Ersten AAB **von Hand** hochladen – Google verlangt das beim ersten Mal.
   Die Datei liegt im GitHub-Release als `*-android-playstore.aab`
3. Service-Account in Google Cloud anlegen, in der Play Console freischalten,
   JSON-Schlüssel herunterladen → Secret `PLAY_SERVICE_ACCOUNT_JSON`
4. Ab dann lädt [deploy.yml](../.github/workflows/deploy.yml) automatisch in den
   Track „internal"

Play verlangt zusätzlich eine **Datensicherheits-Erklärung** – inhaltlich
dieselben Antworten wie bei Apple oben.

---

## Wenn alles live ist

- In [README.md](../README.md) die Store-Knöpfe einkommentieren, den APK-Knopf
  entfernen und die App-Store-ID einsetzen. Die Stellen sind mit
  `STORE-KNOEPFE` markiert
- Die Alpha-Warnung im Abschnitt „Herunterladen" entfernen
- `-alpha.N` aus der Version in [pubspec.yaml](../pubspec.yaml) nehmen

---

## Ein Wort zum Zeitpunkt

Apple lehnt unfertige Apps nach Richtlinie 2.1 ab. Solange die App den
Alpha-Zusatz trägt und bekannte Fehler hat, ist **TestFlight** der richtige Ort –
dort gilt diese Hürde nicht. Der Weg in den Store lohnt sich, wenn die Fehler weg
sind; die Schritte 1 bis 5 gelten für beides und sind dann schon erledigt.
