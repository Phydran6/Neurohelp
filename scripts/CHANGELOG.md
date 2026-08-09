# Änderungen in scripts/

Verbindlich fürs Release ist die [große CHANGELOG.md](../CHANGELOG.md).

## [Unreleased]

## [0.1.0-alpha.2] - 2026-08-09

- `README.md` für diesen Bereich angelegt

## [0.1.0-alpha.1] - 2026-08-09

- `extract_changelog.sh` kommt mit Vorabversionen wie `0.1.0-alpha.1` zurecht
- `ensure_platforms.sh` wird in allen drei Workflows vor `flutter pub get`
  ausgeführt, weil die Plugin-Registrierung sonst fehlt
- `bootstrap.sh` und `bootstrap.ps1` für die Ersteinrichtung
