#!/usr/bin/env bash
# Schneidet den Abschnitt einer Version aus CHANGELOG.md heraus.
# Nutzung: scripts/extract_changelog.sh 0.1.0
set -euo pipefail

VERSION="${1:?Version angeben, z.B. 0.1.0}"
CHANGELOG="${2:-CHANGELOG.md}"

notes="$(
  awk -v ver="$VERSION" '
    $0 ~ "^## \\[" ver "\\]" { inside = 1; next }
    inside && /^## \[/       { exit }
    inside                   { print }
  ' "$CHANGELOG"
)"

# Führende/abschließende Leerzeilen entfernen
notes="$(printf '%s\n' "$notes" | sed -e '/./,$!d' | tac | sed -e '/./,$!d' | tac)"

if [ -z "$notes" ]; then
  echo "Keine Changelog-Einträge für Version ${VERSION} gefunden."
  echo ""
  echo "Vollständige Historie: CHANGELOG.md"
else
  printf '%s\n' "$notes"
fi
