# Sicherung und Wiederherstellung

> Lies zuerst [KONZEPT.md](KONZEPT.md), Abschnitt 14. Bei Widersprüchen
> gewinnt das Konzept.

Das Problem in einem Satz: Alle Nutzerdaten liegen lokal auf dem Gerät, und
ein Gerät geht irgendwann verloren. Ohne Sicherung heißt „lokal-first" für den
User „irgendwann ist alles weg".

---

## Die zwei Wege

Wie überall in dieser App gibt es zwei, und beide führen ans Ziel.

| | **Ich weiß, was ich tue** | **Ich hab keinen Plan** |
|:--|:--|:--|
| Sichern | Datei erzeugen, selbst ablegen | läuft von selbst mit |
| Wo liegt sie | wo der User sie hinlegt | im Dokumentenordner der App |
| In die Cloud | über das Teilen-Blatt, freie Wahl | über die Gerätesicherung |
| Zurückholen | Datei selbst heraussuchen | App schaut am Standardplatz nach |

Der geführte Weg ist nicht der schwächere. Er ist der, bei dem der User keine
Entscheidung treffen muss – und deshalb der, bei dem eine Sicherung
tatsächlich existiert, wenn sie gebraucht wird.

---

## Was in der Datei steht

Alle Tabellen aus [schema.dart](../lib/core/db/schema.dart), Zeile für Zeile,
als Spaltenname und Wert:

- `history_entries`, `history_events` – die Historie
- `task_nodes`, `messages`, `calls`, `appointments` – die Vorgänge
- `settings` – Ton, Theme, KI-Schalter, Anrufbegleitung

**Nicht** in der Datei:

| | Warum |
|:--|:--|
| PIN | liegt im Schlüsselbund. Eine Sicherungsdatei, die den Zugang zum Gerät mitliefert, ist das Gegenteil von Sicherheit |
| Wiederherstellungs-Codes | dasselbe |
| KI-Zugänge (OpenRouter, eigener Server) | dasselbe. Außerdem fremde Zugangsdaten, die uns nichts angehen |
| `lock_method` | Stünde die Sperre drin und die PIN nicht, verlangte die App nach dem Einspielen eine PIN, die es nirgends gibt |

Die App-Sperre wird nach dem Einspielen neu eingerichtet. Das steht so auch
auf dem Bildschirm.

**Die Datei ist gepackt, nicht verschlüsselt.** Sie enthält die Historie im
Klartext. In der App steht deshalb der Satz: leg sie dorthin, wo du auch
Kontoauszüge hinlegen würdest. Eine Verschlüsselung bräuchte ein Passwort, und
ein vergessenes Passwort auf einer Sicherungsdatei ist dieselbe Sackgasse wie
gar keine Sicherung.

---

## Das Format

`.nhbackup` – gzip über UTF-8-JSON.

```json
{
  "format": "neurohelp.backup",
  "formatVersion": 1,
  "schemaVersion": 6,
  "appVersion": "0.1.0-alpha.10",
  "createdAt": "2026-09-22T14:30:00.000",
  "checksum": "sha256 über tables",
  "tables": {
    "history_entries": [{ "id": "…", "title": "…" }]
  }
}
```

**Warum gzip und nicht zip:** Eine Sicherung ist genau eine Datei, kein
Ordner. Ein Zip bräuchte ein zusätzliches Paket und würde ein Verzeichnis
nachbilden, in dem eine einzige Datei liegt. Gzip steckt in Dart schon drin
und packt dieselben Daten auf etwa ein Zehntel.

**Warum trotzdem JSON:** Wer die Datei entpackt, findet lesbaren Text –
nachvollziehbar, durchsuchbar, im Notfall von Hand reparierbar.

Beim Einlesen wird auch **ungepacktes** JSON angenommen: Manche Mail- und
Cloud-Programme packen Anhänge unterwegs selbst aus.

Die Prüfsumme deckt nur `tables` ab. Eine abgeschnittene oder halb übertragene
Datei fällt damit auf, **bevor** sie eingespielt wird – statt als halb
eingespielte Historie zu enden.

---

## Versionstoleranz

Das ist der eigentliche Anspruch: **Eine Sicherung aus jeder Version lässt
sich in jede Version einspielen.** Deshalb steht in der Datei kein Objekt
„Termin", sondern Tabelle, Spalte, Wert.

| Fall | Was passiert |
|:--|:--|
| Sicherung kennt eine Spalte mehr (neuere App) | Spalte wird übergangen |
| Sicherung kennt eine Spalte weniger (ältere App) | Spalte bekommt den Standardwert aus dem Schema |
| Sicherung kennt eine Tabelle mehr | Tabelle wird übersprungen und **gemeldet** |
| Eine einzelne Zeile passt nicht | Zeile wird übersprungen und gezählt |
| Dateiformat ist neuer als die App | klare Ansage: „Aktualisiere die App" |

Was nicht übernommen werden konnte, steht nach dem Einspielen auf dem
Bildschirm. Stillschweigend die Hälfte zu verlieren wäre schlimmer als ein
Fehler.

Fremdschlüssel sind für die Dauer des Einspielens abgeschaltet: Die
Unterpunkte einer Aufgabe zeigen auf dieselbe Tabelle, und in welcher
Reihenfolge sie in der Datei stehen, weiß niemand.

---

## Der Standardplatz

`<Dokumentenordner der App>/Sicherungen/neurohelp-letzte-sicherung.nhbackup`

Eine Datei, immer die neueste. Eine wachsende Sammlung wäre genau die
Entscheidung, die dieser Weg dem User abnehmen soll.

**Warum das eine Neuinstallation überlebt:**

| Plattform | Mechanismus |
|:--|:--|
| Android | Auto Backup nach Google Drive, siehe [backup_rules.xml](../android/app/src/main/res/xml/backup_rules.xml) und [data_extraction_rules.xml](../android/app/src/main/res/xml/data_extraction_rules.xml) |
| iOS | Der Dokumentenordner steckt in der Gerätesicherung nach iCloud bzw. auf den Rechner |

Auf Android steht dort eine **Erlaubnisliste**, keine Sperrliste. Ohne die
Dateien würde Android die gesamte App sichern – inklusive der Datenbank und
des Schlüsselbunds. Das wäre eine Cloud-Speicherung, um die niemand gebeten
hat (Konzept, Abschnitt 14). Mitgenommen wird genau der Ordner
`Sicherungen/`, und der ist leer, solange der User die automatische Sicherung
abgeschaltet hat.

**Was das nicht kann:** Hat der User die Gerätesicherung abgeschaltet oder
wechselt er von Android zu iPhone, ist die Datei weg. Dafür gibt es den
zweiten Weg – und wenn auch der nichts hergibt, sagt die App das und bietet
einen Kontaktweg an, statt eine leere Seite zu zeigen.

---

## Cloud-Speicher

Die App kennt **keinen einzigen Cloud-Dienst** und schickt von sich aus nichts
irgendwohin. Trotzdem erreicht sie alle:

- „Datei erzeugen" öffnet das Teilen-Blatt des Systems
- Dort stehen iCloud Drive, Google Drive, Dropbox, Mail an sich selbst – alles,
  was auf dem Gerät installiert ist
- Der User wählt

Das ist die ehrlichste Umsetzung von „optionaler Cloud-Speicher": kein eigener
Speicher, keine eigenen Zugangsdaten, keine neue Stelle, an der fremde Daten
liegen. Und sie funktioniert ohne eine Zeile Backend-Code.

**Supabase kommt dafür nicht in Frage.** Das Konzept sagt: lokal-first, neue
Cloud-Speicherung ist begründungspflichtig. Die vollständige Historie eines
Users auf unserem Server abzulegen wäre die größtmögliche Abweichung davon –
für einen Zweck, den das Teilen-Blatt schon erfüllt.

---

## Wann automatisch gesichert wird

Beim Zurückkommen aus einem Ablauf ins Hauptmenü
([main_menu_page.dart](../lib/features/home/presentation/main_menu_page.dart)).
Dort ist etwas entstanden, und der User macht gerade nichts.

Die Sicherung läuft im Hintergrund und **meldet sich nie** – auch nicht bei
einem Fehler. Der User hat nicht darum gebeten, also darf sie ihn auch nicht
aufhalten. Fehler landen im Log.

Abschaltbar in beiden Einstellungs-Wegen.

---

## Der Einstieg nach einer Neuinstallation

[restore_gate_page.dart](../lib/features/backup/presentation/restore_gate_page.dart)
läuft **vor** dem Onboarding. Wer die App neu installiert hat, hatte sie schon
einmal; ihn zuerst durch die Einführung zu schicken und ihm danach zu sagen,
dass seine Sachen übrigens wieder da sind, ist die falsche Reihenfolge. Erst
recht, weil die Sicherung die Einstellungen mitbringt und das eben
Eingestellte sofort wieder überschreibt.

Die Frage kommt **genau einmal** (`restoreOffered`).

---

## Was beim Löschen passiert

„Konto löschen" räumt auch den Standardplatz leer. Sonst stünde nach „dieses
Gerät ist leergeräumt" die vollständige Historie weiter im Dateisystem – und
Android hätte sie längst nach Google gesichert.

Eine Datei, die der User selbst woanders abgelegt hat, bleibt liegen. Die kann
die App nicht anfassen, und das sagt sie auch.
