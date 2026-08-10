# Supabase-Backend

Umsetzung von Abschnitt 17 des [Konzepts](KONZEPT.md). Supabase deckt genau drei
Dinge ab — mehr gehört nicht ins Backend:

| Funktion | Warum zentral |
|---|---|
| Benutzerkonten & Login | braucht eine zentrale Instanz |
| Reset-Mails | braucht einen vertrauenswürdigen Absender |
| KI-Proxy | die App darf nie direkt mit einem KI-Anbieter reden |

**Alles andere bleibt lokal auf dem Gerät.** Die Migration enthält bewusst keine
Tabellen für Historie, Aufgaben, Nachrichten oder Kontakte.

---

## Aufbau

```
supabase/
├─ config.toml                Lokale Entwicklungsumgebung
├─ templates/                 Mail-Vorlagen, deutsch, Code statt Link
│  ├─ confirmation.html        Registrierung bestätigen
│  ├─ recovery.html            Passwort zurücksetzen
│  ├─ magic_link.html          Anmeldung ohne Passwort (derzeit ungenutzt)
│  └─ email_change.html        Adresswechsel bestätigen
├─ migrations/                Schema, append-only
│  └─ 20260808120000_init.sql  Profile, Wiederherstellungs-Codes, RLS
└─ functions/
   ├─ _shared/cors.ts
   ├─ ai-proxy/               Anbieteragnostischer KI-Proxy
   │  ├─ index.ts
   │  └─ prompts.ts           Prompt-Register (ohne App-Update änderbar)
   └─ delete-account/         Konto restlos löschen, mit Bestätigungs-Mail
      └─ index.ts
```

---

## Einmalige Einrichtung

CLI installieren:

```bash
npm install -g supabase
```

Projekt auf [supabase.com](https://supabase.com) anlegen (kostenloses Kontingent
reicht für die Alpha-Phase), dann verknüpfen:

```bash
supabase link --project-ref <project-ref>
```

Schema einspielen:

```bash
supabase db push
```

---

## Auth einrichten (Dashboard)

`supabase/config.toml` gilt **nur lokal**. Am gehosteten Projekt müssen
dieselben Werte im Dashboard stehen, sonst greifen sie nicht.

### URL Configuration

Ein frisches Supabase-Projekt hat als Site-URL `http://localhost:3000`. Steht
sie so, zeigt jeder Link aus einer Bestätigungs- oder Reset-Mail dorthin – auf
dem Handy öffnet sich ein Browser, findet nichts und endet mit:

```
?error=access_denied&error_code=otp_expired
```

Das ist kein abgelaufener Code, sondern eine falsche Adresse. Unter
**Authentication → URL Configuration** eintragen:

| Feld | Wert |
|---|---|
| Site URL | `will.neurohelp.help://login-callback` |
| Redirect URLs | `will.neurohelp.help://login-callback` |

### Mailversand (Voraussetzung für alles Weitere)

Der eingebaute Mailversand von Supabase ist **kein Produktivweg**:

- rund zwei Mails pro Stunde
- nur an Adressen, die im Projekt-Team stehen — Tester bekommen nichts
- **die Vorlagen sind gesperrt.** Im Dashboard steht dann oben „Set up custom
  SMTP to edit templates", und Betreff wie Inhalt lassen sich nicht ändern

Ohne eigenen SMTP verschickt Supabase also seine englische Standard-Mail mit
Link statt Code. Die App fängt das ab („Kein Code drin? Ich hab den Link
angetippt" auf dem Bestätigungs-Bildschirm), aber das ist der Notausgang,
nicht der gedachte Weg.

Unter **Authentication → Emails → SMTP Settings** einen eigenen Absender
eintragen (Sender-Adresse, Host, Port 465, Benutzer, Passwort). Erst danach
sind die Vorlagen editierbar.

### Mail-Vorlagen

Unter **Authentication → Emails → Templates** die Vorlagen aus
[supabase/templates/](../supabase/templates/) einfügen. Sie sind deutsch und
stellen **den sechsstelligen Code voran**, nicht den Link.

Das ist Absicht: Ein Link muss aus der Mail-App über den Browser zurück in die
App finden. Das scheitert regelmäßig – falscher Browser, Link-Vorschau des
Mail-Anbieters, Weiterleitung. Ein Code wird abgetippt und funktioniert immer.
Die App verlangt deshalb den Code (`verifyOTP`), der Link ist nur die Zugabe.

Wichtig: `{{ .Token }}` muss in der Vorlage stehen. Ohne diesen Platzhalter
verschickt Supabase den Code gar nicht erst.

### Zwei-Faktor

Unter **Authentication → Multi-Factor** muss TOTP aktiviert sein. Ohne das
antwortet `auth.mfa.enroll` mit einem Fehler, und die Einrichtung in der App
bricht ab.

---

## Lokal entwickeln

```bash
supabase start
```

```bash
supabase functions serve ai-proxy --env-file supabase/.env.local
```

Reset-Mails landen im lokalen Mail-Catcher unter http://localhost:54324.

`supabase/.env.local` ist über [.gitignore](../.gitignore) ausgeschlossen:

```
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
AI_PROVIDER=anthropic
```

---

## Deployen

```bash
supabase functions deploy ai-proxy
```

```bash
supabase functions deploy delete-account
```

Secrets setzen (liegen nur im Backend, nie in der App):

```bash
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```

```bash
supabase secrets set OPENAI_API_KEY=sk-...
```

```bash
supabase secrets set AI_PROVIDER=anthropic
```

| Variable | Zweck | Standard |
|---|---|---|
| `AI_PROVIDER` | `anthropic` oder `openai` | `anthropic` |
| `ANTHROPIC_API_KEY` | API-Zugang Claude | — |
| `ANTHROPIC_MODEL` | Modell-ID | `claude-opus-5` |
| `OPENAI_API_KEY` | API-Zugang ChatGPT | — |
| `OPENAI_MODEL` | Modell-ID | `gpt-5` |
| `ALLOWED_ORIGIN` | CORS, nur für Web/lokale Tests | `*` |
| `SMTP_HOST` | Mailversand für die Löschbestätigung | — |
| `SMTP_PORT` | Port des Mailservers | `465` |
| `SMTP_USER` | Benutzer am Mailserver | — |
| `SMTP_PASS` | Passwort am Mailserver | — |
| `SMTP_FROM` | Absenderadresse | `SMTP_USER` |
| `SMTP_TLS` | `false` schaltet TLS ab | `true` |

`SUPABASE_URL`, `SUPABASE_ANON_KEY` und `SUPABASE_SERVICE_ROLE_KEY` setzt
Supabase für Edge Functions von selbst; sie müssen nicht gesetzt werden.

> Ohne SMTP löscht `delete-account` trotzdem – es geht dann nur keine
> Bestätigungs-Mail raus, und die App sagt „Konto gelöscht." statt „Die
> Bestätigung liegt gleich in deinem Postfach.". Ein fehlender Mailversand
> darf ein erfolgreiches Löschen nicht in einen Fehler verwandeln.

> **Wichtig:** Ein Claude-Chat-Abo ist **nicht** dasselbe wie ein API-Zugang.
> Für die App wird ein getrennter, nutzungsbasierter API-Zugang gebraucht
> (Konzept, Abschnitt 17). Bei Testmengen sind die Kosten sehr gering.

---

## KI-Proxy

Die App kennt **keinen** Anbieter und **kein** Modell. Sie schickt einen
Aufgabentyp und Kontext:

```json
POST /functions/v1/ai-proxy
Authorization: Bearer <supabase-jwt>

{
  "task": "task.split",
  "input": "Ich muss meinen Umzug organisieren.",
  "tone": "locker"
}
```

```json
{ "text": "Kartons besorgen\nKündigung schreiben\n..." }
```

Bekannte Aufgaben (siehe [prompts.ts](../supabase/functions/ai-proxy/prompts.ts)):

| `task` | Feature |
|---|---|
| `task.split` | Aufgabe sortieren – Zerlegung in Mikroschritte |
| `message.compose` | Nachricht schreiben – Text formulieren |
| `call.prepare` | Anruf erledigen – Ziel, Ansprechpartner, Stichpunkte |
| `appointment.route` | Termin klären – Buchungsweg vorschlagen |
| `help.ask` | Hilfe-Bereich – freie Frage, wenn der Katalog nichts hergibt |

**Ein Anbieterwechsel ist eine Änderung an dieser Funktion, nie an der App.**
Ein neuer Anbieter braucht nur eine weitere `callX()`-Funktion und einen Zweig
in der Weiche.

In der App taucht die KI an genau vier Stellen auf, jeweils als Knopf mit
Vorschlagsliste: neue Aufgabe (Mikroschritte), Nachricht formulieren, Anruf
vorbereiten, Buchungsweg. Übernommen wird nur, was der User antippt. Ist die
KI aus oder nicht erreichbar, verschwindet der Knopf – der Ablauf bleibt
vollständig.

---

## Konto löschen

```json
POST /functions/v1/delete-account
Authorization: Bearer <supabase-jwt>
```

```json
{ "deleted": true, "emailed": true }
```

Wer gelöscht wird, entscheidet **ausschließlich das Token** – nie eine Id aus
dem Body. Die Funktion räumt in dieser Reihenfolge auf:
`recovery_codes` → `profiles` → `auth.users`. Danach geht, sofern SMTP
eingerichtet ist, eine Bestätigung an die hinterlegte Adresse.

Der Service-Role-Schlüssel liegt ausschließlich in dieser Funktion. Die App
kennt ihn nicht und darf ihn nie kennen.

---

## Sicherheit

- `verify_jwt = true` — kein KI-Aufruf und kein Löschen ohne angemeldeten
  Nutzer
- Row Level Security auf allen Tabellen, jeder sieht nur seine eigenen Zeilen
- API-Schlüssel liegen ausschließlich in Supabase-Secrets, nie in der App
- Wiederherstellungs-Codes werden nur als Hash gespeichert
- Zwei-Faktor über TOTP, freiwillig – die App weist einmal darauf hin und
  danach nie wieder

---

## Offen

- Wiederherstellungs-Codes ausgeben und einlösen (Tabelle steht, Ablauf fehlt)
- Eigener Absender für die Löschbestätigung statt eines geliehenen Postfachs
