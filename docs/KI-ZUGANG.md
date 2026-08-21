# KI-Zugang über OpenRouter

Umsetzung von [Abschnitt 17a des Konzepts](KONZEPT.md). Dieses Dokument beschreibt das *Wie*,
das Konzept das *Was* und *Warum*.

**Stand: gebaut.** Die Endpunkte unten wurden gegen <https://openrouter.ai/docs> geprüft.

---

## Warum überhaupt OpenRouter

Der User soll KI nutzen können, **ohne** dass Kosten beim Betreiber entstehen und **ohne**
dass er administrative Arbeit leisten muss. Beides gleichzeitig ging lange nicht:

| Weg | Warum verworfen |
|---|---|
| Login mit dem ChatGPT-/Claude-Abo des Users | Existiert nicht. Chat-Abos sind kein API-Zugang. „Sign in with ChatGPT" ist ein reiner Identitäts-Login – Name, E-Mail, Bild. Kein Verbrauchsrecht |
| Ein eigener API-Schlüssel für alle | Kosten skalieren mit jedem Nutzer |
| In-App-Abo | Verlangt Auszahlungs- und Steuerkonfiguration, faktisch Gewerbeanmeldung. Bewusst abgelehnt |
| Nur BYOK | Bricht das DAU-Prinzip. Genau der Admin-Kram, an dem die Zielgruppe scheitert |

OpenRouter hat einen **offiziellen OAuth-Login nach PKCE**: Die App schickt den User zum
Login, bekommt einen Code zurück und tauscht ihn gegen einen **nutzereigenen** API-Schlüssel.
Für den User fühlt sich das an wie „mit Konto anmelden". Er sieht nie einen Schlüssel und
kopiert nichts – das ist der ganze Unterschied zu klassischem BYOK.

---

## Die drei Stufen

```
AiClient (Schnittstelle – die einzige, die Features kennen)
 └── LayeredAiClient          lib/core/ai/data/layered_ai_client.dart
      ├── OpenRouterAiClient  direkt vom Gerät   [wenn verbunden]
      └── SupabaseAiClient    über das Backend   [Standard]
```

| Stufe | Wer zahlt | Aufwand für den User | Rolle |
|---|---|---|---|
| Eigene gehostete KI | niemand | keiner – läuft sofort | Standard |
| OpenRouter-Login | der User (kostenlose Modelle) | ein Tap | Angebot für bessere Qualität |
| Eigener Schlüssel (BYOK) | der User | Schlüssel eintragen | versteckt in den Einstellungen |

**Fehler fallen weich.** Fällt eine Stufe aus – Ratenlimit, Modell verschwunden, kein Netz
zum eigenen Server – geht es stillschweigend eine Stufe tiefer. Der User sieht nie eine
technische Fehlermeldung; bleibt gar nichts übrig, geht der Ablauf seinen lokalen Weg.

### Die Proxy-Regel, differenziert

- **Eigene gehostete KI → über das Backend.** Grund: Schutz der eigenen Infrastruktur und
  des dort liegenden Schlüssels.
- **Nutzereigener Zugang → direkt vom Gerät.** Ein Proxy hätte hier keinen Zweck und wäre
  nur eine zusätzliche Station, auf der fremde Daten landen. Direkt ist konsequenter
  Lokal-First.

---

## Der Login (PKCE)

| Schritt | Wo im Code |
|---|---|
| 1. Verifier und Challenge erzeugen | [`pkce.dart`](../lib/core/ai/openrouter/pkce.dart) |
| 2. Browser öffnen, Rücksprung abfangen | [`openrouter_login.dart`](../lib/core/ai/openrouter/openrouter_login.dart) |
| 3. Code aus der Rücksprung-URL lesen | [`openrouter_account.dart`](../lib/core/ai/openrouter/openrouter_account.dart) |
| 4. Code gegen Schlüssel tauschen | [`openrouter_api.dart`](../lib/core/ai/openrouter/openrouter_api.dart) |
| 5. Verschlüsselt ablegen | [`openrouter_key_store.dart`](../lib/core/ai/openrouter/openrouter_key_store.dart) |

```
GET  https://openrouter.ai/auth?callback_url=…&code_challenge=…&code_challenge_method=S256
POST https://openrouter.ai/api/v1/auth/keys      → { "key": "sk-or-…" }
GET  https://openrouter.ai/api/v1/models         → Verzeichnis, zur Laufzeit
GET  https://openrouter.ai/api/v1/key            → Guthaben und Gültigkeit
POST https://openrouter.ai/api/v1/chat/completions
```

Der Verifier bleibt in der App und steht nie in einer URL. Ohne PKCE könnte eine fremde App,
die dasselbe URL-Schema beansprucht, den Code abfangen und einlösen.

Das Anfrageformat entspricht dem OpenAI-Chat-Completions-Schema – ein Anbieterwechsel bleibt
dadurch später überschaubar.

### Deep Link

Rücksprung über das Custom Scheme **`neurohelp://openrouter`**:

- **Android:** eigene `CallbackActivity` in `android/app/src/main/AndroidManifest.xml`
- **iOS:** zweiter Eintrag unter `CFBundleURLTypes` in `ios/Runner/Info.plist`

Beides steht neben dem bestehenden Schema `will.neurohelp.help`, über das der Rückweg aus
Bestätigungs- und Reset-Mails läuft. Custom Scheme statt App Link / Universal Link ist eine
bewusste Abkürzung für die Alpha: App Links wären sauberer, brauchen aber eine Domain mit
hinterlegter Datei. [`openrouter_deep_link_test.dart`](../test/unit/openrouter_deep_link_test.dart)
hält beide Plattformdateien und den Code im Gleichschritt – lokal wird nicht gebaut, ein
falsches Schema würde sonst erst auf einem echten Gerät auffallen.

### Wo der Schlüssel liegt

Verschlüsselt im sicheren Speicher des Geräts (Android Keystore, iOS Keychain über
`flutter_secure_storage`). **Nie im Backend, nie in der SQLite-Datenbank, nie im Klartext
auf dem Bildschirm** – angezeigt werden höchstens die letzten vier Zeichen. Beim Löschen des
Kontos wird er mit weggeräumt.

---

## Modellwahl zur Laufzeit

**Merksatz: kein Modell wird fest verdrahtet.** Die Liste der kostenlosen Modelle rotiert;
ein eingebauter Name wäre irgendwann tot, und die App wüsste es nicht. Deshalb holt sie das
Verzeichnis (`GET /models`) und wählt selbst –
[`openrouter_model_choice.dart`](../lib/core/ai/openrouter/openrouter_model_choice.dart):

1. Nur Modelle, die Text hereinnehmen und Text herausgeben
2. Ohne Klassifizierer, Einbettungen, Umsortierer, Sprachausgabe – die stehen in derselben
   Liste und würden sonst mitausgewählt
3. Nur kostenlose, solange der User bei OpenRouter kein Guthaben aufgeladen hat
4. Sortiert nach Kontextlänge; sehr kleine Modelle rutschen ans Ende
5. Die besten vier werden als Kandidaten behalten

Bei einer Anfrage wird der erste Kandidat gefragt. Antwortet er nicht – Ratenlimit,
verschwunden, abgelehnt – geht es still zum nächsten. Das Verzeichnis gilt sechs Stunden und
wird sofort ungültig, wenn ein Modell nicht mehr existiert.

**Der User wählt nie ein Modell** und erfährt auch nicht, welches geantwortet hat.

### Kostenpflichtige Modelle

Nur wenn `GET /key` meldet, dass der User schon einmal Guthaben aufgeladen hat
(`is_free_tier: false`). Ungefragt Geld ausgeben tut die App nicht, und auch dann kommen
kostenlose Modelle zuerst. Ein Modell ohne Preisangabe wird ausgelassen.

---

## Die Prompts – der eine unschöne Punkt

Normalerweise liegen die Prompts im Backend
([`supabase/functions/ai-proxy/prompts.ts`](../supabase/functions/ai-proxy/prompts.ts)) und
sind dort ohne App-Update änderbar. Beim direkten Weg muss die App selbst wissen, was sie
fragen will – also gibt es sie ein zweites Mal in
[`ai_prompts.dart`](../lib/core/ai/ai_prompts.dart).

**Wer dort etwas ändert, ändert es hier mit.** Sonst antwortet die App je nach Stufe
unterschiedlich, und niemand versteht warum.
[`ai_prompts_test.dart`](../test/unit/ai_prompts_test.dart) prüft wenigstens, dass beide
Seiten dieselben Aufgabentypen kennen.

---

## Ratenlimits

Für `:free`-Modelle, Stand August 2026 – ändert sich regelmäßig, vor Annahmen nachschlagen:

| Konto | Pro Minute | Pro Tag |
|---|---|---|
| ohne je aufgeladenes Guthaben | ~20 | ~50 |
| ab 10 $ aufgeladenem Guthaben | ~20 | ~1000 |

50 Anfragen am Tag klingen wenig, reichen für die Nutzung von Neurohelp aber gut aus – die
KI wird pro Ablauf einmal gefragt, nicht laufend. Wird es doch eng, fällt die App auf die
eigene gehostete Stufe zurück, ohne dass der User etwas merkt.

---

## Datenschutz

Anfragen laufen über OpenRouter **und** den dahinterliegenden Modellanbieter. Bei
kostenlosen Modellen ist Training mit den Daten häufig erlaubt. Das steht deshalb sichtbar
im Angebot in den Einstellungen, nicht im Kleingedruckten – in Neurohelp geht es oft um
Arzt- und Kassenthemen. Siehe [DATENSCHUTZ.md](DATENSCHUTZ.md).

---

## Was ein abgelaufener Zugang macht

Weist OpenRouter den Schlüssel zurück (HTTP 401), merkt die App sich das
(`OpenRouterAccount.needsReconnect`), benutzt diese Stufe nicht weiter und fällt auf die
Standardstufe zurück. Der Schlüssel bleibt liegen – ihn stillschweigend wegzuwerfen wäre die
schlechtere Überraschung. In den Einstellungen steht dann ein ruhiger Satz und ein Knopf
„Neu verbinden".

---

## Was das kostet

| Posten | Kosten für den Betreiber |
|---|---|
| KI über OpenRouter | **0 €**, unabhängig von der Nutzerzahl |
| Gewerbe / Steuer | nicht nötig – es fließt kein Geld über den Betreiber |
| In-App-Kauf | entfällt – keine Store-Provision, kein Abo-Verkauf |

Will ein User mehr Qualität, lädt er bei OpenRouter selbst auf – komplett am Betreiber vorbei.

---

## Offen

- [ ] App Link / Universal Link statt Custom Scheme, sobald eine Domain dafür da ist
- [ ] Prüfen, welche der kostenlosen Modelle für die einzelnen Aufgaben wirklich taugen.
      Kleine Modelle reichen für Formulierungen, fürs Ableiten von Ziel und Ansprechpartner
      eher nicht. Bisher entscheidet nur die grobe Rangfolge oben
