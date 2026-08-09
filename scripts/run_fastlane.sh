#!/usr/bin/env bash
# Ruft eine fastlane-Lane auf und macht den Fehlerfall lesbar.
#
# Hintergrund: Die Protokolle eines Actions-Laufs sind nur nach Anmeldung
# einsehbar - Annotationen dagegen stehen auf der Zusammenfassungsseite und
# sind auch ohne Konto lesbar. Deshalb wird die Ausgabe mitgeschrieben und bei
# einem Fehler als Annotation zusammengefasst, mit einer Deutung in Klartext.
#
# Aufruf:
#   bash scripts/run_fastlane.sh beta version:0.1.0 build_number:42
#
# Secret-Werte maskiert GitHub in Annotationen genauso wie im Protokoll.
set -uo pipefail

cd "$(dirname "$0")/../ios" || exit 1

log="$(mktemp)"

# Mit Gemfile.lock ueber bundler, damit die Version festgenagelt ist. Ohne
# Lock-Datei direkt - `bundle exec` waere dann nur eine zusaetzliche
# Fehlerquelle.
if [ -f Gemfile.lock ]; then
  runner=(bundle exec fastlane)
else
  runner=(fastlane)
fi

if "${runner[@]}" "$@" 2>&1 | tee "$log"; then
  echo "fastlane $1 ist durchgelaufen."
  exit 0
fi

echo "::group::Deutung des Fehlers"

deutung=""
add() { deutung="${deutung}${deutung:+ | }$1"; }

grep -qi "Invalid password passed via 'MATCH_PASSWORD'\|Could not decrypt\|bad decrypt" "$log" \
  && add "MATCH_PASSWORD passt nicht zu den Dateien im Zertifikats-Repository. Das Passwort muss genau das von der Erstellung sein. Ist es nicht mehr bekannt: Zertifikats-Repository leeren und den Ablauf 'iOS Signatur einrichten' erneut starten."

grep -qi "Could not create keychain\|SecKeychain\|keychain.*locked\|Failed to unlock" "$log" \
  && add "Der Schluesselbund auf dem Runner liess sich nicht nutzen. Dafuer ist setup_ci zustaendig - pruefen, ob es im Fastfile vor match laeuft."

grep -qi "No matching provisioning profiles\|Provisioning profile .* doesn't\|doesn't match the bundle identifier\|No profiles for" "$log" \
  && add "Profil und Bundle-ID passen nicht zusammen. Erwartet wird 'match AppStore will.neurohelp.help'."

grep -qi "No development certificates available\|no local code signing identities\|No signing certificate" "$log" \
  && add "Xcode sucht ein ENTWICKLER-Zertifikat, wir haben ein Verteilungs-Zertifikat. Das Projekt muss auf manuelle Signatur mit dem match-Profil stehen - dafuer ist update_code_signing_settings im Fastfile zustaendig."

grep -qi "No suitable application records\|Could not find app with bundle" "$log" \
  && add "Apple findet keine App zu dieser Bundle-ID. In App Store Connect muss ein Datensatz mit will.neurohelp.help existieren."

grep -qi "Authentication credentials are missing or invalid\|401 Unauthorized\|Invalid JWT\|NOT_AUTHORIZED" "$log" \
  && add "Der App-Store-Connect-API-Key wird abgelehnt. Key-ID, Issuer-ID oder der base64-Inhalt der .p8 stimmen nicht - oder der Key hat nicht mindestens die Rolle App Manager."

grep -qi "already been used\|The bundle version must be higher\|redundant.*version" "$log" \
  && add "Diese Build-Nummer gibt es bei Apple schon. Ein neuer Lauf zaehlt sie hoch - einfach erneut starten."

if grep -oiE "ITMS-[0-9]{4,5}" "$log" | sort -u | head -3 | grep -q .; then
  codes=$(grep -oiE "ITMS-[0-9]{4,5}" "$log" | sort -u | tr '\n' ' ')
  add "Apple hat den Upload abgelehnt: $codes"
fi

grep -qi "Gem::\|Bundler::\|Could not find gem\|bundle install.*failed" "$log" \
  && add "Ruby- oder Bundler-Problem, kein Apple-Problem. Vermutlich fehlt eine Gemfile.lock oder eine Abhaengigkeit passt nicht."

[ -n "$deutung" ] || deutung="Keine bekannte Ursache erkannt. Die letzten Zeilen stehen unten."

echo "$deutung"
echo "::endgroup::"

echo "::error::fastlane $1 gescheitert - $deutung"

# Die letzten Zeilen als eigene Annotation, damit man sie ohne Anmeldung liest.
# %0A ist der Zeilenumbruch in Annotationen; dieselbe Technik nutzt ci.yml.
tail -n 25 "$log" \
  | sed -e 's/%/%25/g' -e 's/\r/ /g' \
  | sed -z 's/\n/%0A/g' \
  | { read -r block; echo "::error::Letzte Zeilen:%0A$block"; }

exit 1
