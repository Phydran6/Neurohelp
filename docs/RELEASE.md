# Release & Deployment

Ziel: ein Tag pushen, alles andere läuft automatisch.

```bash
git tag v0.1.0-alpha.2 && git push origin v0.1.0-alpha.2
```

---

## Branches

Einer bleibt, alles andere ist Arbeitsmaterial:

| Branch | Zweck |
|---|---|
| `main` | Produktiv. Nur von hier wird getaggt und veröffentlicht |
| Arbeitszweige | Ein Zweig je Vorhaben, danach weg |

Der Weg ist immer derselbe: einen Zweig für das Vorhaben aufmachen, per Pull
Request nach `main`, dann taggen und den Zweig löschen. Jeder Zweig durchläuft
dieselbe CI.

Ein dauerhafter `develop` stand hier früher als Zwischenstation. Er wurde nie
so benutzt – gearbeitet wurde von Anfang an in Zweigen je Vorhaben, und
`develop` lief dabei still hinter `main` her. Beschrieben steht jetzt, was
tatsächlich passiert.

---

## Vor jedem Tag

1. Version in `pubspec.yaml` hochziehen
2. Abschnitt in `CHANGELOG.md` anlegen und prüfen:
   `bash scripts/extract_changelog.sh <version>`
3. **Die Download-Links in `README.md` auf die neue Version setzen.**
   `/releases/latest` funktioniert dafür nicht – GitHub überspringt dort
   Vorabversionen, der Link liefe ins Leere

---

## Versionsnummern

Format `<major>.<minor>.<patch>[-alpha.N]`, die Build-Nummer hängt die CI an.

Der Zusatz `-alpha.N` steht in `pubspec.yaml` und ist auf dem Gerät sichtbar.
Er bleibt, solange die App nicht wirklich für fremde Geräte taugt. GitHub
markiert solche Releases automatisch als Vorabversion.

---

## Ablauf

| Schritt | Wo | Was passiert |
|---|---|---|
| 1 | `release.yml` | Version aus dem Tag lesen, Release-Notes aus CHANGELOG.md schneiden |
| 2 | `release.yml` | Android: signiertes AAB + APK bauen |
| 3 | `release.yml` | iOS: signiertes IPA bauen (fastlane match) |
| 4 | `release.yml` | GitHub-Release mit Artefakten und Notizen anlegen |
| 5 | `deploy.yml` | AAB → Play Store Track `internal`, IPA → TestFlight |

Die Build-Nummer ist immer `github.run_number` – dadurch steigt sie monoton, wie es beide
Stores verlangen.

Fehlen Store-Secrets, überspringen die betroffenen Schritte sich selbst mit einer Warnung.
Die Pipeline bleibt grün, es entstehen unsignierte Artefakte.

---

## Vor dem ersten Release: einmalige Einrichtung

### 1. Android-Signatur

Upload-Keystore erzeugen:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`android/app/build.gradle.kts` um die Release-Signatur ergänzen (nach `flutter create`
einmalig einzupflegen):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}
```

`key.properties` und die `.jks` sind in [.gitignore](../.gitignore) – sie werden in der CI aus
Secrets erzeugt.

### 2. Google Play

1. Play Developer Account anlegen (25 $ einmalig)
2. App mit Package `will.neurohelp.help` anlegen, eine Version manuell hochladen (Play verlangt
   das für den ersten Upload)
3. Google-Cloud-Service-Account mit Play-Console-Zugriff anlegen, JSON-Schlüssel herunterladen

### 3. Apple

1. Apple Developer Program (99 $/Jahr)
2. App-ID `will.neurohelp.help` in App Store Connect anlegen
3. App-Store-Connect-API-Key (`.p8`) erzeugen
4. `fastlane match` einrichten – privates Repo für die Zertifikate:
   ```bash
   cd ios && fastlane match init
   ```

---

## GitHub-Secrets

Repository → Settings → Secrets and variables → Actions.

### Android

| Secret | Inhalt |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Store-Passwort |
| `ANDROID_KEY_ALIAS` | z.B. `upload` |
| `ANDROID_KEY_PASSWORD` | Key-Passwort |
| `PLAY_SERVICE_ACCOUNT_JSON` | kompletter Inhalt des Service-Account-JSON |

### iOS

| Secret | Inhalt |
|---|---|
| `APPSTORE_API_KEY_ID` | Key-ID des App-Store-Connect-Keys |
| `APPSTORE_API_ISSUER_ID` | Issuer-ID |
| `APPSTORE_API_PRIVATE_KEY` | Inhalt der `.p8`, base64-kodiert |
| `MATCH_GIT_URL` | URL des privaten match-Zertifikats-Repos |
| `MATCH_PASSWORD` | Passphrase für match |
| `APPLE_ID` | Apple-ID des Entwicklerkontos |
| `DEVELOPER_TEAM_ID` | Team-ID |
| `APPSTORE_TEAM_ID` | App-Store-Connect-Team-ID |

Base64 unter Windows:

```bash
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

---

## Versionierung

[Semantic Versioning](https://semver.org/lang/de/): `MAJOR.MINOR.PATCH`

- `MAJOR` – Brüche im Datenmodell oder in Nutzerabläufen
- `MINOR` – neues Feature, abwärtskompatibel
- `PATCH` – Fehlerbehebungen

Vor 1.0 gilt jedes Release als Vorabversion; `release.yml` markiert `0.x`-Tags automatisch als
Prerelease.

### Release-Schritte von Hand

1. `CHANGELOG.md`: `[Unreleased]` in `[X.Y.Z] - JJJJ-MM-TT` umbenennen, neuen leeren
   `[Unreleased]`-Block darüber anlegen, Vergleichs-Links unten anpassen
2. `pubspec.yaml`: `version:` auf `X.Y.Z+1` setzen
3. Committen, dann taggen:
   ```bash
   git tag vX.Y.Z && git push origin main --tags
   ```

---

## Store-Promotion

Von `internal` weiter in die geschlossene Beta bzw. Produktion:

```bash
cd android && fastlane promote_beta
```

```bash
cd android && fastlane promote_production
```

---

## Alpha ohne Store

Für die Alpha-Phase (Konzept, Abschnitt 19, Punkt 12) reicht das APK aus dem GitHub-Release.
Direkt verteilbar, kein Play-Konto nötig. iOS braucht dagegen **immer** die
Developer-Mitgliedschaft – auch für Sideloading.
