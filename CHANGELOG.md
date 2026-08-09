# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Changed

- **Die App heißt technisch jetzt `will.neurohelp.help`** statt
  `de.phytech.neurohelp`. Damit trägt sie keinen Firmennamen mehr im
  Inneren – die App steht für sich
- **Achtung beim nächsten Update:** Android sieht die neue Kennung als
  eigenständige App. Die alte Version lässt sich nicht überinstallieren,
  sie muss vorher deinstalliert werden. **Lokale Daten der Alpha gehen
  dabei verloren** – Aufgaben, Verläufe und Einstellungen. Einmalig, und
  nur weil noch niemand außer dir die App hat

### Added

- iOS-Signatur ist einsatzbereit: Export-Einstellungen liegen im
  Repository, ein eigener Arbeitsablauf richtet Zertifikat und Profil
  einmalig ein. Ein eigener Mac ist dafür nicht nötig
- Die App erklärt Apple beim Hochladen von selbst, dass sie nur
  Standardverschlüsselung nutzt – das ersparte Nachfragen bei jedem Upload

## [0.1.0-alpha.4] - 2026-08-09

### Fixed

- **Konto anlegen schlug im Release-Build immer fehl** („Ich erreiche den
  Server gerade nicht"). Der App fehlte die Internet-Berechtigung: Flutter
  legt sie nur in den Debug- und Profile-Manifesten an, im Release fehlte
  sie. Betraf Konto, Reset-Mail und KI – alles Lokale lief normal weiter
- Ein Test prüft das jetzt mit, damit es nicht wiederkommt. Er achtet
  zugleich darauf, dass keine unnötigen Berechtigungen dazukommen

## [0.1.0-alpha.3] - 2026-08-09

### Added

- **Die App hat ein Icon.** Auf Android in fünf Auflösungen plus adaptivem
  Icon, auf iOS in allen 21 Größen
- `tool/make_icons.dart` bereitet das Original auf: Für iOS randlos und ohne
  Transparenz, für Android das Motiv freigestellt und eingerückt

### Fixed

- **Die Startseite auf GitHub zeigte die falsche Datei.** `.github/README.md`
  verdrängt die Wurzel-`README.md` – umbenannt in `UEBERSICHT.md`
- Download-Links zeigen wieder auf eine gültige Datei. `/releases/latest`
  überspringt Vorabversionen und lief ins Leere

### Changed

- Startseite überarbeitet: Icon und Titel oben, ein deutlicher Download-Knopf,
  die vier Funktionen nebeneinander statt untereinander

## [0.1.0-alpha.2] - 2026-08-09

Aufräumen. An der App selbst ändert sich nichts.

### Changed

- **Release-Dateien heißen jetzt sprechend:**
  `Neurohelp-0.1.0-alpha.2-android.apk` statt `app-release.apk`. Man sieht am
  Namen, was man geladen hat
- **Startseite neu**: erklärt, was Neurohelp macht und für wen – mit direkten
  Download-Links. Alles Technische liegt jetzt in
  [docs/TECHNIK.md](docs/TECHNIK.md)
- Jeder Bereich des Repositories hat eine eigene `README.md` und ein eigenes
  `CHANGELOG.md`
- Weniger Dateien in der Wurzel: `CONTRIBUTING.md` und `SECURITY.md` liegen in
  `.github/`, wo GitHub sie genauso findet
- Doku-Dateien deutsch benannt: `ARCHITEKTUR.md`, `BACKEND.md`, `RELEASE.md`

## [0.1.0-alpha.1] - 2026-08-09

Erste Alpha für Android und iOS. Alle fünf Pfade laufen durch, das Backend
steht. **Nicht für den täglichen Gebrauch gedacht** – Daten liegen lokal und
sind bei einer Neuinstallation weg.

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
- **Nachricht schreiben** (Konzept, Abschnitt 10): Ablauf mit Inhalt vor
  Empfänger und Empfängertyp vor Adresse; Schemaversion 4
- Floskel-Rahmen wird automatisch ergänzt – immer derselbe höflich-neutrale
  Standard, bei allen Empfängern gleich, und nie doppelt
- Zustand „übergeben" für Nachrichten, die an die System-App gingen: die App
  kann nicht wissen, ob gesendet wurde. Auf „Nein" bleibt der Vorgang als
  offene Aufgabe liegen, ohne Druck
- **Anruf erledigen** (Konzept, Abschnitt 8): Kategorie, Historie-Check über
  frühere Anrufe, Ziel, Ansprechpartner und Stichpunkte als flexibler
  Leitfaden; Schemaversion 5
- Minimale Nachbereitung – eine Frage, zwei Antworten. Auf „Nein" bleibt der
  Vorgang offen, damit die App Weiterhilfe anbieten kann
- Schnittstelle für die **Anrufbegleitung** (Konzept, Abschnitt 8a): Android
  Overlay oder Split-Screen, iOS Live Activity. `supportsLiveNotes` bildet
  ab, dass Notizen auf iOS erst nach dem Anruf entstehen können
- Die Wahl der Begleitung wird einmalig gemerkt
- **Termin klären** (Konzept, Abschnitt 9): Buchungsweg mit Übergabe an das
  Anruf- bzw. Nachricht-Feature, V1 nur Neuorganisation; Schemaversion 6
- Nachverfolgung in vier Phasen mit höchstens einer Benachrichtigung pro
  Phase. Eine verpasste Erinnerung wird nicht nachgeholt – keine
  Schuldmechanik
- Kalender-Schnittstelle mit Kollisionsprüfung und ICS-Export; ohne
  Kalenderzugriff blockiert nichts, es entfällt nur die Prüfung
- **Info- und Hilfe-Bereich** (Konzept, Abschnitt 15): fester FAQ-Katalog,
  der ohne KI allein trägt; die KI antwortet nur, wenn im Katalog nichts
  passt und der User sie eingeschaltet hat
- „Über die App" mit Herkunft, Entwickler, Version, Lizenzen und einem
  sichtbaren Hinweis zur Datenhaltung
- Neue KI-Aufgabe `help.ask` in App und Backend
- **Startseite** (Konzept, Abschnitt 6): Logo, wechselnder Spruch, ein
  einziger großer Knopf. Der Spruch wechselt täglich statt bei jedem Tippen;
  ein Test hält fest, dass keine Leistungs- oder Drucksprache hineinrutscht
- **Hauptmenü** (Konzept, Abschnitt 7): Auswahl vor Eingabe, freie Eingabe
  zuletzt, ruhige Symbole statt Emojis
- **Fokus-Modus für „Aufgabe sortieren"** (Konzept, Abschnitt 11): ein
  Schritt pro Bildschirm, der Berg bleibt unsichtbar. Historie-Check beim
  Einstieg, Ausweg „Später weitermachen" ohne Mahnung, am Ende eine
  Feststellung statt Lob
- Neue Aufgaben lassen sich selbst zerlegen: ein Feld, Eingabetaste,
  nächster Punkt
- **Nachricht schreiben als Oberfläche** (Konzept, Abschnitt 10): ein Schritt
  pro Bildschirm in der festgelegten Reihenfolge – Inhalt zuerst, dann grob
  der Empfängertyp, dann die Adresse. Der Floskel-Rahmen erscheint in der
  Vorschau
- Übergabe an die Mail-App über `url_launcher`; Android und iOS sind dafür
  freigeschaltet. Der Vorgang bleibt danach **offen**, nicht erledigt
- Sanfte Nachfrage beim nächsten Öffnen mit Ja / Nein / Nicht jetzt
- **Einstellungen**: Tonfall und KI-Toggle. Der Hinweis unter dem Schalter
  sagt je nach Stellung, was das konkret bedeutet
- **Hilfe & Info als Oberfläche**: FAQ zum Aufklappen, freie Frage nur wenn
  der Katalog nichts hergibt, „Über die App" mit Lizenzen und dem
  Datenhinweis sichtbar auf der Seite
- Beide über ruhige Symbole auf der Startseite erreichbar, ohne sie zu
  überladen
- **Anruf erledigen als Oberfläche** (Konzept, Abschnitt 8): Kategorie
  zuerst, dann der Historie-Check auf frühere Vorgänge derselben Kategorie,
  dann Ziel, Ansprechpartner und Stichpunkte
- Während des Anrufs stehen die Stichpunkte groß da; das Notizfeld erscheint
  erst nach dem Wählen – auf iOS wäre es vorher ohnehin nicht beschreibbar
- Anruf starten über `tel:`, hinter einer Schnittstelle; Android und iOS
  sind dafür freigeschaltet
- **Termin klären als Oberfläche** (Konzept, Abschnitt 9): Buchungsweg
  wählen, Telefon übergibt an den Anruf-Ablauf, Mail und Formular an den
  Nachrichten-Ablauf – die Abläufe werden nicht doppelt gebaut
- Die vier Nachverfolgungs-Phasen als Karten: Bestätigung, Checkliste am
  Vortag, Anfahrt am Terminmorgen, Nachfrage danach. Jede verschwindet nach
  dem Antippen und kommt nicht wieder
- Die Dienste nehmen eine einstellbare Uhr entgegen, damit Tests nicht von
  der Tageszeit abhängen
- **Onboarding als Oberfläche** (Konzept, Abschnitt 16): fünf Schritte, einer
  pro Bildschirm. Der KI-Toggle ist eine echte Entscheidung – zwei
  gleichwertige Knöpfe, keine Voreinstellung. Nur die Zusatzsicherheit ist
  überspringbar
- Kein vorgetäuschtes Konto: Solange kein Backend eingerichtet ist, sagt die
  App das ruhig, statt ein Konto zu erfinden
- **App-Sperre**: Beim Öffnen wird Biometrie versucht, ohne Aufhebens; wenn
  sie nicht geht, kommt still die PIN. Falsche PIN heißt „Das war nicht die
  richtige PIN." – kein Vorwurf, keine Zählung
- PIN liegt im sicheren Speicher des Geräts (Keystore / Keychain), nie in der
  Datenbank
- **Backend angebunden**: Registrierung, Anmeldung und Reset-Mail laufen über
  Supabase Auth; das Konto entsteht wirklich, statt nur so zu tun
- KI-Zugang über die Backend-Funktion `ai-proxy`. Die App kennt weiterhin
  weder Anbieter noch Modell – nur den Aufgabentyp
- Ist kein Backend erreichbar, läuft die App vollständig lokal weiter und
  sagt das ruhig, statt einen Fehler anzuzeigen
- `android/` und `ios/` erzeugt, Release-Signatur in Gradle eingerichtet;
  `pubspec.lock` eingecheckt; App-Name auf „Neurohelp" korrigiert

### Fixed

- Formatprüfung in der CI: Die SDK-Untergrenze in `pubspec.yaml` bestimmt den
  Stil von `dart format`. Sie liegt jetzt bei 3.8, damit lokal und CI
  denselben Stil verwenden

## 0.1.0 - 2026-08-08 (nie veröffentlicht)

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

[Unreleased]: https://github.com/Phydran6/Neurohelp/compare/v0.1.0-alpha.4...HEAD
[0.1.0-alpha.4]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.4
[0.1.0-alpha.3]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.3
[0.1.0-alpha.2]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.2
[0.1.0-alpha.1]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.1
