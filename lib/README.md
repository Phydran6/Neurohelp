# lib/ – der Code der App

Aller Dart-Code. Was hier drin steht, läuft auf dem Gerät.

[← Technische Doku](../docs/TECHNIK.md) · [Änderungen](CHANGELOG.md)

---

## Aufbau

| Ordner | Was da rein gehört |
|---|---|
| `main.dart` | Einstiegspunkt. Öffnet die Datenbank, verdrahtet die Dienste |
| [`app/`](app/) | App-Wurzel, `MaterialApp`, die Weiche zwischen Onboarding, Sperre und Start |
| [`core/`](core/) | Querschnitt – alles, was mehr als ein Feature braucht |
| [`features/`](features/) | Ein Ordner pro Feature |
| [`shared/`](shared/) | Widgets, die mehrere Features benutzen |

---

## core/

| Ordner | Inhalt |
|---|---|
| `account/` | Konto, dahinter Supabase Auth |
| `ai/` | KI-Schnittstelle. Kennt Aufgabentypen, **keinen** Anbieter |
| `calendar/` | Kalender-Einträge und ICS |
| `companion/` | Darstellung der Anrufbegleitung |
| `config/` | Build-Flavors und `--dart-define`-Werte |
| `db/` | SQLite: Schema, Migrationen, Zugang |
| `di/` | `AppServices` und `AppScope` – die einzige Verdrahtung |
| `history/` | Historie: das Rückgrat der App |
| `logging/` | Log-Schicht. `print` ist verboten |
| `security/` | App-Sperre, PIN-Ablage |
| `settings/` | Tonfall, KI-Toggle, Art der Sperre |
| `theme/` | Farben, Typografie, Hell und Dunkel |

## features/

Jedes Feature hat denselben Schnitt:

```
features/<name>/
├─ data/           Repositories, Datenquellen
├─ domain/         Modelle und Logik – ohne Flutter-Abhängigkeit
└─ presentation/   Seiten, Widgets, Zustand
```

Vorhanden: `appointments`, `calls`, `help`, `home`, `messages`, `onboarding`,
`security`, `settings`, `tasks`.

---

## Regeln in diesem Bereich

- **`domain/` kennt kein Flutter.** Reine Logik, direkt testbar
- **`presentation/` greift nie direkt auf die Datenbank zu** – immer über ein
  Repository aus `data/`
- **Features kennen sich nicht gegenseitig.** Gemeinsames wandert nach `core/`
  oder `shared/`
- **Jede Schreiboperation landet in der Historie.** Ohne Ausnahme
- **Kein `print`** – ausschließlich `AppLogger`
- **Kein `CircularProgressIndicator`** für lokale Ladevorgänge: Er flackert nur
  und bringt `pumpAndSettle` in Widget-Tests zum Hängen
- Deutsche Kommentare, englische Bezeichner

---

## Neues Feature anlegen

1. `lib/features/<name>/` mit `data/`, `domain/`, `presentation/`
2. In `domain/` anfangen – die Logik ohne UI
3. Dienst in [`core/di/app_services.dart`](core/di/app_services.dart) eintragen
4. Tests unter [`test/`](../test/), Logik als Unit-, Ablauf als Widget-Test
5. Eintrag in die [CHANGELOG.md](../CHANGELOG.md)
