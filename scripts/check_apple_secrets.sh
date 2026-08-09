#!/usr/bin/env bash
# Prueft, ob die Apple-Secrets vollstaendig sind, und sagt welches fehlt.
#
# Ohne diese Pruefung scheitern die iOS-Laeufe erst tief in fastlane, mit
# Meldungen, in denen der eigentliche Grund nicht vorkommt: Fehlt der
# Git-Token, fragt git nach einem Passwort und bricht mit
# "could not read Password" ab - das klingt nach MATCH_PASSWORD, ist aber
# etwas voellig anderes.
#
# Aufruf:
#   bash scripts/check_apple_secrets.sh           # fehlend = Fehler
#   bash scripts/check_apple_secrets.sh --soft    # fehlend = nur Hinweis
#
# Die Werte selbst werden nie ausgegeben, nur ob sie gesetzt sind.
set -uo pipefail

soft=0
[ "${1:-}" = "--soft" ] && soft=1

required=(
  APPSTORE_API_KEY_ID
  APPSTORE_API_ISSUER_ID
  APPSTORE_API_PRIVATE_KEY
  MATCH_PASSWORD
  MATCH_GIT_URL
  MATCH_GIT_TOKEN
)

missing=""
for name in "${required[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing="$missing $name"
    echo "FEHLT    $name"
  else
    echo "gesetzt  $name"
  fi
done

# Der base64-Schluessel ist die haeufigste stille Fehlerquelle: Wer die .p8
# direkt einfuegt statt sie zu kodieren, merkt es erst beim Anmelden.
if [ -n "${APPSTORE_API_PRIVATE_KEY:-}" ]; then
  case "$APPSTORE_API_PRIVATE_KEY" in
    LS0tLS1CRUdJ*)
      echo "         APPSTORE_API_PRIVATE_KEY sieht nach base64 aus - gut" ;;
    *-----BEGIN*)
      echo "::error::APPSTORE_API_PRIVATE_KEY ist der rohe Inhalt der .p8. Er muss base64-kodiert sein."
      missing="$missing APPSTORE_API_PRIVATE_KEY(nicht-base64)" ;;
    *)
      echo "::warning::APPSTORE_API_PRIVATE_KEY beginnt unerwartet. Erwartet wird base64, das mit LS0tLS1CRUdJ anfaengt." ;;
  esac
fi

if [ -n "$missing" ]; then
  if [ "$soft" = "1" ]; then
    echo "::warning::Unvollstaendig, iOS wird uebersprungen:$missing"
    exit 1
  fi
  echo "::error::Diese Secrets fehlen oder sind falsch:$missing"
  echo "Nachtragen unter Settings -> Secrets and variables -> Actions."
  exit 1
fi

echo "Alle sechs Apple-Secrets sind gesetzt."
