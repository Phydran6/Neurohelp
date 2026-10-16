# Datenschutzerklärung

**Neurohelp** · Stand: 21. August 2026

Diese Erklärung beschreibt, welche Daten die App verarbeitet. Sie ist absichtlich
kurz, weil die App absichtlich wenig überträgt.

---

## Kurzfassung

Alles, was du in Neurohelp einträgst, bleibt auf deinem Gerät. Zum Server gehen
nur drei Dinge: deine Kontoanmeldung, die Passwort-Reset-Mail und – **nur wenn du
KI eingeschaltet hast** – der Text, den die KI formulieren soll. Hast du ein
eigenes KI-Konto verbunden, geht dieser Text stattdessen direkt von deinem Gerät
zum Anbieter, an unserem Server vorbei.

Damit beim Neuinstallieren nichts verloren geht, legt die App eine
Sicherungsdatei auf deinem Gerät ab. Sie geht **nicht an uns** – sondern dorthin,
wo dein Telefon ohnehin sichert (Google bzw. iCloud), oder dorthin, wo du sie
selbst hinlegst. Abschaltbar in den Einstellungen.

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

**Deinstallieren löscht diese Daten.** Auf unseren Servern liegt davon nichts –
auch keine Kopie „für den Fall der Fälle".

---

## Die Sicherung

Damit beim Neuinstallieren oder beim Gerätewechsel nicht alles verloren ist,
legt die App eine Sicherungsdatei an. Sie enthält dieselben Daten wie oben,
also deine Vorgänge, deine Historie und deine Einstellungen.

**Nicht enthalten sind:** deine PIN, deine Wiederherstellungs-Codes und deine
KI-Zugänge. Die liegen im Schlüsselbund des Geräts und kommen bewusst nicht
mit – eine Datei, die den Zugang zum Gerät gleich mitliefert, wäre das
Gegenteil von Sicherheit.

Die Datei geht **nicht an uns.** Wohin sie geht, hängt davon ab, welchen Weg du
wählst:

| Weg | Wo die Datei landet |
|:--|:--|
| Automatisch (Voreinstellung) | in den Dokumentenordner der App auf deinem Gerät. Von dort nimmt dein Telefon sie in **seine eigene** Sicherung mit – bei Android nach Google Drive, bei iPhone nach iCloud. Das ist deine Sicherung bei deinem Anbieter, nicht unsere |
| „Datei erzeugen" | dorthin, wo du sie im Teilen-Menü hinlegst: Dateien-App, deine Cloud, eine Mail an dich selbst, ein Stick |

Die App kennt **keinen einzigen Cloud-Dienst** und lädt von sich aus nichts
irgendwohin hoch. Im zweiten Fall übergibt sie die Datei nur an das Programm,
das du auswählst.

**Abschaltbar:** In den Einstellungen unter „Sicherung" lässt sich das
automatische Sichern ausschalten. Dann entsteht keine Datei, und es wird auch
nichts in die Gerätesicherung übernommen.

Die Datei ist gepackt, aber **nicht verschlüsselt**. Sie enthält deine
Historie im Klartext. Leg sie dorthin, wo du auch Kontoauszüge hinlegen
würdest.

Einzelheiten: [BACKUP.md](BACKUP.md).

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

### 4. Eigenes KI-Konto – nur wenn du eins verbindest

In den Einstellungen kannst du ein eigenes KI-Konto bei
[OpenRouter](https://openrouter.ai) verbinden. Das ist ein Angebot, keine
Voraussetzung – ohne dieses Konto ändert sich für dich nichts.

**Verarbeitet:** dieselben Texte wie unter Punkt 3, und die Art der Aufgabe.

**Wohin:** Solange ein eigenes Konto verbunden ist, geht die Anfrage **direkt von
deinem Gerät** an OpenRouter und von dort an den Anbieter des Modells, das
antwortet. **Unser Server sieht diese Anfragen nicht.** Welcher Anbieter das ist,
wechselt: Die App wählt zur Laufzeit aus den gerade verfügbaren Modellen.

**Wichtig:** Bei kostenlosen Modellen ist es häufig erlaubt, mit diesen Texten
Modelle zu trainieren. Das ist der Unterschied zu Punkt 3 und der Grund, warum
der Hinweis auch in der App direkt am Angebot steht. Gerade bei Arzt- und
Kassenthemen ist das einen Gedanken wert.

**Dein Zugang:** Der Schlüssel, den die App bei der Anmeldung bekommt, liegt
verschlüsselt im sicheren Speicher deines Geräts (Android Keystore, iOS
Keychain). Er geht **nie** an unseren Server. Über „Trennen" in den Einstellungen
ist er sofort weg; danach läuft die KI wieder über Punkt 3.

**Wie lange:** Wir speichern nichts davon – wir bekommen nichts davon zu sehen.
Was OpenRouter und der jeweilige Modellanbieter speichern, steht in deren eigenen
Erklärungen; für dieses Konto bist du deren Vertragspartner, nicht wir.

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

**Konto löschen:** In der App unter Einstellungen → Konto löschen. Das Konto
und die dazugehörige E-Mail-Adresse werden entfernt, und direkt danach räumt
die App dieses Gerät leer – Vorgänge, Historie, Einstellungen, PIN und die
Sicherungsdatei auf dem Gerät.

Hast du die App nicht mehr installiert, schreib uns über die oben genannten
Wege. Der vollständige Ablauf steht in
[KONTO-LOESCHEN.md](KONTO-LOESCHEN.md).

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
