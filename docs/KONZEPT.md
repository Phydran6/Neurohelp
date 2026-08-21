# Neurohelp – Konzeptdokument v7.0
*Stand: 21. August 2026 | **Status: Alpha verteilt – KI-Zugang neu festgelegt***

> **Änderungen gegenüber v6.0:**
> - **KI-Zugang komplett neu gedacht:** OpenRouter-Login (OAuth/PKCE) als Hauptweg, eigene gehostete KI als Standard, BYOK als versteckte Expertenoption
> - **Kein In-App-Kauf, kein Gewerbe** – bewusste Entscheidung, Abschnitt 18 entsprechend umgebaut
> - **Proxy-Prinzip differenziert:** gilt weiterhin für die eigene KI, entfällt beim nutzereigenen Schlüssel
> - **Datenschutz aus dem Feinschliff-Block vorgezogen** – Alpha-Nutzer außerhalb des engeren Kreises ist aktiv
> - Neuer Abschnitt **17a: KI-Zugang** (Detail in separatem Dokument)

---

## 1. Vision

Eine App, die neurodivergenten Menschen im Alltag hilft – als hilfsbereiter Freund, ruhiger Assistent und Werkzeugkasten in einem. Neurohelp vereinfacht das Leben an sich.

**Kernprinzip:** Hilfe zur Selbsthilfe. Die App unterstützt den Nutzer dabei, Dinge selbst zu schaffen. Nur wenn es wirklich nicht geht, übernimmt sie vollständig.

---

## 2. Identität & Werte

| Eigenschaft | Beschreibung |
|---|---|
| **Name** | Neurohelp |
| **Gefühl** | Hilfsbereiter Freund + ruhiger Assistent + Werkzeugkasten |
| **Ton** | Locker, kumpelhaft, modern, persönlich – wie ein Freund bei WhatsApp |
| **Design** | Minimalistisch, reizarm, modern, einladend, selbsterklärend |

### Neurohelp ist NICHT:
- Kein Therapie- oder Medizintool
- Keine Gamification (keine Punkte, Level, Streaks)
- Kein Coach (nichts Belehrendes oder Forderndes)
- Kein Zwang (keine Druck-Mechaniken, kein schlechtes Gewissen)
- Keine Social-/Community-Plattform (erstmal)

### Positionierung: Curb-Cut-Effekt
Optimal gebaut für neurodivergente Menschen – offen für alle. Insbesondere junge Erwachsene, die vom Lebensadmin überfordert sind, profitieren genauso.

---

## 3. Zielgruppe & Veröffentlichung

1. **Alpha:** Du + enge Freunde — **läuft bereits**, inkl. mindestens eines Nutzers außerhalb des engeren Kreises
2. **Beta:** Menschen mit ADHS/Autismus im deutschsprachigen Raum (DACH)
3. **Launch:** Alle Neurodivergenten, international

**Plattform:** Android **und** iOS gleichwertig ab Release.

---

## 4. Designprinzipien (Leitplanken für den Bau)

1. **Minimalistisch** – wenige Elemente pro Bildschirm
2. **Reizarm** – Farben, Schrift, Animationen gedämpft
3. **Selbsterklärend** – die App führt durch sich selbst
4. **Kein Zwang** – niemals Druck, Schuld oder Forderungen
5. **Kumpelhaft** – moderner, persönlicher Ton
6. **Hilfe zur Selbsthilfe** – unterstützen, nicht abnehmen
7. **Auswahl vor Eingabe** – wenig denken müssen als Standard
8. **Erst die App denken lassen, dann den User** – Historie vor Rückfrage
9. **Alles wird geloggt** – damit die App sagen kann: „Du warst hier stehen geblieben"
10. **DAU-Prinzip** – keine administrativen Aktionen für den Nutzer. Nie. Kein Kopieren von Schlüsseln, keine Konten bei Dritten anlegen, keine Dashboards.

---

## 5. Tonfall-System

- **Anpassbar in Einstellungen** (locker / neutral / sachlich)
- **Automatische Anpassung an Situation** (bei Stress sanfter) → späteres KI-Feature
- **Initiale Auswahl beim ersten Start**, jederzeit änderbar

---

## 6. Erster Bildschirm (Startseite)

- Logo
- Einladender, lockerer Spruch im Kumpel-Ton (wechselnd)
- Ein einziger großer Button

> *„Hey, schön dass du da bist. Was steht an?"*

Kein leeres Eingabefeld, das anstarrt. Kein Tutorial nötig.

---

## 7. Hauptmenü

```
"Was geht? Womit kann ich helfen?"

[ 📞 Anruf erledigen ]      ✅
[ 📋 Termin klären ]        ✅
[ ✉️ Nachricht schreiben ]  ✅
[ 🧩 Aufgabe sortieren ]    ✅
[ 💭 (freie Eingabe) ]
```

**Später:** häufig genutzte Aktionen wandern nach oben, eigene Kategorien möglich.

---

## 8. Feature: Anruf erledigen ✅

**1. Kategorie wählen** – „Arzt", „Versicherung", „Handwerker" etc.

**2. Historie checken** – Gibt es offene/vergangene Vorgänge?
- Ja → „Geht's um [Thema vom letzten Mal]?"
- Nein → weiter

**3. Situation beschreiben** – „Was ist los? Erzähl kurz." (Freitext)

**4. Ziel + Ansprechpartner ableiten (KI)**
- Was ist das Ziel? (z.B. „Termin beim Optiker für Sehtest")
- Wer ist der richtige Ansprechpartner?
- Kontaktdaten recherchieren falls nötig

**5. Stichpunkte erstellen** – kein Skript, sondern flexibler Leitfaden

**6. Anruf starten + begleiten** → siehe Abschnitt 8a (plattformabhängig)

**7. Kalender-Integration** – Live-Kollisionsprüfung gegen Gerätekalender, Google, Outlook (ICS-Export ohne Kollisionsprüfung)

**8. Nachbereitung (minimal!)** – „Hat geklappt?" Ja / Nein
- Ja → optional Termin speichern
- Nein → App bietet Weiterhilfe an

**9. Historie aktualisieren** – Kontakt + Datum + Thema + Ergebnis

---

## 8a. Anrufbegleitung – plattformabhängig ✅ GELÖST

Die Begleitung während des Telefonats ist die geteilte Kernkomponente von **Anruf-** und **Termin-Feature**. Sie funktioniert auf beiden Plattformen, aber technisch unterschiedlich.

### Android: Overlay oder Split-Screen
- User wählt **einmalig** Overlay oder Split-Screen – Auswahl wird gemerkt
- Sichtbar währenddessen: Stichpunkte, Notizfeld, Termin-Button

### iOS: Live Activity + Dynamic Island
**Apple erlaubt kein Overlay über anderen Apps.** Der offiziell vorgesehene Weg ist die **Live Activity**.

- Stichpunkte erscheinen live auf dem **Sperrbildschirm**
- Auf neueren iPhones zusätzlich in der **Dynamic Island**
- Regelkonform, App-Store-tauglich, kein Umgehungs-Trick

> **Regel: iOS nicht zwingen, sich wie Android zu verhalten.**

**Funktionale Konsequenz für iOS:** Notizen werden auf iOS **nach dem Anruf** erfasst, im Nachbereitungs-Schritt.

---

## 9. Feature: Termin klären ✅

**V1-Scope:** Nur Neuorganisation. Kein Umbuchen, kein Verschieben, kein Termin-Chaos sortieren.

**1. Buchungsweg bestimmen** – KI schlägt vor (Telefon / Online / Mail / Formular), User kann überstimmen

**2a. Telefon** → übergibt an Anruf-Feature

**2b. Online-Buchung**
- Vorbereitung: Was wird gebraucht? (Versichertennummer, Zeitfenster, Daten)
- Live-Begleitung: dieselbe Komponente wie Abschnitt 8a

**2c. Mail / Kontaktformular** → übergibt an Nachricht-Feature

**3. Nachverfolgung – 4 Phasen, max. eine Benachrichtigung pro Phase, keine Schuldmechanik**

| Phase | Zeitpunkt | Inhalt |
|---|---|---|
| 1 | Nach Buchung | Bestätigung, Termin gespeichert |
| 2 | Tag davor | Erinnerung + Checkliste (was mitnehmen?) |
| 3 | Am Tag selbst | Erinnerung + Anfahrtsinfos |
| 4 | Danach | Nachfrage: gelaufen? offene Punkte? |

---

## 10. Feature: Nachricht schreiben ✅

**Deckt ab:** freie Nachrichten, E-Mail, Kontaktformular (inkl. Terminbuchung per Mail/Formular aus dem Termin-Feature)

### Schritt 1: Inhalt zuerst, nicht Empfänger
Der Einstieg fragt **worum es geht** – nicht an wen.

### Schritt 2: Auffangebene „Ich weiß nur, dass da was war"
1. **Zuerst gräbt die App** – Historie-Check: *„Warte mal, ich schau kurz für dich."*
   - Findet sie etwas → **Auswahlliste**, antippen genügt
2. **Erst wenn nichts gefunden wird** → sanfte Rückfragen als Gedächtnisstütze

> **Begründung:** Die Denkarbeit macht erst die App, der User ist letzte Instanz.

### Schritt 3: Empfänger ableiten – zweistufig
1. **Erst der Typ** – „Das geht wohl an deine Krankenkasse."
2. **Dann erst der konkrete Kontakt** – Adresse / Formular-Link recherchieren

### Schritt 4: Formulieren – „Schaffst du's allein oder brauchst du Hilfe?"

**Weg A – User schreibt selbst** – Textfeld, **Floskel-Rahmen wird automatisch ergänzt**

**Weg B – KI formuliert** – User wirft hin, wie es kommt; KI formuliert inkl. Rahmen

**Regel zum Rahmen:** Immer **höflich-neutraler Standard**, bei allen Empfängern gleich.

### Schritt 5: Vor dem Senden
Zwischenschritt: **direkt senden** oder **nochmal bearbeiten**.

### Schritt 6: Senden über die System-App
- E-Mail: Standard-Mail-App **vorausgefüllt** öffnen
- **Keine eigene Mail-Integration**

**Technische Grenze:** Kein Rückkanal aus der fremden Mail-App. Automatisches „Zurückschicken nach Senden" ist **nicht möglich**.

### Schritt 7: Nachverfolgung beim nächsten Öffnen
- Sanfte Nachfrage: *„Hat das geklappt?"* → Ja / Nein
- **Immer mit Ausweg-Button**, **maximal 3 Nachfragen insgesamt**
- Danach bleibt der Vorgang als **offene Aufgabe** liegen. Keine Schuld.

### Historie
Verfasster Text + Empfänger + Datum + Status (übergeben / bestätigt / offen).

### Offener Punkt: Kontaktformular
Technische Ansteuerung noch offen – siehe Abschnitt 21.

---

## 11. Feature: Aufgabe sortieren ✅

**Zweck:** Gegen die Überforderungs-Blockade. Ein diffuser Berg wird in winzige, machbare Mikroschritte zerlegt.

### Schritt 1: Historie zuerst
Die App prüft, ob es bereits angefangene Aufgaben gibt.

### Schritt 2: Die zentrale Frage

> **„Soll ich sie für dich zerlegen – oder schaffst du's selbst?"**

### Weg A – Neurohelp zerlegt
- KI zerlegt in Mikroschritte, User kann **bestätigen** oder **nachbearbeiten**
- **Anzeige: Schritt für Schritt.** Der Berg bleibt unsichtbar.

### Weg B – User zerlegt selbst
- **Verzweigte Unterpunkte** (Baumstruktur), beliebig tief
- Jeder Unterpunkt **ausführbar**, mit **klarer Notiz**, **abhakbar**

**Anforderung:** Das Anlegen muss sich **smooth und performant** anfühlen.

### Schritt 3: Fokus-Modus ist immer die Grundfunktion

### Schritt 4: Lückenloses Logging

---

## 12. Die Historie als Rückgrat der App

| Feature | Was geloggt wird |
|---|---|
| Anruf | Kontakt, Datum, Thema, Ergebnis |
| Termin | Buchung, Phase der Nachverfolgung |
| Nachricht | Text, Empfänger, Status |
| Aufgabe | Jeder einzelne Schritt + Fortschritt |

Daraus speist sich der Historie-Check am Anfang **jedes** Features.

---

## 13. Sicherheit & Authentifizierung

### Grundmodell: Single Sign-in beim App-Start
> **Prinzip:** Eine Hürde, nicht sieben.

### Ebene 1 – App-Sperre beim Start
| Methode | Details |
|---|---|
| **Biometrie** | Fingerabdruck / Gesichtsscan |
| **PIN / Passwort** | Rückfallebene |

### Ebene 2 – MFA (nur bei Einrichtung / sensiblen Aktionen)
TOTP-Authenticator-Apps, mit geführter Anleitung. **Nicht** bei jedem Öffnen.

### Ebene 3 – Security Keys (optional)
FIDO2 / WebAuthn.

### Wiederherstellung
**Pflicht-Konto im Onboarding:** Benutzername, E-Mail, Passwort.

| Weg | Für wen |
|---|---|
| **Reset-Mail** | Alle. Serverseitig über Supabase Auth |
| **Wiederherstellungs-Code** | Optional, für IT-affine User |

---

## 14. Datenhaltung: Lokal-First

### Grundsatz
**Alle Nutzerdaten liegen lokal auf dem Gerät.** Kontakte, Historie, Notizen, Termine, Aufgaben. Reine Textdaten – Speicherplatz ist kein Problem.

### Was über das Backend läuft
| Funktion | Warum |
|---|---|
| KI-Verarbeitung **über die eigene gehostete KI** | Läuft auf eigener Infrastruktur |
| Reset-Mails | Braucht vertrauenswürdigen Absender |
| Benutzerkonten / Passwortprüfung | Braucht zentrale Instanz |

**Neu ab v7.0:** Nutzt der User einen **eigenen** KI-Zugang (OpenRouter-Login oder eigener Schlüssel), geht die Anfrage **direkt vom Gerät** raus – ohne Umweg über das Backend. Siehe Abschnitt 17a.

### KI-Toggle – Pflichtentscheidung im Onboarding

> **„Willst du KI nutzen – ja oder nein?"**

- Mit kurzem, **ruhigem** Hinweis, welche Vorteile ohne KI wegfallen
- Ohne KI läuft die App vollständig lokal

> **Positionierung:** „Deine Daten bleiben auf deinem Gerät" ist ein echter Vertrauenspunkt.

---

## 15. Info- & Hilfe-Bereich

1. **Über die App** – Name, Herkunft, Entwickler, Version, Lizenzen
2. **FAQ** – ohne KI: feste Antworten. Mit KI: zusätzlich frei fragbar
3. **Links & Dokumentation**

---

## 16. Onboarding – Eckpunkte

1. Konto anlegen: **Benutzername, E-Mail, Passwort** (Pflicht)
2. **KI-Toggle**: ja / nein
3. **Sicherheit einrichten**: Biometrie und/oder PIN/Passwort
4. Optional: MFA / Security Key / Wiederherstellungs-Code
5. **Ton-Auswahl**: locker / neutral / sachlich

**Nicht im Onboarding:** die Wahl des KI-Anbieters. Die Standard-KI läuft sofort, ohne Frage. Das Verbinden eines eigenen Zugangs ist ein späteres Angebot, kein Einstiegshindernis.

---

## 17. Technische Architektur

### App: Flutter
Eine Codebasis für Android + iOS, volle Kontrolle über die Oberfläche.

### Backend: Supabase
Auth, Reset-Mails, Proxy für die eigene gehostete KI. Kostenloses Kontingent reicht für die Alpha.

### Stack

| Komponente | Technologie |
|---|---|
| **App** | Flutter (Dart) |
| **Lokale DB** | SQLite (Drift / sqflite) |
| **Backend** | Supabase (Auth, Mailversand, KI-Proxy für eigene KI) |
| **KI-Zugang** | Siehe Abschnitt 17a |
| **Auth lokal** | Android BiometricPrompt / iOS LocalAuthentication |
| **MFA** | TOTP (RFC 6238) |
| **Security Keys** | FIDO2 / WebAuthn |
| **Kalender** | Gerätekalender + Google Calendar API + Outlook API + ICS-Export |
| **Anruf** | Plattform-Kanal → Android Intent / iOS URL-Scheme |
| **Anrufbegleitung Android** | Overlay-Berechtigung / Split-Screen |
| **Anrufbegleitung iOS** | Live Activity + Dynamic Island (ActivityKit) |
| **Mailversand aus App** | System-Mail-App vorausgefüllt öffnen |
| **Versionsverwaltung** | GitHub |
| **Build & Deployment** | GitHub Actions |

---

## 17a. KI-Zugang ✅ NEU – Kernentscheidung v7.0

> **Detaildokument:** [KI-ZUGANG.md](KI-ZUGANG.md)

### Das Problem
Der User soll KI nutzen können, **ohne** dass Kosten bei dir entstehen und **ohne** dass er administrative Arbeit leisten muss. Beides gleichzeitig schien lange unmöglich.

### Verworfene Wege

| Weg | Warum verworfen |
|---|---|
| Login mit ChatGPT-/Claude-Abo des Users | Existiert nicht. Chat-Abos sind technisch kein API-Zugang, und kein Anbieter erlaubt Fremd-Apps, auf Rechnung eines Nutzer-Abos zu arbeiten. |
| Nur dein eigener API-Schlüssel für alle | Kosten skalieren mit jedem Nutzer. Bei Alpha-Nutzern außerhalb des Freundeskreises nicht tragbar. |
| In-App-Abo (IAP) | Verlangt Auszahlungs- und Steuerkonfiguration → faktisch Gewerbeanmeldung. **Bewusst abgelehnt.** Store-Provision liegt bei 15 %. |
| Nur BYOK (Schlüssel selbst eintragen) | Bricht das DAU-Prinzip. Genau der Admin-Kram, an dem die Zielgruppe scheitert. |

### Festgelegtes Drei-Stufen-Modell

| Stufe | Wer zahlt | Aufwand für den User | Rolle |
|---|---|---|---|
| **1. Eigene gehostete KI** | niemand | keiner – läuft sofort | **Standard** |
| **2. OpenRouter-Login (OAuth/PKCE)** | der User selbst (kostenlose Modelle vorhanden) | ein Tap, wie „mit Konto anmelden" | **Angebot für bessere Qualität** |
| **3. Eigener API-Schlüssel (BYOK)** | der User | Schlüssel eintragen | **versteckt in Einstellungen** |

### Warum OpenRouter
- Offizieller OAuth-Login: die App tauscht einen Code gegen einen **nutzereigenen Schlüssel**. Der User sieht nie einen Schlüssel, kopiert nichts.
- Kostenlose Modelle verfügbar (`:free`), kein Zahlungsmittel nötig für den Einstieg.
- Ein Zugang, viele Modelle – passt exakt auf die anbieteragnostische Schicht.
- **Deine Kosten bleiben bei 0 €, unabhängig von der Nutzerzahl.** Kein Gewerbe nötig, weil kein Geld über dich fließt.
- Will ein User mehr, lädt er bei OpenRouter selbst auf – komplett an dir vorbei.

### Bauvorgaben
1. Die App kennt **keinen Anbieter**, nur „die KI". Ein Wechsel darf keine App-Änderung erfordern.
2. **Kein Modell wird fest verdrahtet.** Die Liste der verfügbaren (und kostenlosen) Modelle wird zur Laufzeit abgefragt, weil sie rotiert.
3. **Proxy-Regel differenziert:**
   - Eigene gehostete KI → über das Backend (Schutz deiner Infrastruktur)
   - Nutzereigener Zugang → **direkt vom Gerät**, der Proxy hätte keinen Zweck und wäre eine zusätzliche Station, auf der fremde Daten landen
4. Der nutzereigene Schlüssel liegt **verschlüsselt lokal** (Keystore / Keychain), nie im Backend.
5. Fällt ein Weg aus, fällt die App sauber auf die nächste Stufe zurück – nie in eine Fehlermeldung.

---

## 18. Kosten

### Laufende Kosten
| Posten | Kosten |
|---|---|
| Supabase | **0 €** (kostenloses Kontingent) |
| GitHub + Actions | **0 €** |
| Eigene gehostete KI | **0 €** (eigene Infrastruktur) |
| KI über OpenRouter | **0 €** für dich – zahlt der User |

### Store-Zugang
| Posten | Kosten |
|---|---|
| Google Play Developer | **25 $ einmalig** |
| Apple Developer Program | **99 $/Jahr**, verpflichtend für iOS |
| Android-Verteilung ohne Store | APK frei verteilbar |

### Bewusst NICHT gemacht
- **Kein In-App-Kauf, kein Abo-Verkauf, keine Gewerbeanmeldung.** Sollte die App wachsen, wäre das nachträglich möglich – die Architektur aus 17a verbaut nichts. Aber es ist ausdrücklich kein Ziel.

---

## 19. Bau-Reihenfolge

*(Teilweise umgesetzt – die Alpha ist bereits verteilt. Maßgeblich ist der Stand im Repository.)*

1. Projekt-Setup Flutter + GitHub Actions
2. Supabase-Projekt anlegen (Auth + Mailversand)
3. **Lokale DB + Historie-Rückgrat (Abschnitt 12) – alles hängt daran**
4. Onboarding + Konto + Sicherheit
5. **KI-Schicht: anbieteragnostisch, Drei-Stufen-Modell aus 17a**
6. Feature **Aufgabe sortieren**
7. Feature **Nachricht schreiben**
8. Feature **Anruf erledigen** + Anrufbegleitung
9. Feature **Termin klären**
10. Info- & Hilfe-Bereich
11. Apple Developer Account einrichten
12. Alpha-Verteilung als APK

---

## 20. Erledigte Blocker ✅

- [x] **iOS-Ersatz für Overlay** → Live Activity + Dynamic Island (Abschnitt 8a)
- [x] **Backend-Betrieb ohne eigene Kosten** → Supabase (Abschnitt 17)
- [x] **Mehr-Anbieter-KI** → als Bauvorgabe verankert (Abschnitt 17a)
- [x] **KI-Kosten ohne Gewerbe und ohne Admin-Kram für den User** → Drei-Stufen-Modell (Abschnitt 17a)

---

## 21. Offene Punkte

### Vorgezogen – nicht mehr im Feinschliff-Block
- [ ] **Datenschutzkonzept (DSGVO)**. Grund: Es nutzt bereits jemand außerhalb des engeren Freundeskreises die App. Damit läuft fremdes Material – oft Arzt- und Kassenthemen – über deine Infrastruktur. Muss angefasst werden, bevor der Nutzerkreis weiter wächst.

### Technisch offen (blockiert den Bau NICHT)
- [x] **OpenRouter-Anbindung** gebaut: OAuth/PKCE, Modellwahl zur Laufzeit, Rückfall-Kette, BYOK. Der Rücksprung läuft über das Custom Scheme `neurohelp://openrouter` – für die Alpha ausreichend. App Link / Universal Link (mit Domain und hinterlegter Datei) bleibt der sauberere Weg für später
- [ ] **Kontaktformular**: konkrete Ansteuerung von Web-Formularen (Abschnitt 10)
- [ ] GitHub Actions Pipelines vollständig aufsetzen
- [ ] Apple Developer Account einrichten (vor iOS-Verteilung)

### Feinschliff-Block – hinter der ersten Bauphase
- [ ] Farbschema und visuelles Design
- [ ] Tonfall-Texte und Formulierungen
- [ ] Vollständiger Onboarding-Flow
- [ ] UI-Verhalten Aufgaben-Baumstruktur
- [ ] Technische Detailarchitektur
- [ ] KI-Prompts

### Nach V1
- [ ] Freundschaftspflege-Modul

---

## 22. Zukunfts-Ideen (Parkplatz)

1. **KI-geführter Anruf via Twilio** – KI spricht für den User. Rechtlich für DE prüfen.
2. **App hört Anruf mit** – Live-Feedback während des Telefonats. Technisch schwierig.
3. **Warteschleifen-Erkennung** – App erkennt automatische Auswahlmenüs.
4. Vorlagen für häufige Situationen (Arzttermin, Handwerker, Reklamation)
5. Geteilte Skripte mit Freunden
6. Termin-Feature erweitern: Umbuchen, Verschieben, Chaos sortieren
7. In-App-Kauf – **nur falls die App unerwartet groß wird**, siehe Abschnitt 18

---

## 23. Projektgrundsätze

- **Feinschliff hinter der ersten Bauphase** – erst bauen, dann sehen was fehlt
- **Ein Feature richtig gut, bevor das nächste kommt**
- **Du bist Nutzer Nr. 1** – wenn es für dich funktioniert, funktioniert es
- **Bei Unsicherheit: verschieben, nicht reinpacken** – Scope-Disziplin
- **Plattformen nicht zueinander zwingen** – Android und iOS je nativ stimmig
- **Kostenlos, quelloffen wo möglich, effizient** – KI wird eingesetzt, weil sie gebraucht wird, nicht weil sie im Trend liegt
- **Lebendes Dokument** – wird mit jeder Sitzung aktualisiert

---

*Die OpenRouter-Anbindung ist gebaut – Stand und Details in [KI-ZUGANG.md](KI-ZUGANG.md).
Nächster Schritt: das vorgezogene Datenschutzkonzept aus Abschnitt 21.*
