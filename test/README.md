# test/ – Unit- und Widget-Tests

Aktuell **149 Tests**, alle grün. Die CI lässt keinen roten Stand durch.

[← Technische Doku](../docs/TECHNIK.md) · [Änderungen](CHANGELOG.md)

---

## Aufteilung

| Ordner | Was geprüft wird |
|---|---|
| [`unit/`](unit/) | Logik ohne UI: Repositories, Abläufe, Regeln |
| [`widget/`](widget/) | Ganze Bedienpfade, so wie ein Mensch sie geht |
| [`../integration_test/`](../integration_test/) | End-to-End auf Gerät oder Emulator |

Ausführen:

```bash
flutter test
```

```bash
flutter test --coverage
```

---

## Was hier auch geprüft wird

Nicht nur, ob etwas funktioniert – auch, ob es sich richtig anfühlt. Einige
Tests prüfen bewusst die Haltung der App:

- `greetings_test.dart` verbietet Wörter wie `musst`, `solltest`, `endlich`,
  `schaffst du`, `streak`, `gut gemacht`
- `onboarding_lock_test.dart` prüft, dass der KI-Toggle zwei **gleichwertige**
  Knöpfe hat, ohne Voreinstellung
- `onboarding_flow_test.dart` prüft, dass sich Pflichtschritte nicht
  stillschweigend überspringen lassen
- `supabase_backend_test.dart` prüft, dass Fehlermeldungen ruhig klingen und
  keine technische Kette durchreichen

---

## Vier Fallen bei Tests mit Datenbank

Alle schon getreten, alle behoben:

1. **`databaseFactoryFfiNoIsolate` statt `databaseFactoryFfi`.** In
   Widget-Tests läuft die Zeit simuliert; ein Future über eine Isolate-Grenze
   wird dort nie eingelöst.
2. **Nach einem Seitenwechsel `pumpAndSettle`, bevor getippt wird.** Ein Widget
   ist schon da, während es noch hereingeschoben wird – ein Tap trifft daneben,
   ohne dass der Test es merkt.
3. **Nicht auf `find.text` warten, wenn derselbe Text im Eingabefeld steht.**
   Sonst ist der Test grün, obwohl nichts passiert ist. Auf Schlüssel warten.
4. **`pumpAndSettle` wartet auf Animationen, nicht auf Futures.**

Dazu: Tests, die von der Tageszeit abhängen, bekommen über
`AppServices.from(clock: …)` eine feste Uhr.
