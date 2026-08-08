# Neurohelp – Konzeptdokument v6.0
*Stand: 8. August 2026 | **Status: BAUBEREIT – keine blockierenden Punkte mehr***

> **Änderungen gegenüber v5.0:**
> - ⚠️→✅ **iOS-Overlay gelöst:** Live Activity + Dynamic Island als iOS-Weg festgelegt
> - **Supabase** als Backend für Planungs- und Umsetzungsphase festgelegt
> - **Mehr-Anbieter-KI-Anbindung** (Claude + ChatGPT) explizit als Bauvorgabe verankert
> - **Kostenmodell in Phasen** ergänzt (Alpha kostenlos, KI-API separat, In-App-Kauf später)

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

1. **Alpha:** Du + enge Freunde
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
- User wählt **einmalig** Overlay (kleines Fenster über dem Anruf) oder Split-Screen – Auswahl wird gemerkt
- Sichtbar währenddessen: Stichpunkte, Notizfeld, Termin-Button

### iOS: Live Activity + Dynamic Island
**Apple erlaubt kein Overlay über anderen Apps.** Der offiziell vorgesehene Weg für genau diesen Zweck ist die **Live Activity**.

- Stichpunkte erscheinen live auf dem **Sperrbildschirm**
- Auf neueren iPhones zusätzlich in der **Dynamic Island**
- Während des Telefonats wischt der User einmal zum Sperrbildschirm und sieht seine Punkte
- Regelkonform, App-Store-tauglich, kein Umgehungs-Trick

### ⚠️ Bewusste Design-Entscheidung
Der Flow **fühlt sich auf iOS anders an** als auf Android: schwebendes Fenster vs. einmal hinwischen. Gleiche Idee, anderer Handgriff.

> **Regel: iOS nicht zwingen, sich wie Android zu verhalten.** Beide Wege werden nativ und für ihre Plattform stimmig gebaut, statt einen schlechten Kompromiss für beide.

**Funktionale Konsequenz für iOS:** Das Notizfeld ist auf einer Live Activity nicht frei beschreibbar. Notizen werden auf iOS **nach dem Anruf** erfasst, im Nachbereitungs-Schritt.

---

## 9. Feature: Termin klären ✅

**V1-Scope:** Nur Neuorganisation. Kein Umbuchen, kein Verschieben, kein Termin-Chaos sortieren.

**1. Buchungsweg bestimmen** – KI schlägt vor (Telefon / Online / Mail / Formular), User kann überstimmen

**2a. Telefon** → übergibt an Anruf-Feature

**2b. Online-Buchung**
- Vorbereitung: Was wird gebraucht? (Versichertennummer, Zeitfenster, Daten)
- Live-Begleitung: nutzt dieselbe Komponente wie Abschnitt 8a (Android Overlay / iOS Live Activity)

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
Der Einstieg fragt **worum es geht** – nicht an wen. Der richtige Empfänger ergibt sich oft erst aus dem Inhalt.

### Schritt 2: Auffangebene „Ich weiß nur, dass da was war"
**Reihenfolge ist bewusst festgelegt:**

1. **Zuerst gräbt die App** – Historie-Check, Ton: *„Warte mal, ich schau kurz für dich."*
   - Findet sie etwas → **Auswahlliste** (alles auf einen Blick, ruhig gehalten, antippen genügt)
2. **Erst wenn nichts gefunden wird** → sanfte Rückfragen als Gedächtnisstütze

> **Begründung:** Gedächtnis anstupsen kann überfordern. Die Denkarbeit macht erst die App, der User ist letzte Instanz.

### Schritt 3: Empfänger ableiten – zweistufig
1. **Erst der Typ** – „Das geht wohl an deine Krankenkasse." → User nickt oder korrigiert
2. **Dann erst der konkrete Kontakt** – Adresse / Formular-Link recherchieren

> **Begründung:** Direkt eine Adresse zu zeigen erzeugt Unsicherheit. Der Typ-Check ist zugleich Fehlerschutz.

### Schritt 4: Formulieren – „Schaffst du's allein oder brauchst du Hilfe?"

**Weg A – User schreibt selbst**
- Textfeld öffnet sich, User schreibt frei den Inhalt
- **Der Floskel-Rahmen wird automatisch ergänzt** (Anrede, Grußformel)

**Weg B – KI formuliert**
- App fragt locker: „Worum ging's denn?"
- User wirft es hin, wie es kommt
- KI formuliert daraus den fertigen Text – inkl. Rahmen

**Regel zum Rahmen:** Immer **höflich-neutraler Standard**, bei allen Empfängern gleich.
> **Begründung:** Kostet keine Denkkapazität, keine Fehlerquelle, funktioniert überall angemessen. Floskel-Arbeit darf den User niemals belasten – auch nicht, wenn er selbst schreibt.

### Schritt 5: Vor dem Senden
Zwischenschritt mit der fertigen Nachricht: **direkt senden** oder **nochmal bearbeiten**. Kein Zwang in beide Richtungen.

### Schritt 6: Senden über die System-App
- E-Mail: Standard-Mail-App des Geräts wird **vorausgefüllt** geöffnet (Empfänger, Betreff, Text)
- **Keine eigene Mail-Integration** – bewusst verworfen (zu aufwendig, Wartungsalbtraum)

**Technische Grenze (wichtig):** Sobald der User in der fremden Mail-App ist, kann Neurohelp **nicht** mitlesen, ob und was gesendet wurde. Es gibt keinen Rückkanal – weder auf Android noch iOS. Ein automatisches „Zurückschicken nach Senden" ist **technisch nicht möglich**.

### Schritt 7: Nachverfolgung beim nächsten Öffnen
- App merkt sich: *Mail vorbereitet und übergeben, nie bestätigt*
- Beim nächsten Öffnen sanfte Nachfrage: *„Du wolltest neulich die Mail an die Krankenkasse rausschicken – hat das geklappt?"* → Ja / Nein
- **Immer mit Ausweg-Button** („Nicht jetzt" / „Nerv mich nicht")
- **Maximal 3 Nachfragen insgesamt**, ruhig verteilt
- Danach hört die App von selbst auf. Der Vorgang bleibt als **offene Aufgabe** liegen. Kein Endlos-Gebettel, keine Schuld.

### Historie
Gespeichert wird der **verfasste Text** + Empfänger + Datum + Status (übergeben / bestätigt / offen).

### Offener Punkt: Kontaktformular
Kontaktformulare **müssen** als Weg möglich sein. Die konkrete technische Umsetzung ist noch offen – siehe Abschnitt 21.

---

## 11. Feature: Aufgabe sortieren ✅

**Zweck:** Gegen die Überforderungs-Blockade. Ein diffuser Berg („Umzug organisieren") wird in winzige, machbare Mikroschritte zerlegt. Nicht „mach die Steuer", sondern „such zuerst nur die Lohnbescheinigung raus".

### Schritt 1: Historie zuerst
Die App prüft, ob es bereits angefangene Aufgaben gibt. Der User muss sich nichts merken.

### Schritt 2: Die zentrale Frage

> **„Soll ich sie für dich zerlegen – oder schaffst du's selbst?"**

### Weg A – Neurohelp zerlegt
- KI zerlegt die Aufgabe in Mikroschritte
- User kann **bestätigen** oder **nachbearbeiten** – Kontrolle bleibt beim User
- **Anzeige: Schritt für Schritt.** Der Berg bleibt unsichtbar. Eine Sache fertig → die nächste erscheint.

### Weg B – User zerlegt selbst
- User legt die große Aufgabe an
- Er erzeugt daraus **verzweigte Unterpunkte** (Baumstruktur / Mindmap-Prinzip), beliebig tief
- Jeder Unterpunkt ist **ausführbar** und trägt eine **klare Notiz, was konkret zu tun ist**
- Jeder Punkt ist **abhakbar** – abgehakt heißt: endgültig erledigt

**Anforderung:** Das Anlegen muss sich **smooth und performant** anfühlen. Genau hier entsteht sonst die Reibung, die die Zielgruppe blockiert.

### Schritt 3: Fokus-Modus ist immer die Grundfunktion
Auch nach eigenem Zerlegen führt die App wieder in den **Schritt-für-Schritt-Fokus** zurück. Die App ist **immer** Hilfebaustein, unabhängig davon, wie fit der User ist.

### Schritt 4: Lückenloses Logging
**Jede Handlung, jeder abgehakte Schritt** wird mitgeschrieben. Damit kann die App sagen: *„Du warst hier stehen geblieben."*

---

## 12. Die Historie als Rückgrat der App

Das durchgängige Loggen ist kein Nebenfeature, sondern die tragende Struktur:

| Feature | Was geloggt wird |
|---|---|
| Anruf | Kontakt, Datum, Thema, Ergebnis |
| Termin | Buchung, Phase der Nachverfolgung |
| Nachricht | Text, Empfänger, Status (übergeben / bestätigt / offen) |
| Aufgabe | Jeder einzelne Schritt + Fortschritt |

Daraus speist sich der Historie-Check am Anfang **jedes** Features.

---

## 13. Sicherheit & Authentifizierung

### Grundmodell: Single Sign-in beim App-Start
Die App sperrt sich selbst. Beim Öffnen wird **einmal** authentifiziert – danach ist alles frei nutzbar.

> **Prinzip:** Eine Hürde, nicht sieben.

### Ebene 1 – App-Sperre beim Start
| Methode | Details |
|---|---|
| **Biometrie** | Fingerabdruck / Gesichtsscan, Android + iOS |
| **PIN / Passwort** | Rückfallebene |

### Ebene 2 – MFA (nur bei Einrichtung / sensiblen Aktionen)
- **TOTP-Authenticator-Apps** (Microsoft, Google Authenticator, Aegis u.a.)
- **Mit geführter Anleitung in der App**
- **Nicht** bei jedem Öffnen

### Ebene 3 – Security Keys (optional)
FIDO2 / WebAuthn – YubiKey und vergleichbare. Rein optional.

### Wiederherstellung
**Pflicht-Konto im Onboarding:** Benutzername, E-Mail, Passwort.

| Weg | Für wen |
|---|---|
| **Reset-Mail** | Alle. Versand serverseitig über Supabase Auth |
| **Wiederherstellungs-Code** | Optional, einmalig bei Einrichtung. Für IT-affine User |

---

## 14. Datenhaltung: Lokal-First

### Grundsatz
**Alle Nutzerdaten liegen lokal auf dem Gerät.** Kontakte, Historie, Notizen, Termine, Aufgaben.

**Speicherplatz ist kein Problem:** reine Textdaten, auch nach Jahren nur wenige Megabyte.

### Was zwingend über das Backend läuft
| Funktion | Warum |
|---|---|
| KI-Verarbeitung | Text muss zum Anbieter und zurück |
| Reset-Mails | Braucht vertrauenswürdigen Absender |
| Benutzerkonten / Passwortprüfung | Braucht zentrale Instanz |

### KI-Toggle – Pflichtentscheidung im Onboarding

> **„Willst du KI nutzen – ja oder nein?"**

- Mit kurzem, **ruhigem** Hinweis, welche Vorteile ohne KI wegfallen
- **Nicht überladen** – aber eindeutig
- Ohne KI läuft die App vollständig lokal

> **Positionierung:** „Deine Daten bleiben auf deinem Gerät" ist ein echter Vertrauens- und Verkaufspunkt.

---

## 15. Info- & Hilfe-Bereich

Eigener Bereich, ruhig auffindbar – stört den minimalistischen Startbildschirm nicht.

1. **Über die App** – Name, Herkunft, Entwickler, Version, Lizenzen
2. **FAQ** – ohne KI: feste Antworten. Mit KI: zusätzlich frei fragbar
3. **Links & Dokumentation**

---

## 16. Onboarding – Eckpunkte

*(Vollständiger Flow → Feinschliff nach der ersten Bauphase. Struktur steht fest:)*

1. Konto anlegen: **Benutzername, E-Mail, Passwort** (Pflicht)
2. **KI-Toggle**: ja / nein, mit Hinweis auf wegfallende Vorteile
3. **Sicherheit einrichten**: Biometrie und/oder PIN/Passwort
4. Optional: MFA / Security Key / Wiederherstellungs-Code
5. **Ton-Auswahl**: locker / neutral / sachlich

---

## 17. Technische Architektur

### App: Flutter

**Begründung:**
- iOS zwingend nötig (Zielgruppe Richtung Apple verschoben)
- Eine Codebasis für beide Plattformen
- Volle Kontrolle über die Oberfläche → reizarmes Design pixelgenau umsetzbar
- Größte Verbreitung und beste Zukunftssicherheit

**Verworfen:** Kotlin Multiplatform (UI trotzdem doppelt), React Native (kein Vorteil), doppelt nativ.

### Backend: Supabase ✅ NEU

Für die Planungs- und Umsetzungsphase wird **Supabase** als Backend eingesetzt statt eines selbstbetriebenen Servers.

**Begründung:**
- Deckt **Benutzerkonten und Login** fertig ab – spart erheblichen Eigenbau
- Deckt **Reset-Mails** ab – die zweite neue Backend-Aufgabe
- Dauerhaftes kostenloses Kontingent, für Alpha-Phase völlig ausreichend
- Kein eigener Serverbetrieb, keine Wartung, keine laufenden Kosten in dieser Phase

**Das Kernprinzip bleibt unverändert:** Die App redet **nie direkt** mit KI-Anbietern. Alle KI-Aufrufe laufen über die Backend-Schicht.

### KI-Anbindung: Mehr-Anbieter von Anfang an ✅ NEU

**Bauvorgabe:** Die KI-Schicht wird von Beginn an so gebaut, dass **mehrere Anbieter parallel dranhängen können** – konkret **Claude und ChatGPT**, weitere später.

- Die App kennt keinen Anbieter, sie kennt nur „die KI"
- Ein Anbieter-Wechsel darf **keine** App-Änderung erfordern
- Später wählt der User seinen Anbieter selbst, das Backend routet entsprechend

> **Wichtig, damit es keine Überraschung gibt:** Eine Claude-Chat-Subscription ist technisch **nicht** dasselbe wie eine KI-Anbindung für eine App. Dafür braucht es einen **API-Zugang** – ein getrennter, nutzungsbasierter Zugang, nicht im Chat-Abo enthalten. Für Testmengen sehr günstig, aber es ist ein eigener Posten.

### Stack

| Komponente | Technologie |
|---|---|
| **App** | Flutter (Dart) – Android + iOS aus einer Codebasis |
| **Lokale DB** | SQLite (Drift / sqflite) |
| **Backend** | Supabase (Auth, Mailversand, KI-Proxy) |
| **KI-Anbindung** | Über Backend, anbieteragnostisch (Claude, OpenAI, weitere) |
| **KI-Zugang** | API-Zugang, nutzungsbasiert |
| **Mailversand** | Supabase Auth (Reset-Mails) |
| **Auth lokal** | Android BiometricPrompt / iOS LocalAuthentication |
| **MFA** | TOTP (RFC 6238) |
| **Security Keys** | FIDO2 / WebAuthn |
| **Kalender** | Gerätekalender (Android / iOS EventKit) + Google Calendar API + Outlook API + ICS-Export |
| **Anruf** | Plattform-Kanal → Android Intent / iOS URL-Scheme |
| **Anrufbegleitung Android** | Overlay-Berechtigung / Split-Screen |
| **Anrufbegleitung iOS** | **Live Activity + Dynamic Island (ActivityKit)** |
| **Mailversand aus App** | System-Mail-App vorausgefüllt öffnen |
| **Versionsverwaltung** | GitHub |
| **Build & Deployment** | GitHub Actions |

---

## 18. Kosten – in Phasen

### Phase 1: Planung & Umsetzung (jetzt)
| Posten | Kosten |
|---|---|
| Supabase | **0 €** (kostenloses Kontingent reicht) |
| GitHub + Actions | **0 €** |
| Reset-Mails | **0 €** in dieser Größenordnung |
| KI-API-Zugang | Nutzungsbasiert, bei Testmengen sehr gering |

### Phase 2: Alpha / Store-Zugang
| Posten | Kosten |
|---|---|
| Google Play Developer | **25 $ einmalig** |
| Apple Developer Program | **99 $/Jahr** (~8–9 €/Monat), verpflichtend |
| Android-Verteilung ohne Store | APK frei verteilbar |
| iOS-Sideloading (EU / DMA) | Möglich, erfordert **trotzdem** Mitgliedschaft + Notarisierung |

### Phase 3: Später – User zahlt seine eigene KI
Der User schließt sein **eigenes KI-Abo innerhalb der App** ab (In-App-Kauf). Damit trägt jeder User seine eigenen KI-Kosten.
**Bewusst weit nach hinten geplant** – die Architektur (Abschnitt 17, Mehr-Anbieter) macht es später möglich, ohne dass jetzt etwas dafür gebaut werden muss.

### Geschäftsmodell
- Grundfunktionen kostenlos (ohne KI)
- KI-Features im Abo

---

## 19. Bau-Reihenfolge

1. Projekt-Setup Flutter + GitHub Actions (Android + iOS Pipelines)
2. Supabase-Projekt anlegen (Auth + Mailversand)
3. **Lokale DB + Historie-Rückgrat (Abschnitt 12) – zuerst, alles hängt daran**
4. Onboarding + Konto + Sicherheit (Abschnitt 13/14/16)
5. Backend-Schicht: KI-Proxy, anbieteragnostisch gebaut
6. Feature **Aufgabe sortieren** (wenigste externe Abhängigkeiten → guter Einstieg)
7. Feature **Nachricht schreiben**
8. Feature **Anruf erledigen** + Anrufbegleitung (Android Overlay / iOS Live Activity)
9. Feature **Termin klären** (baut auf Anruf + Nachricht auf)
10. Info- & Hilfe-Bereich
11. Apple Developer Account einrichten
12. Alpha-Verteilung als APK

---

## 20. Erledigte Blocker ✅

- [x] **iOS-Ersatz für Overlay** → Live Activity + Dynamic Island (Abschnitt 8a)
- [x] **Backend-Betrieb ohne eigene Kosten** → Supabase (Abschnitt 17)
- [x] **Mehr-Anbieter-KI** → als Bauvorgabe verankert (Abschnitt 17)

**Es gibt keine blockierenden Punkte mehr. Der Bau kann beginnen.**

---

## 21. Offene Punkte

### Technisch offen (blockiert den Bau NICHT)
- [ ] **Kontaktformular**: konkrete Ansteuerung von Web-Formularen (Abschnitt 10). Kann geklärt werden, wenn Feature 7 der Bau-Reihenfolge dran ist.
- [ ] Kotlin-Code auf Flutter umbauen
- [ ] GitHub Actions Pipelines aufsetzen
- [ ] Apple Developer Account einrichten (vor iOS-Verteilung)

### Feinschliff-Block – **komplett hinter die erste Bauphase**
Bewusste Entscheidung: Vieles davon zeigt sich erst am laufenden Objekt.
- [ ] Farbschema und visuelles Design
- [ ] Tonfall-Texte und Formulierungen
- [ ] Vollständiger Onboarding-Flow
- [ ] UI-Verhalten Aufgaben-Baumstruktur
- [ ] Datenschutzkonzept (DSGVO / DE)
- [ ] Technische Detailarchitektur
- [ ] KI-Prompts

### Nach V1
- [ ] Freundschaftspflege-Modul

---

## 22. Zukunfts-Ideen (Parkplatz)

1. **KI-geführter Anruf via Twilio** – KI spricht für den User, stellt sich als Assistent vor. Nummer kommt nicht vom Handy des Users. Rechtlich für DE prüfen.
2. **App hört Anruf mit** – Live-Feedback während des Telefonats. Technisch schwierig (kein Audio-Stream-Zugriff).
3. **Warteschleifen-Erkennung** – App erkennt automatische Auswahlmenüs und hilft durch die Optionen.
4. Vorlagen für häufige Situationen (Arzttermin, Handwerker, Reklamation)
5. Geteilte Skripte mit Freunden
6. Termin-Feature erweitern: Umbuchen, Verschieben, Chaos sortieren
7. In-App-Kauf für eigene KI-Abos des Users (siehe Abschnitt 18, Phase 3)

---

## 23. Projektgrundsätze

- **Feinschliff hinter der ersten Bauphase** – erst bauen, dann sehen was fehlt
- **Ein Feature richtig gut, bevor das nächste kommt**
- **Du bist Nutzer Nr. 1** – wenn es für dich funktioniert, funktioniert es
- **Bei Unsicherheit: verschieben, nicht reinpacken** – Scope-Disziplin
- **Plattformen nicht zueinander zwingen** – Android und iOS je nativ stimmig
- **Lebendes Dokument** – wird mit jeder Sitzung aktualisiert

---

*Status: BAUBEREIT. Nächster Schritt: Abschnitt 19, Punkt 1.*
