# scripts/ – Hilfsskripte

Vier Skripte, keins davon braucht man im Alltag.

[← Technische Doku](../docs/TECHNIK.md) · [Änderungen](CHANGELOG.md)

---

| Skript | Wozu | Wer ruft es auf |
|---|---|---|
| `bootstrap.sh` | Erstaufsetzen auf macOS / Linux | Mensch, einmalig |
| `bootstrap.ps1` | Dasselbe für Windows | Mensch, einmalig |
| `ensure_platforms.sh` | Legt `android/` und `ios/` an, falls sie fehlen | CI, vor jedem Build |
| `extract_changelog.sh` | Schneidet einen Versionsabschnitt aus `CHANGELOG.md` | `release.yml` |

---

## Hinweise

**`ensure_platforms.sh` ist meistens ein No-Op.** `android/` und `ios/` liegen
im Repository. Das Skript greift nur, wenn sie fehlen.

**Danach immer erneut `flutter pub get`.** Die Registrierung der Plugins
entsteht erst, wenn die Plattform-Ordner existieren. Ohne den zweiten Aufruf
scheitert der Build.

**`extract_changelog.sh` prüfen, bevor getaggt wird:**

```bash
bash scripts/extract_changelog.sh 0.1.0-alpha.2
```

Findet es nichts, bekommt das Release einen Platzhalter statt der Notizen.
