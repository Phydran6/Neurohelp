# Changelog

Alle nennenswerten Änderungen an diesem Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

## [0.1.0-alpha.11] - 2026-08-30

### Fixed

- **Ein abgebrochener Termin lässt sich wieder aufnehmen – auch der Anruf.**
  Wer „Anrufen" gewählt und das Telefonat abgebrochen hat, landete beim
  Weitermachen sofort im Eintragen: Die App ging davon aus, der Anruf sei
  gelaufen, und bot ihn nicht mehr an. Jetzt führt der Weg wieder über die
  Wahl. Der zuletzt gewählte Weg steht markiert da – du kannst ihn noch
  einmal gehen oder einen anderen nehmen. Wer den Termin inzwischen schon
  hat, überspringt das mit „Der Termin steht schon – eintragen"
- **Der Kalender fängt bei Montag an.** Datums- und Uhrzeitwähler liefen auf
  Englisch und mit der amerikanischen Woche: Sonntag zuerst, Montag daneben.
  Genau daneben greift man dann auch. Alles, was Flutter an Texten
  beisteuert, spricht jetzt Deutsch, und die Woche beginnt, wo sie im
  Deutschen beginnt
- **Der Wochentag steht beim Termin dabei.** Nach dem Wählen liest du
  „Mo, 31.08.2026, 10:00 Uhr" statt nur des Datums. Ein Griff daneben fällt
  damit sofort auf und nicht erst am falschen Tag
- **„Punkt hinzufügen" ist ein Knopf mit Beschriftung.** Vorher war es ein
  kleines Plus im Eingabefeld – es war da, aber es las sich nicht als
  „hinzufügen", und auf kleinen Bildschirmen war es kaum zu treffen. Der
  neue Punkt wird außerdem ins Bild geschoben, damit man sieht, dass er
  angekommen ist

### Added

- **Ein Termin, der steht, bleibt erreichbar.** Bisher war er mit „Termin
  steht" abgeschlossen und verschwand; was du danach noch wusstest –
  Unterlagen, Überweisung, wo es genau hingeht –, konntest du nirgends mehr
  eintragen. Jetzt stehen deine gebuchten Termine unter „Termine, die
  stehen" und lassen sich öffnen. Uhrzeit, Ort und die Mitnehm-Liste
  kannst du jederzeit nachtragen
- **Auch aus der Erinnerung heraus.** Fragt die App am Vortag, was du
  mitnehmen musst, steht daneben „Etwas nachtragen" – da fällt es einem ja
  ein. Das ist **kein Umbuchen**: Beim Arzt ändert sich davon nichts, das
  bleibt außen vor (Konzept, Abschnitt 9). Verschiebst du den Termin selbst
  auf einen anderen Tag, gilt die Erinnerung am Vortag neu

## [0.1.0-alpha.10] - 2026-08-21

### Added

- **Du kannst jetzt ein eigenes KI-Konto verbinden – kostenlos möglich.** In den
  Einstellungen unter „KI" steht ein Knopf „Konto verbinden". Ein Tap: Du meldest
  dich im Browser bei OpenRouter an und bist zurück. Du bekommst nie einen
  Schlüssel zu sehen und musst nichts kopieren, nichts eintragen, nirgends ein
  Dashboard öffnen. Danach antwortet dein eigener Zugang, und die Antworten
  werden besser. Ohne das ändert sich für dich nichts – die KI der App läuft
  weiter wie bisher (Konzept, Abschnitt 17a)
- **Der ehrliche Hinweis steht direkt daneben, nicht im Kleingedruckten.** Was
  die KI verarbeitet, läuft dann über OpenRouter und den Anbieter des Modells,
  und bei kostenlosen Modellen darf mit diesen Texten häufig trainiert werden.
  Bei Arzt- und Kassenthemen ist das einen Gedanken wert – also steht es dort,
  wo die Entscheidung fällt
- **Wer schon einen eigenen Schlüssel hat**, findet ihn unter „Ich habe schon
  einen eigenen Schlüssel" – aufklappbar, bewusst unauffällig. Für den
  Standardweg taucht nirgends ein Schlüsselfeld auf
- **Zwei neue Antworten im Hilfe-Bereich** zum eigenen KI-Konto: was es bringt
  und was dabei mit den Texten passiert

### Changed

- **Fällt die KI aus, fällt sie weich.** Bisher gab es einen Weg; ging der nicht,
  war die KI weg. Jetzt gibt es Stufen: erst dein eigener Zugang, dann die KI der
  App. Hängt ein Modell am Limit oder ist über Nacht verschwunden, wird still das
  nächste genommen; trägt keins mehr, geht es eine Stufe tiefer weiter. Du siehst
  davon nichts – höchstens, dass es gerade etwas einfacher zugeht
- **Kein Modell ist fest eingebaut.** Welche kostenlosen Modelle es gibt, ändert
  sich ständig. Die App schaut deshalb zur Laufzeit nach und wählt selbst. Du
  sollst nie ein Modell aussuchen müssen und erfährst auch nicht, welches
  geantwortet hat
- **Läuft dein Zugang ab oder wird zurückgezogen**, sagt die App das in einem
  ruhigen Satz und bietet „Neu verbinden" an. Es fällt nichts aus: Solange läuft
  alles über den Standardweg weiter
- **„Konto löschen" nimmt jetzt auch den eigenen KI-Zugang mit.** Er liegt auf
  deinem Gerät, also gehört er zu dem, was dabei weggeräumt wird. Dein Konto bei
  OpenRouter bleibt davon unberührt

## [0.1.0-alpha.9] - 2026-08-19

### Fixed

- **KI-Vorschläge lassen sich wieder übernehmen.** Auf kleinen Bildschirmen
  erschienen die Vorschläge unter dem Textfeld – und weil beim Fragen oft noch
  die Tastatur oben stand, rutschten die Kacheln darunter oder unter den unteren
  Rand. Ein Tipp auf „Übernehmen" bzw. „Einsetzen" landete dann im Nichts, für
  den User „passierte nichts". Jetzt schließt sich beim Erscheinen der
  Vorschläge zuerst die Tastatur, und der Block wird in den sichtbaren Bereich
  geholt – der Tipp kommt wieder an. Betrifft Nachricht, Anruf und Aufgabe
  gleichermaßen

## [0.1.0-alpha.8] - 2026-08-16

### Changed

- **„Konto löschen" löscht jetzt wirklich alles.** Bisher verschwand nur das
  Konto im Backend; die Vorgänge, die Historie, die Einstellungen und die PIN
  blieben auf dem Gerät liegen, und die App lief weiter, als wäre man
  angemeldet – ohne Konto ergibt das keinen Sinn. Jetzt ist es ein Weg: Erst
  räumt das Backend auf, und nur wenn das geklappt hat, räumt die App das
  Gerät leer. Danach sagt sie in einem Satz, was weg ist, und steht wieder am
  Anfang – abgemeldet, ohne Daten. Was die App gar nicht in der Hand hat –
  eine schon übergebene Mail, ein exportierter Termin – bleibt, wo es ist
- **Kein „Text scannen" mehr im Auswahlmenü der Eingabefelder.** Wer beim
  Schreiben mehrmals ins Feld tippte, bekam plötzlich die Kamera angeboten
  und war aus dem Ablauf heraus. Ausschneiden, Kopieren, Einfügen und Alles
  auswählen bleiben. Einen Brief abfotografieren soll man können – aber an
  einer eigenen Stelle, nicht als Stolperfalle mitten im Text

### Added

- **Jedes Feature fängt jetzt auch die auf, die es nicht mehr wissen.** Bisher
  stand am Anfang sofort „Worum geht es?" und ein leeres Feld, und der
  Weiter-Knopf blieb aus, solange nichts drinstand – wer nur wusste, dass da
  was war, kam keinen Schritt weit. Jetzt kommt zuerst die Frage, ob man es
  noch weiß. „Ich weiß es" führt wie bisher ins Feld. „Ich weiß nur, dass da
  was war" lässt die App zuerst in der Historie graben: Findet sie etwas,
  steht es als Liste da und ein Antippen übernimmt das Thema. Findet sie
  nichts, kommen ruhige Gedächtnisstützen – und ein Weiter, das auch mit
  leerem Feld funktioniert. Was fehlt, ergibt sich unterwegs; bei einer
  Nachricht wird aus dem geschriebenen Text am Ende ein Betreff. Derselbe
  Einstieg steht in Nachricht, Anruf, Termin und Aufgabe – gleiche Frage,
  gleiche zwei Wege (Konzept, Abschnitt 10, Schritt 2)
- **Ein sichtbarer Knopf „Aus Zwischenablage einfügen"** beim Schreiben einer
  Nachricht. Wer den Text woanders schon stehen hat, holt ihn damit herüber,
  ohne im Auswahlmenü danach zu suchen

### Fixed

- **Beim Schreiben einer Nachricht sieht man wieder, was man tippt.** Sobald
  die KI-Hilfe einen Vorschlag zeigte, drückte der Vorschlagsblock das
  Textfeld auf wenige Pixel zusammen – eigener Text und Cursor waren nicht
  mehr zu sehen. Feld und KI-Block liegen jetzt gemeinsam in einem
  scrollbaren Bereich: Das Feld behält seine Höhe, der Vorschlag steht
  darunter. Nach „Einsetzen" springt die Ansicht zurück nach oben, damit der
  übernommene Text sofort im Blick ist

## [0.1.0-alpha.7] - 2026-08-15

### Added

- **Die App erklärt sich jetzt selbst.** Beim allerersten Start standen
  bisher sofort Benutzername, E-Mail und Passwort da – ohne ein Wort
  darüber, wofür man sich gerade anmeldet. Davor liegen jetzt zwei
  Bildschirme, mehr nicht: einer, der die vier Features benennt, und einer,
  der die Bedienidee erklärt – eine Frage nach der anderen, Historie-Check
  zuerst, Daten bleiben auf dem Gerät, kein Druck. Beide verlangen nichts
  und sind mit zwei Tipps hinter sich gebracht; vom zweiten kommt man zum
  ersten zurück. Dieselben zwei Bildschirme stehen dauerhaft unter
  „Hilfe & Info", damit niemand die App neu installieren muss, um sie
  wiederzufinden
- **Die Historie ist endlich sichtbar.** Sie war von Anfang an das Rückgrat
  der App – jedes Feature hat hineingeschrieben, gelesen hat daraus nur der
  Historie-Check am Anfang. Nachschauen konnte man nirgends. Jetzt gibt es
  einen eigenen Bereich (Startseite, Hauptmenü und Einstellungen) mit allen
  Vorgängen quer über Anruf, Termin, Nachricht und Aufgabe: durchsuchbar
  nach Thema und Ansprechpartner, filterbar je Feature, offen und erledigt
- **Jeder Vorgang zeigt seinen vollständigen Verlauf.** „Alles wird
  geloggt" war Designprinzip 9 und stimmte auch – nur konnte niemand es
  sehen. Angefangen, Schritt erledigt, übergeben, nachgefragt,
  abgeschlossen: alles mit Zeitpunkt und Notiz. Vorgänge lassen sich von
  Hand abhaken, wieder öffnen, umbenennen und löschen
- **Wiederherstellungs-Codes, und zwar zum Herunterladen.** Nach dem
  Einrichten der Zwei-Faktor-Anmeldung kommt eine Sicherungsdatei mit dem
  Schlüssel und zehn Codes – über das System-Blatt zu speichern, wo der
  User will. Auch der Schlüssel allein lässt sich schon vor dem Bestätigen
  sichern. Jeder Code gilt genau einmal und bringt an der App-Sperre
  vorbei, wenn PIN und Fingerabdruck nicht mehr gehen. Nachholbar und neu
  erzeugbar in den Einstellungen unter „App-Sperre"
- **Termine lassen sich in den Kalender übernehmen.** Der ICS-Export war
  vollständig gebaut, getestet und an keiner Stelle erreichbar. Er hängt
  jetzt am Buchen-Bildschirm

### Fixed

- **Die Nachfrage zu übergebenen Nachrichten hörte nie auf.** Das Konzept
  erlaubt höchstens drei Nachfragen, ruhig verteilt, danach bleibt der
  Vorgang still liegen. Tatsächlich kam die Karte bei **jedem** Öffnen
  wieder: Der Zähler in der Historie wurde nirgends hochgezählt, und
  „Nicht jetzt" blendete sie nur bis zum nächsten Besuch aus
- **Angefangene Nachrichten gingen verloren.** Gespeichert wurde erst beim
  Übergeben an die Mail-App. Wer mittendrin aufhörte, fand nichts wieder –
  und die Liste „Angefangen und liegengeblieben" konnte gar nichts
  enthalten, weil es nie eine liegengebliebene Zeile gab
- **Jede Nachricht hieß in der Historie „Ohne Titel".** Der Vorgang
  entsteht beim Antippen von „Neue Nachricht", also bevor der Betreff
  getippt ist. Nachgezogen wurde er nie
- **Ein sofort abgebrochener Entwurf hinterließ einen leeren Vorgang**, der
  für immer in der Historie stehen blieb
- **Ein gelöschter Vorgang konnte sein Protokoll behalten.** Das Aufräumen
  hing allein an `ON DELETE CASCADE`, und das hängt an einem PRAGMA pro
  Verbindung. Die Ereignisse werden jetzt ausdrücklich mitgelöscht
- **Ein Termin, den es nicht mehr gibt, zeigte einen leeren Bildschirm**
  ohne Erklärung und ohne Ausweg – der Ladezustand wurde in diesem Fall nie
  beendet
- **Die Zwei-Faktor-Einrichtung konnte zwei Faktoren anlegen.** Der Schutz
  gegen den zweiten Aufruf griff während des Ladens nicht, und
  `didChangeDependencies` läuft auch bei jedem Themen- und Größenwechsel
- **iOS 15 gilt jetzt auch für `App.framework`.** Xcode-Projekt und Podfile
  standen bereits auf 15.0; das eingebettete Flutter-Framework bekam ohne
  eigenen Eintrag weiterhin das Engine-Minimum 13.0 – und damit ITMS-90068

## [0.1.0-alpha.6] - 2026-08-10

### Added

- **Anmelden und Passwort zurücksetzen beim ersten Start.** Bisher bot die
  App ausschließlich an, ein neues Konto anzulegen. Wer die App neu
  installiert hatte oder sein Passwort nicht mehr wusste, saß fest. Beides
  steht jetzt als ruhiger Textknopf unter dem Anlegen-Feld
- **Bestätigung per sechsstelligem Code statt Link.** Der Link aus der Mail
  landete im Browser und endete dort mit „Email link is invalid or has
  expired". Der Code wird abgetippt und funktioniert überall – bei der
  Registrierung wie beim Passwort-Reset
- **Die Zwei-Faktor-Anmeldung gibt es wirklich.** Im Onboarding stand
  vorher nur ein „Später"-Knopf und sonst nichts. Jetzt: Schlüssel
  anzeigen, in die Authenticator-App übernehmen, einmal den Code abtippen.
  Überspringen geht weiterhin – dann sagt die App **einmal** Bescheid, dass
  es offen bleibt, und danach nie wieder
- **Konto löschen in den Einstellungen.** Löscht restlos alles, was
  serverseitig zum Konto gehört, und schickt darüber eine Bestätigung per
  Mail
- **Die KI tut endlich etwas.** An vier Stellen erscheint bei
  eingeschalteter KI ein Knopf, der einen Vorschlag erzeugt: Mikroschritte
  für eine neue Aufgabe, der Text einer Nachricht, Ziel und Leitfaden für
  einen Anruf, der Buchungsweg für einen Termin. Der Vorschlag steht in der
  Auswahlliste – übernommen wird nur, was angetippt wird
- **Fingerabdruck und Gesicht sind abschaltbar**, in den Einstellungen unter
  „App-Sperre". Die PIN lässt sich dort ebenfalls ändern
- **Links im Info-Bereich:** Quelltext, Konzept, Datenschutz, Changelog,
  Lizenz und Fehler melden – vorher gab es dort keinen einzigen Verweis
- Störungen beim Anmelden zeigen hinter „Details" den technischen
  Hintergrund zum Kopieren. Vorher endete jede Störung in einem
  freundlichen Satz ohne jeden Anhaltspunkt

### Changed

- **Mindestens iOS 15.** Apple hatte Build 7 mit ITMS-90068 beanstandet: Ab
  Frühjahr 2027 wird kein Upload unter 15.0 mehr angenommen. Ein Test hält
  die Version im Xcode-Projekt und im Podfile jetzt zusammen
- **Der gewählte Ton wirkt sich aus.** Die Frage „Wie soll ich mit dir
  reden?" kam im Onboarding, wurde gespeichert – und danach klang die App
  überall gleich. Jetzt ändern sich Begrüßung, Knöpfe und der Stil der
  KI-Vorschläge
- **Der KI-Schalter wirkt sofort und sagt, ob es geklappt hat.** Vorher zog
  der KI-Zugang seinen Schalter nur beim App-Start, und beim Umlegen
  passierte sichtbar gar nichts
- **Jeder Ablauf beginnt sichtbar mit dem Blick in die Historie** – auch
  wenn nichts gefunden wird. Der stumme Fall war der Fehler: Man konnte
  nicht wissen, ob überhaupt gesucht wurde
- Die Mail-Vorlagen sind deutsch, erklären, was zu tun ist, und stellen den
  Code voran
- Die Version im Info-Bereich kommt aus dem Build. Vorher stand dort
  dauerhaft „0.1.0 (1)", egal was installiert war

### Removed

- **„Etwas anderes" im Hauptmenü.** Der Eintrag versprach einen Bildschirm
  und lieferte den Hinweis, dass es ihn bald gibt. Er kommt zurück, wenn der
  Ablauf dahinter gebaut ist

## [0.1.0-alpha.5] - 2026-08-10

### Changed

- **Die App heißt technisch jetzt `will.neurohelp.help`** statt
  `de.phytech.neurohelp`. Damit trägt sie keinen Firmennamen mehr im
  Inneren – die App steht für sich
- **Achtung beim nächsten Update:** Android sieht die neue Kennung als
  eigenständige App. Die alte Version lässt sich nicht überinstallieren,
  sie muss vorher deinstalliert werden. **Lokale Daten der Alpha gehen
  dabei verloren** – Aufgaben, Verläufe und Einstellungen. Einmalig, und
  nur weil noch niemand außer dir die App hat
- **Auf iOS zeigt die App `0.1.0` statt `0.1.0-alpha.5`.** Apple erlaubt in
  der Versionsnummer nur Ziffern und Punkte und weist alles andere beim
  Hochladen ab. Der Alpha-Zusatz bleibt auf Android sichtbar, wie im Konzept
  gedacht – auf iOS unterscheidet stattdessen die Build-Nummer die Uploads

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

[Unreleased]: https://github.com/Phydran6/Neurohelp/compare/v0.1.0-alpha.11...HEAD
[0.1.0-alpha.11]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.11
[0.1.0-alpha.10]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.10
[0.1.0-alpha.9]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.9
[0.1.0-alpha.8]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.8
[0.1.0-alpha.7]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.7
[0.1.0-alpha.6]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.6
[0.1.0-alpha.5]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.5
[0.1.0-alpha.4]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.4
[0.1.0-alpha.3]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.3
[0.1.0-alpha.2]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.2
[0.1.0-alpha.1]: https://github.com/Phydran6/Neurohelp/releases/tag/v0.1.0-alpha.1
