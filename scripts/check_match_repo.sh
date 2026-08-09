#!/usr/bin/env bash
# Prueft den Zugriff auf das Zertifikats-Repository und sagt, WORAN es liegt.
#
# `git ls-remote` liefert bei jedem Problem fast dieselbe Meldung, und
# GitHub-Actions maskiert Secrets in der Ausgabe - man sieht also nicht einmal,
# welche URL versucht wurde. Dieses Skript prueft die Ursachen deshalb einzeln
# und gibt nur Aussagen aus, keine Werte.
#
# Erwartet MATCH_GIT_URL und MATCH_GIT_TOKEN in der Umgebung.
set -uo pipefail

fail() {
  echo "::error::$1"
  exit 1
}

url="${MATCH_GIT_URL:-}"
token="${MATCH_GIT_TOKEN:-}"

[ -n "$url" ] || fail "MATCH_GIT_URL ist nicht gesetzt."
[ -n "$token" ] || fail "MATCH_GIT_TOKEN ist nicht gesetzt."

echo "== Form der URL =="

# Leerzeichen und Zeilenumbrueche sind der Klassiker beim Einfuegen in das
# Secret-Feld. Sie sind unsichtbar und machen die URL unbrauchbar.
clean="${url//[$'\t\r\n ']/}"
if [ "$clean" != "$url" ]; then
  fail "MATCH_GIT_URL enthaelt Leerzeichen oder einen Zeilenumbruch. Secret neu eintragen, ohne abschliessenden Umbruch."
fi

case "$url" in
  https://github.com/*) echo "  beginnt mit https://github.com/  - gut" ;;
  git@github.com:*)     fail "MATCH_GIT_URL ist eine SSH-Adresse. In der CI wird HTTPS gebraucht: https://github.com/<Konto>/<Repo>.git" ;;
  http://*)             fail "MATCH_GIT_URL benutzt http statt https." ;;
  *)                    fail "MATCH_GIT_URL sieht nicht wie eine GitHub-HTTPS-Adresse aus. Erwartet: https://github.com/<Konto>/<Repo>.git" ;;
esac

# Konto und Repo herausloesen, um den Token gezielt zu testen.
path="${url#https://github.com/}"
path="${path%.git}"
path="${path%/}"
owner="${path%%/*}"
repo="${path##*/}"

if [ -z "$owner" ] || [ -z "$repo" ] || [ "$owner" = "$path" ]; then
  fail "Aus MATCH_GIT_URL laesst sich kein <Konto>/<Repo> lesen. Erwartet: https://github.com/<Konto>/<Repo>.git"
fi

echo "  Konto und Repo konnten gelesen werden"

echo "== Was der Token darf =="

code=$(curl -s -o /tmp/match_repo.json -w "%{http_code}" \
  -H "Authorization: Bearer $token" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$owner/$repo")

case "$code" in
  200)
    echo "  Der Token sieht das Repository (HTTP 200)."
    perms=$(tr ',' '\n' < /tmp/match_repo.json | grep -E '"(push|pull)":' | tr -d ' ')
    echo "  Rechte: $(echo "$perms" | tr '\n' ' ')"
    if echo "$perms" | grep -q '"push":false'; then
      fail "Der Token darf lesen, aber nicht schreiben. Unter Permissions -> Repository permissions -> Contents auf 'Read and write' stellen."
    fi
    ;;
  401)
    fail "Der Token wird abgelehnt (HTTP 401). Er ist abgelaufen, widerrufen oder beim Eintragen verstuemmelt worden. Neuen Token erzeugen." ;;
  403)
    fail "Der Token ist gueltig, darf aber nicht auf dieses Repository (HTTP 403). Bei einem fein abgestuften Token muss das Repository unter 'Only select repositories' ausgewaehlt sein." ;;
  404)
    fail "Der Token sieht dieses Repository nicht (HTTP 404). Entweder gibt es das Repository unter diesem Namen nicht - Tippfehler in MATCH_GIT_URL - oder beim Token wurde ein anderes Repository ausgewaehlt." ;;
  *)
    fail "Unerwartete Antwort von GitHub: HTTP $code" ;;
esac

echo "== Zugriff per git =="

git config --global url."https://x-access-token:$token@github.com/".insteadOf "https://github.com/"
export GIT_TERMINAL_PROMPT=0

# WICHTIG: ausserhalb des ausgecheckten Repositorys arbeiten.
#
# `actions/checkout` schreibt in dessen lokale Konfiguration
#   http.https://github.com/.extraheader = AUTHORIZATION: basic <GITHUB_TOKEN>
# Dieser Kopfzeilen-Eintrag gewinnt gegen Zugangsdaten in der URL. Innerhalb
# des Arbeitsverzeichnisses benutzt git also das Workflow-Token, und das darf
# nur in dieses eine Repository. GitHub antwortet dann mit "Repository not
# found", um die Existenz privater Repositories nicht zu verraten - man sucht
# daraufhin einen Tippfehler, den es nicht gibt.
#
# `match` selbst ist davon nicht betroffen: Es klont in ein temporaeres
# Verzeichnis, wo nur die globale Konfiguration greift.
work="$(mktemp -d)"
cd "$work" || fail "Temporaeres Verzeichnis nicht nutzbar."

if git ls-remote "$url" >/dev/null 2>err.txt; then
  echo "  git kommt hinein - alles in Ordnung."
else
  echo "  git scheitert, obwohl der Token das Repository sehen darf."
  if grep -qi "could not read Password\|Authentication failed" err.txt; then
    fail "git wurde die Anmeldung verweigert. Pruefe, ob MATCH_GIT_URL genau mit https://github.com/ beginnt."
  fi
  if grep -qi "not found\|does not exist" err.txt; then
    fail "git findet das Repository nicht, obwohl die API es sieht. Das deutet auf einen Tippfehler im Repo-Namen."
  fi
  fail "git ls-remote ist gescheitert. Ursache steht in der maskierten Ausgabe oben."
fi

echo "== Inhalt =="

if git clone --depth 1 --quiet "$url" klon 2>/dev/null; then
  if [ -z "$(ls -A klon 2>/dev/null | grep -v '^\.git$')" ]; then
    echo "  Repository ist leer - match legt Zertifikat und Profil neu an."
  else
    echo "  Es liegen schon Dateien darin:"
    find klon -type f -not -path '*/.git/*' | sed 's|^klon/|    |'
    echo "::warning::MATCH_PASSWORD muss dasselbe sein wie beim Anlegen dieser Dateien."
  fi
else
  echo "  Noch kein Klon moeglich - bei einem frisch erstellten, leeren Repository ist das normal."
fi

echo "Zugriff auf das Zertifikats-Repository ist in Ordnung."
