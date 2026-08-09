# Änderungen in test/

Verbindlich fürs Release ist die [große CHANGELOG.md](../CHANGELOG.md).

## [Unreleased]

## [0.1.0-alpha.2] - 2026-08-09

- `README.md` für diesen Bereich angelegt

## [0.1.0-alpha.1] - 2026-08-09

- `unit/supabase_backend_test.dart`: Eingabeprüfung und ruhige Fehlermeldungen
  der Konto-Verwaltung, KI-Client im ausgeschalteten Zustand
- `unit/app_config_test.dart` prüft, dass das Backend voreingestellt ist und
  dort nur der öffentliche Schlüssel steht
- `widget/onboarding_lock_test.dart`: Onboarding-Durchlauf und App-Sperre
- `widget/start_page_test.dart` an die neue Einstiegs-Weiche angepasst
- Widget-Tests für alle vier Feature-Pfade
- Unit-Tests für Historie, Einstellungen, Aufgaben, Nachrichten, Anrufe,
  Termine, PIN-Ablage, Hilfe
