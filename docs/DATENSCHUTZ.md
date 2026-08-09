# Datenschutzerklärung

**Neurohelp** · Stand: 9. August 2026

Diese Erklärung beschreibt, welche Daten die App verarbeitet. Sie ist absichtlich
kurz, weil die App absichtlich wenig überträgt.

---

## Kurzfassung

Alles, was du in Neurohelp einträgst, bleibt auf deinem Gerät. Zum Server gehen
nur drei Dinge: deine Kontoanmeldung, die Passwort-Reset-Mail und – **nur wenn du
KI eingeschaltet hast** – der Text, den die KI formulieren soll.

Es gibt keine Werbung, kein Tracking, keine Analyse-Werkzeuge und keine
Weitergabe an Dritte zu Werbezwecken.

---

## Verantwortlich

Philipp Fischer
Kontakt: über [GitHub-Issues](https://github.com/Phydran6/Neurohelp/issues) oder
die im GitHub-Profil angegebene Adresse

---

## Was auf dem Gerät bleibt

Diese Daten verlassen dein Handy nicht. Sie liegen in einer SQLite-Datenbank im
privaten Speicherbereich der App:

- Aufgaben und ihre Schritte
- Nachrichten, die du entworfen hast
- Anrufe: Ziel, Gesprächspartner, Stichpunkte, Ergebnis
- Termine und die Erinnerungen dazu
- deine gesamte Historie über alle Vorgänge
- deine Einstellungen, einschließlich der KI-Entscheidung
- die PIN der App-Sperre, als Hashwert – nicht im Klartext

**Deinstallieren löscht diese Daten.** Es gibt keine Sicherung in der Cloud.
Das ist eine bewusste Entscheidung, kein fehlendes Feature.

---

## Was zum Server geht

Der Server ist eine [Supabase](https://supabase.com)-Instanz. Rechtsgrundlage ist
Art. 6 Abs. 1 lit. b DSGVO (Erfüllung des Nutzungsvertrags) beziehungsweise
lit. a (Einwilligung) für die KI.

### 1. Konto

**Verarbeitet:** E-Mail-Adresse, Passwort (nur als Hashwert), Zeitpunkt der
Registrierung und der letzten Anmeldung, ein selbstgewählter Anzeigename.

**Warum:** Damit du dich bei einem Gerätewechsel wieder anmelden kannst.

**Wie lange:** Bis du das Konto löschst.

### 2. Passwort zurücksetzen

**Verarbeitet:** deine E-Mail-Adresse, um dir einen Link zu schicken.

**Wie lange:** Der Link verfällt nach kurzer Zeit.

### 3. KI-Formulierung – nur bei eingeschalteter KI

**Verarbeitet:** der Text, den du formulieren lassen möchtest, und die Art der
Aufgabe (zum Beispiel „Aufgabe in Schritte zerlegen"). Kein Name, keine
E-Mail-Adresse, keine Gerätekennung.

**Wohin:** Die Anfrage geht an unseren Server und von dort an einen
Sprachmodell-Anbieter – **Anthropic** (Claude) oder **OpenAI** (GPT), je nach
Konfiguration. Beide verarbeiten Anfragen auch in den USA. Grundlage sind die
Standardvertragsklauseln der EU-Kommission.

**Wie lange:** Wir speichern diese Texte nicht. Die Anbieter halten Anfragen
nach eigenen Angaben zur Missbrauchserkennung befristet vor und nutzen
API-Anfragen nicht zum Training ihrer Modelle.

**Freiwillig:** Beim ersten Start wirst du gefragt, und die Frage hat zwei
gleichwertige Antworten. Ohne KI funktioniert die App vollständig. Du kannst die
Entscheidung in den Einstellungen jederzeit ändern.

**Ein Hinweis in eigener Sache:** Schreib in KI-Felder nichts, was niemand außer
dir lesen soll. Der Text verlässt dabei dein Gerät. Bei ausgeschalteter KI
passiert das nie.

---

## Was die App *nicht* tut

- **Keine Werbung.** Keine Werbekennung, kein IDFA, keine Werbenetzwerke
- **Kein Tracking.** Kein Analyse-Werkzeug, keine Nutzungsstatistik, keine
  Absturzberichte an Dritte
- **Kein Standort.** Die App fragt nicht nach deinem Standort
- **Keine Kontakte.** Telefonnummern und Mailadressen tippst du selbst ein; die
  App liest dein Adressbuch nicht
- **Kein Verkauf von Daten.** An niemanden, zu keinem Preis

---

## Berechtigungen

| Berechtigung | Wofür |
|:--|:--|
| **Internet** | Konto, Reset-Mail, KI. Ohne KI und ohne Konto braucht die App kein Netz |
| **Face ID / Fingerabdruck** | Nur zum Entsperren der App. Biometrische Daten verlassen das Gerät nicht und sind für die App nicht lesbar – das Betriebssystem meldet nur „passt" oder „passt nicht" |

Die App verlangt keine weiteren Berechtigungen. Anrufe und Mails öffnet sie über
die dafür vorgesehenen System-Dialoge; sie darf nicht selbst anrufen oder senden.

---

## Deine Rechte

Du hast Anspruch auf Auskunft, Berichtigung, Löschung, Einschränkung der
Verarbeitung, Datenübertragbarkeit und Widerspruch (Art. 15–21 DSGVO). Eine
Einwilligung – etwa in die KI-Nutzung – kannst du jederzeit widerrufen.

**Konto löschen:** Schreib uns über die oben genannten Wege. Das Konto und die
dazugehörige E-Mail-Adresse werden dann entfernt. Deine Inhalte müssen wir dafür
nicht anfassen, weil wir sie nie hatten – die löschst du selbst, indem du die App
deinstallierst.

Du kannst dich außerdem bei einer Datenschutz-Aufsichtsbehörde beschweren.

---

## Kinder

Die App richtet sich an Erwachsene und Jugendliche. Sie erhebt bewusst keine
Altersangabe und verarbeitet keine Daten von Kindern unter 13 Jahren.

---

## Kein Medizinprodukt

Neurohelp ist ein Werkzeug zur Alltagsorganisation. Es stellt keine Diagnose,
gibt keine medizinischen Ratschläge und ersetzt keine Therapie oder Behandlung.

---

## Änderungen

Änderungen an dieser Erklärung sind über die
[Versionsgeschichte dieser Datei](https://github.com/Phydran6/Neurohelp/commits/main/docs/DATENSCHUTZ.md)
nachvollziehbar. Der Stand oben nennt das Datum der letzten Änderung.
