# Änderungen in lib/

Nur was den App-Code betrifft. Verbindlich fürs Release ist die
[große CHANGELOG.md](../CHANGELOG.md).

## [Unreleased]

## [0.1.0-alpha.2] - 2026-08-09

- `README.md` für diesen Bereich angelegt
- Verweis auf die umbenannte Backend-Doku korrigiert

## [0.1.0-alpha.1] - 2026-08-09

- `main.dart` verbindet die App mit Supabase; ohne Backend läuft alles lokal
  weiter
- `core/account/data/supabase_account_repository.dart`: Registrierung,
  Anmeldung, Reset-Mail
- `core/ai/data/supabase_ai_client.dart`: KI-Zugang über die Edge Function
- `core/config/app_config.dart` kennt jetzt Projekt-URL und öffentlichen
  Schlüssel
- `features/onboarding/` und `features/security/`: Onboarding und App-Sperre
- Alle fünf Feature-Pfade vollständig: Aufgaben, Nachrichten, Anrufe, Termine,
  Hilfe
- `core/history/`: Historie als Rückgrat, jede Schreiboperation protokolliert
- `core/db/`: SQLite-Schema mit versionierten Migrationen
