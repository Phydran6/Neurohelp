# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

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
- `android/` und `ios/` erzeugt, Release-Signatur in Gradle eingerichtet;
  `pubspec.lock` eingecheckt; App-Name auf „Neurohelp" korrigiert

### Fixed

- Formatprüfung in der CI: Die SDK-Untergrenze in `pubspec.yaml` bestimmt den
  Stil von `dart format`. Sie liegt jetzt bei 3.8, damit lokal und CI
  denselben Stil verwenden

## [0.1.0] - 2026-08-08

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

[Unreleased]: https://github.com/Phydran6/Neurohelp/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0
