# supabase/ – das Backend

Deckt genau drei Dinge ab. Mehr gehört nicht hierher.

[← Technische Doku](../docs/TECHNIK.md) ·
[Einrichtung: BACKEND.md](../docs/BACKEND.md) ·
[Änderungen](CHANGELOG.md)

---

| Funktion | Warum zentral |
|---|---|
| Konten und Anmeldung | braucht eine zentrale Instanz |
| Reset-Mails | braucht einen vertrauenswürdigen Absender |
| KI-Proxy | die App darf nie direkt mit einem KI-Anbieter reden |

**Alles andere bleibt auf dem Gerät.** Die Migration enthält bewusst **keine**
Tabellen für Historie, Aufgaben, Nachrichten oder Kontakte. Wer sie hier
ergänzt, bricht das Kernversprechen der App.

---

## Aufbau

| Pfad | Inhalt |
|---|---|
| `config.toml` | Lokale Entwicklungsumgebung |
| `migrations/` | Schema, **append-only** – nie eine bestehende Datei ändern |
| `functions/ai-proxy/` | Der anbieteragnostische KI-Proxy |
| `functions/ai-proxy/prompts.ts` | Prompt-Register, ohne App-Update änderbar |
| `functions/_shared/` | Gemeinsames für alle Funktionen |

---

## Der KI-Proxy

Die App schickt einen **Aufgabentyp**, keinen Modellnamen:

```json
POST /functions/v1/ai-proxy

{ "task": "task.split", "input": "Ich muss meinen Umzug organisieren.", "tone": "locker" }
```

```json
{ "text": "Kartons besorgen\nKündigung schreiben\n..." }
```

| `task` | Feature |
|---|---|
| `task.split` | Aufgabe sortieren |
| `message.compose` | Nachricht schreiben |
| `call.prepare` | Anruf erledigen |
| `appointment.route` | Termin klären |
| `help.ask` | Freie Frage zur App |

**Ein Anbieterwechsel ist eine Änderung an dieser Funktion, nie an der App.**
Ein neuer Anbieter braucht eine weitere `callX()`-Funktion und einen Zweig in
der Weiche – sonst nichts.

---

## Befehle

Hochladen:

```bash
supabase functions deploy ai-proxy --project-ref <ref>
```

Schema einspielen:

```bash
supabase db push
```

Lokal ausprobieren (braucht Docker):

```bash
supabase start
```

---

## Sicherheit

- `verify_jwt = true` – kein KI-Aufruf ohne angemeldeten Nutzer
- Row Level Security auf allen Tabellen, jeder sieht nur seine Zeilen
- API-Schlüssel liegen ausschließlich in Supabase-Secrets, nie in der App
- Wiederherstellungs-Codes werden nur als Hash gespeichert
