<div align="center">

# Neurohelp

**Eine App, die im Alltag hilft, ohne Druck zu machen.**

Für Menschen, denen alltägliche Dinge schwerfallen, die für andere
selbstverständlich sind.

[![CI](https://github.com/Phydran6/Neurohelp/actions/workflows/ci.yml/badge.svg)](https://github.com/Phydran6/Neurohelp/actions/workflows/ci.yml)
[![Lizenz: MIT](https://img.shields.io/badge/Lizenz-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-0.1.0--alpha.2-orange.svg)](https://github.com/Phydran6/Neurohelp/releases)

[**Herunterladen**](#-herunterladen) ·
[Was sie kann](#was-neurohelp-kann) ·
[Für wen](#für-wen-das-gedacht-ist) ·
[Technische Doku](docs/TECHNIK.md)

</div>

---

## Worum es geht

Manche Dinge sind objektiv klein und fühlen sich trotzdem unmöglich an. Beim
Amt anrufen. Eine Mail schreiben, die seit drei Wochen offen ist. Einen
Termin ausmachen. Eine Aufgabe anfangen, die eigentlich aus zwölf kleinen
Aufgaben besteht.

Neurohelp nimmt einem das nicht ab. Es zerlegt es in Schritte, die einzeln
machbar sind, und bleibt dabei ruhig.

**Hilfe zur Selbsthilfe.** Nur wenn es wirklich nicht geht, übernimmt die App.

---

## Was Neurohelp kann

### Aufgabe sortieren

Ein großer Berg wird zu einer Liste kleiner Schritte. Im Fokus-Modus siehst du
immer nur **den nächsten** – der Rest bleibt unsichtbar, bis er dran ist.

### Nachricht schreiben

Du sagst, worum es geht. Die App formuliert daraus eine Nachricht, die man so
abschicken kann. Der höfliche Rahmen kommt automatisch, damit du nicht über
Formulierungen grübelst.

### Anruf erledigen

Vor dem Anruf: Was ist das Ziel, wen erreiche ich, was muss gesagt werden.
Während des Anrufs stehen die Stichpunkte groß auf dem Bildschirm.

### Termin klären

Telefon, Mail oder Formular – die App schlägt den Weg vor und führt hindurch.
Danach erinnert sie an Bestätigung, Vorbereitung und Anfahrt. Jede Erinnerung
kommt genau einmal.

### Hilfe & Einstellungen

Feste Antworten auf die häufigen Fragen. Tonfall einstellbar: locker, neutral
oder sachlich.

---

## Für wen das gedacht ist

Für Menschen mit ADHS, Autismus, Depression, Angststörung oder einfach an
einem Punkt, an dem der Alltag zu viel ist.

Du musst keine Diagnose haben. Wenn dir das oben bekannt vorkommt, ist die App
für dich.

---

## Wie sie sich anfühlt

Das ist der Teil, der bei dieser App wichtiger ist als jede Funktion:

| | |
|---|---|
| **Kein Zwang** | Keine Streaks, keine Punkte, keine Abzeichen |
| **Keine Schuld** | Nichts wird rot. Nichts sagt dir, dass du etwas verpasst hast |
| **Kein Lob** | Erledigt ist erledigt. Kein „Gut gemacht!" |
| **Ein Schritt** | Ein Bildschirm, eine Entscheidung. Nie eine Wand aus Optionen |
| **Kein leeres Feld** | Die App fragt nie „Was möchtest du tun?", ohne selbst anzufangen |

Erinnerungen kommen höchstens dreimal. Danach bleibt ein Vorgang still liegen,
ohne Vorwurf.

---

## Wo deine Daten liegen

**Auf deinem Gerät.** Nicht in einer Cloud.

Aufgaben, Nachrichten, Anrufe, Termine, deine ganze Historie – alles bleibt
lokal in einer Datenbank auf dem Handy.

Zum Server geht nur:

- dein Konto (damit du dich bei einem Gerätewechsel wieder anmelden kannst)
- Reset-Mails, wenn du das Passwort vergisst
- der Text, den du der KI zum Formulieren gibst – und auch das nur, wenn du KI
  eingeschaltet hast

**KI ist freiwillig.** Beim ersten Start wirst du gefragt, und die Frage hat
zwei gleichwertige Antworten. Ohne KI funktioniert die App vollständig, nur
formuliert sie dann nicht selbst.

---

## 📥 Herunterladen

> **Das ist eine Alpha.** Zum Ausprobieren, nicht für den täglichen Gebrauch.
> Daten liegen lokal und sind bei einer Neuinstallation weg.

| Plattform | Datei | Wie |
|---|---|---|
| **Android** | [Neurohelp-0.1.0-alpha.2-android.apk](https://github.com/Phydran6/Neurohelp/releases/download/v0.1.0-alpha.2/Neurohelp-0.1.0-alpha.2-android.apk) | Herunterladen, antippen, installieren |
| **Android (Play Store)** | [Neurohelp-0.1.0-alpha.2-android-playstore.aab](https://github.com/Phydran6/Neurohelp/releases/download/v0.1.0-alpha.2/Neurohelp-0.1.0-alpha.2-android-playstore.aab) | Nur zum Hochladen in die Play Console |
| **iOS** | [Neurohelp-0.1.0-alpha.2-ios-unsigniert.ipa](https://github.com/Phydran6/Neurohelp/releases/download/v0.1.0-alpha.2/Neurohelp-0.1.0-alpha.2-ios-unsigniert.ipa) | Unsigniert – muss erst signiert werden |
| **Alle Versionen** | [Release-Übersicht](https://github.com/Phydran6/Neurohelp/releases) | Ältere Stände und Änderungslisten |
| **Was ist neu** | [CHANGELOG.md](CHANGELOG.md) | Jede Änderung, nachvollziehbar |

**Android:** Beim ersten Mal fragt das Handy, ob Installationen aus dieser
Quelle erlaubt sind. Das ist normal bei Apps außerhalb des Play Stores.

**iOS:** Apple erlaubt keine Installation aus dem Browser. Das IPA ist
unsigniert und braucht TestFlight, Xcode oder ein Sideload-Werkzeug.

---

## Mitmachen

Rückmeldungen sind willkommen – besonders, wenn sich etwas nach Druck anfühlt.
Genau das soll die App nicht.

- [Fehler melden oder Idee vorschlagen](https://github.com/Phydran6/Neurohelp/issues)
- [Beitragsleitfaden](.github/CONTRIBUTING.md)

---

<div align="center">

**[→ Technische Dokumentation](docs/TECHNIK.md)**

Aufbau, Entwicklung, Backend, Release-Prozess

---

[MIT-Lizenz](LICENSE) · © 2026 Philipp Fischer

</div>
