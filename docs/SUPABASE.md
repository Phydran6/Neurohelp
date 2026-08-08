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
├─ migrations/                Schema, append-only
│  └─ 20260808120000_init.sql  Profile, Wiederherstellungs-Codes, RLS
└─ functions/
   ├─ _shared/cors.ts
   └─ ai-proxy/               Anbieteragnostischer KI-Proxy
      ├─ index.ts
      └─ prompts.ts           Prompt-Register (ohne App-Update änderbar)
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

**Ein Anbieterwechsel ist eine Änderung an dieser Funktion, nie an der App.**
Ein neuer Anbieter braucht nur eine weitere `callX()`-Funktion und einen Zweig
in der Weiche.

---

## Sicherheit

- `verify_jwt = true` — kein KI-Aufruf ohne angemeldeten Nutzer
- Row Level Security auf allen Tabellen, jeder sieht nur seine eigenen Zeilen
- API-Schlüssel liegen ausschließlich in Supabase-Secrets, nie in der App
- Wiederherstellungs-Codes werden nur als Hash gespeichert

---

## Offen (Phase 4 der Bau-Reihenfolge)

- Supabase-Projekt anlegen und `supabase db push` ausführen
- Mail-Vorlagen für Reset-Mails auf den Ton der App anpassen
- Anbindung in der App (`supabase_flutter`) zusammen mit dem Onboarding
