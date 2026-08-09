# Änderungen in supabase/

Verbindlich fürs Release ist die [große CHANGELOG.md](../CHANGELOG.md).

## [Unreleased]

## [0.1.0-alpha.2] - 2026-08-09

- `README.md` für diesen Bereich angelegt

## [0.1.0-alpha.1] - 2026-08-09

- **Live geschaltet:** Schema eingespielt, `ai-proxy` hochgeladen, Secrets
  gesetzt (`ANTHROPIC_API_KEY`, `AI_PROVIDER`, `ANTHROPIC_MODEL`)
- `config.toml`: veralteter Abschnitt `[inbucket]` → `[local_smtp]`
- `migrations/20260808120000_init.sql`: Profile und Wiederherstellungs-Codes
  mit Row Level Security, bewusst ohne Tabellen für Nutzerinhalte
- `functions/ai-proxy/`: anbieteragnostischer Proxy für Claude und OpenAI,
  Prompts im Backend
