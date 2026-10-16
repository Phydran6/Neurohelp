# Checkliste: vom Testkanal in den echten Store

> Diese Datei ist die Antwort auf „was muss ich an meinen Entwicklerkonten
> noch einstellen, damit ein richtiger Release geht?".
>
> [STORE.md](STORE.md) beschreibt die **einmalige Einrichtung** bis TestFlight
> und Play-Track „internal". Das hier ist der Weg **darüber hinaus**: bis die
> App öffentlich im App Store und im Play Store steht.

Was eingehakt ist, liegt im Repository und läuft automatisch. Was offen ist,
muss ein Mensch in einer Konsole klicken – Apple und Google lassen sich beides
nicht per Skript anlegen.

---

## Stand: was fehlt wirklich noch

| | Android | iOS |
|:--|:--|:--|
| Signierter Build in der CI | ✅ | ✅ |
| Automatisch in den Testkanal | ✅ Track „internal" | ✅ TestFlight |
| Store-Texte im Repository | ✅ `android/fastlane/metadata/` | ✅ `ios/fastlane/metadata/` |
| Bilder im Repository | ❌ fehlen noch | ❌ fehlen noch |
| Knopf „in die Produktion" | ✅ [promote.yml](../.github/workflows/promote.yml) | ✅ [promote.yml](../.github/workflows/promote.yml) |
| Formulare in der Konsole | ❌ Abschnitt A | ❌ Abschnitt B |
| Geschlossener Test, 12 Tester, 14 Tage | ❌ **nur bei privatem Konto** | entfällt |
| Web-Seite „Konto löschen" | ❌ Google verlangt eine URL | entfällt (App genügt) |

Die beiden roten Punkte unten – geschlossener Test und Lösch-URL – sind die,
an denen ein Release sonst **kurz vor dem Ziel** stehenbleibt. Beide kosten
Zeit bzw. eine Webseite, nicht Code.

---

## A – Google Play

### A1. Kontoart klären (das entscheidet über zwei Wochen Wartezeit)

In der Play Console unter **Einstellungen → Entwicklerkonto → Kontodetails**
steht, ob das Konto als *persönlich* oder als *Organisation* geführt wird.

**Persönliches Konto, nach dem 13.11.2023 angelegt:**
Google verlangt vor dem ersten Produktions-Release einen **geschlossenen Test
mit mindestens 12 Testern, die 14 Tage am Stück beigetreten bleiben**. Erst
danach lässt sich Produktionszugriff beantragen, und der wird noch einmal
geprüft.

Das heißt praktisch: **mindestens drei Wochen einplanen**, bevor die App
öffentlich sein kann. Die 12 Tester müssen echte Google-Konten sein und
dürfen nicht zwischendurch austreten.

Vorgehen:

1. Play Console → **Testen → Geschlossener Test** → Track `beta` (den
   bespielt [promote.yml](../.github/workflows/promote.yml) mit `step: beta`)
2. E-Mail-Liste mit den 12 Konten anlegen
3. Opt-in-Link verschicken, bestätigen lassen, dass alle beigetreten sind
4. 14 Tage laufen lassen
5. **Produktionszugriff beantragen** (eigener Menüpunkt, erscheint erst, wenn
   die Bedingung erfüllt ist)

**Organisationskonto:** Diese Hürde entfällt. Wenn das Projekt ohnehin unter
einer Firma läuft, ist der Wechsel der Kontoart der schnellere Weg – er
verlangt eine D-U-N-S-Nummer und dauert selbst ein paar Tage.

### A2. Service-Account mit genug Rechten

Vorhanden, falls Track „internal" schon läuft. Für die Produktion braucht er
mehr:

Play Console → **Nutzer und Berechtigungen** → der Service-Account →
Berechtigungen:

- [ ] `Releases in Produktion, ausgeschlossene Tests und Vorabtests verwalten`
- [ ] `Store-Eintrag, Preise und Vertrieb verwalten` (für `metadata_only`)
- [ ] `App-Informationen anzeigen`

Prüfen, ohne 20 Minuten zu bauen:

```bash
cd android && fastlane check_access
```

### A3. Die Formulare (App-Inhalte)

Play Console → **Richtlinien → App-Inhalte**. Alles muss grün sein, sonst
lässt sich die Produktion nicht freigeben.

- [ ] **Datenschutzerklärung**
  `https://github.com/Phydran6/Neurohelp/blob/main/docs/DATENSCHUTZ.md`
- [ ] **App-Zugriff** → „Teile des Inhalts sind eingeschränkt". Hier das
      Testkonto hinterlegen, mit dem der Prüfer hineinkommt. **Dasselbe wie
      bei Apple.** Ohne das wird abgelehnt
- [ ] **Anzeigen** → Nein, die App enthält keine Werbung
- [ ] **Inhaltseinstufung** → IARC-Fragebogen, Kategorie *Dienstprogramm*.
      Überall „Nein". Erwartetes Ergebnis: USK 0 / PEGI 3
- [ ] **Zielgruppe** → 18+ (keine Kinder). Damit entfällt die
      Families-Richtlinie
- [ ] **Datensicherheit** → siehe A4
- [ ] **Staatliche App** → Nein
- [ ] **Finanzprodukte** → Nein
- [ ] **Gesundheits-App** → **Nein.** Wichtig: Die App beschreibt ihre
      Zielgruppe, behauptet aber keine Wirkung auf ein Krankheitsbild. Der
      Haftungsausschluss steht in der Beschreibung und im Info-Bereich
- [ ] **Konto löschen** → siehe A5

### A4. Datensicherheits-Formular

Inhaltlich dasselbe wie das App-Datenschutz-Formular bei Apple – mit **einer
Ergänzung seit der Sicherungsfunktion**:

| Frage | Antwort |
|:--|:--|
| Werden Daten erfasst? | **Ja** |
| Personenbezogene Daten → E-Mail-Adresse | Ja, *Kontoverwaltung* und *App-Funktionalität*. Verknüpft, kein Tracking |
| App-Aktivität → Sonstige nutzergenerierte Inhalte | Ja, *App-Funktionalität* – der Text für die KI. Nicht verknüpft, kein Tracking |
| Werden Daten **übertragen**? | Ja, verschlüsselt (HTTPS) |
| Können Nutzer die Löschung beantragen? | **Ja** – in der App und über die URL aus A5 |
| Standort, Kontakte, Gesundheit, Finanzen, Fotos, Nachrichten, Dateien | **Nein**, alles |

> **Die Sicherung ist hier kein meldepflichtiger Punkt.** Sie wird von der
> Android-Gerätesicherung mitgenommen, also von Google selbst, nicht von uns
> übertragen. Das Formular fragt nach Daten, die *die App* erhebt oder
> versendet. Trotzdem steht es in der Store-Beschreibung und in
> [DATENSCHUTZ.md](DATENSCHUTZ.md) – weil es die Antwort auf „liegt wirklich
> alles nur bei mir?" verändert.

### A5. Konto-Lösch-URL (eigene Hürde, oft übersehen)

Google verlangt für jede App mit Kontoanlage eine **im Web erreichbare
Seite**, auf der ein Nutzer die Löschung beantragen kann – „in der App gibt es
einen Knopf" genügt **nicht**, weil jemand ohne installierte App sie auch
erreichen können muss.

Die billigste Lösung ohne eigene Infrastruktur:

1. Eine Markdown-Datei `docs/KONTO-LOESCHEN.md` im Repository mit:
   - dem Weg in der App (Einstellungen → Konto löschen)
   - einer Mail-Adresse für alle, die die App nicht mehr haben
   - was gelöscht wird und was nicht
   - wie lange es dauert
2. GitHub Pages aktivieren oder direkt auf die Datei im Repository verlinken
3. Die URL in der Play Console unter **App-Inhalte → Konto löschen**
   eintragen

- [ ] Seite angelegt
- [ ] URL eingetragen

### A6. Store-Eintrag

- [ ] Texte: liegen in `android/fastlane/metadata/android/de-DE/`, hochladen
      mit `promote.yml` → `step: metadata`
- [ ] **Icon 512×512** und **Feature-Grafik 1024×500** nach
      `android/fastlane/metadata/android/de-DE/images/` legen (siehe das
      README dort)
- [ ] **2 bis 8 Bildschirmfotos** nach `images/phoneScreenshots/`
- [ ] Kategorie: *Produktivität*
- [ ] Kontaktdaten: Support-Mail (dieselbe wie in der App)

### A7. Der Weg nach oben

```
internal  →  beta (geschlossener Test)  →  production
```

- `Actions → In den Store hochstufen → target: android, step: beta`
- nach der Testphase: `step: production`, `rollout: 0.2`

Der Rollout-Anteil ist Absicht: Google liefert zunächst nur an einen Teil der
Geräte aus. Fällt etwas auf, lässt sich das anhalten, bevor es alle trifft.
Hochdrehen ist ein Klick, ein Rückruf ist es nicht.

---

## B – Apple App Store

Die Einrichtung bis TestFlight steht in [STORE.md](STORE.md) und ist
vollständig. Für den öffentlichen Store fehlt:

### B1. Formulare in App Store Connect

- [ ] **Alterseinstufung** → überall „Keine" / „Nein". Erwartet: 4+
- [ ] **App-Datenschutz** → die Tabelle in [STORE.md](STORE.md) ist korrekt
      und bleibt es; die Sicherung ändert daran nichts, weil sie in Apples
      Gerätesicherung läuft, nicht über uns
- [ ] **Preis** → kostenlos
- [ ] **Verfügbarkeit** → Länder festlegen. Die App ist nur auf Deutsch; naheliegend
      sind Deutschland, Österreich, Schweiz
- [ ] **Exportbestimmungen** → erledigt, `ITSAppUsesNonExemptEncryption = false`
      steht in der Info.plist

### B2. Testkonto für den Prüfer

**Der häufigste Ablehnungsgrund überhaupt.** Die App verlangt beim ersten
Start ein Konto; ohne Zugang kommt der Prüfer nicht hinein.

GitHub-Secrets setzen – [promote.yml](../.github/workflows/promote.yml) bricht
ab, wenn sie fehlen:

- [ ] `REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME`
- [ ] `REVIEW_PHONE`, `REVIEW_EMAIL`
- [ ] `REVIEW_DEMO_USER`, `REVIEW_DEMO_PASSWORD`

Das Konto vorher anlegen **und ausprobieren**. Es muss zum Zeitpunkt der
Prüfung funktionieren – auch die Zwei-Faktor-Anmeldung darf dort nicht
eingeschaltet sein, sonst kommt der Prüfer nicht durch.

### B3. Bildschirmfotos

- [ ] `Actions → Store-Bildschirmfotos → Run workflow`
- [ ] Artefakt herunterladen, nach `ios/fastlane/screenshots/de-DE/` legen,
      committen

Eine Größe genügt (1320 × 2868), Apple rechnet herunter.

### B4. Einreichen

```
Actions → In den Store hochstufen
  target: ios
  version: 0.1.0
  build_number: <Lauf-Nummer des Builds, der in TestFlight liegt>
```

Der Lauf baut, lädt hoch und reicht zur Prüfung ein. Veröffentlicht wird
**nicht** automatisch (`automatic_release false` im Deliverfile) – der letzte
Knopf bleibt bei einem Menschen.

### B5. Der Zeitpunkt

Apple lehnt unfertige Apps nach Richtlinie 2.1 ab. Solange die Version den
Zusatz `-alpha.N` trägt, ist das ein unnötiges Risiko:

- [ ] `-alpha.N` aus [pubspec.yaml](../pubspec.yaml) nehmen
- [ ] Bekannte Fehler abarbeiten
- [ ] In [README.md](../README.md) die Store-Knöpfe einkommentieren
      (markiert mit `STORE-KNOEPFE`) und die Alpha-Warnung entfernen

---

## C – Was beide noch brauchen

### C1. Support-Adresse

Beide Stores verlangen eine Kontaktmöglichkeit, und seit dem Hilfe-Umbau gibt
es sie auch in der App.

- [ ] In der Play Console unter **Store-Eintrag → Kontaktdaten** eintragen
- [ ] In App Store Connect unter **App-Informationen** eintragen
- [ ] Prüfen, dass es dieselbe Adresse ist wie `AppConfig.supportEmail`

Übersteuerbar beim Bauen mit `--dart-define=SUPPORT_EMAIL=…`.

### C2. Gemeinsamer KI-Schlüssel

Optional. Ohne ihn fehlt in der ausgelieferten App genau eine KI-Stufe – die
anderen laufen weiter (siehe [KI-ZUGANG.md](KI-ZUGANG.md)).

- [ ] Bei OpenRouter einen Schlüssel anlegen, **mit Ausgabenlimit**
- [ ] Als GitHub-Secret `OPENROUTER_SHARED_KEY` hinterlegen
- [ ] **Nie** ins Repository committen

Ein ausgelieferter Schlüssel lässt sich aus jeder App herausholen. Das Limit
ist keine Vorsichtsmaßnahme, sondern Voraussetzung.

### C3. Datenschutzerklärung aktualisieren

Die Sicherung ist neu und ändert die Aussage „alles bleibt auf dem Gerät".

- [ ] [DATENSCHUTZ.md](DATENSCHUTZ.md) nennt die Gerätesicherung
- [ ] Die Store-Beschreibungen nennen sie ebenfalls

### C4. Eine Runde auf echten Geräten

Kein Formular, aber der Schritt, der am meisten spart:

- [ ] Neuinstallation auf Android: sichern, App löschen, neu installieren,
      Wiederherstellung durchlaufen
- [ ] Dasselbe auf iOS
- [ ] Passwort ändern, Zwei-Faktor einrichten, Konto löschen
- [ ] Einmal komplett ohne KI durchspielen
