#!/usr/bin/env bash
# Stellt sicher, dass die von Flutter generierten Plattform-Ordner vorhanden sind.
#
# Solange android/ und ios/ noch nicht eingecheckt sind (Flutter SDK war beim
# Aufsetzen des Repos nicht verfügbar), erzeugt dieses Skript sie in der CI.
# Sobald sie einmal per scripts/bootstrap.* erzeugt und committet wurden,
# ist das Skript ein No-Op.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ -d android/app ] && [ -d ios/Runner ]; then
  echo "Plattform-Ordner sind vorhanden – nichts zu tun."
  exit 0
fi

echo "==> Plattform-Ordner werden erzeugt"
flutter create \
  --project-name neurohelp \
  --org de.phytech \
  --platforms android,ios \
  .

echo "==> Kuratierte Projektdateien wiederherstellen"
# `flutter create` schreibt Template-Versionen dieser Dateien. Unsere gewinnen.
for path in lib test integration_test pubspec.yaml analysis_options.yaml README.md .gitignore; do
  if [ -e "$path" ]; then
    git checkout -- "$path" 2>/dev/null || true
  fi
done

echo "==> Fertig"
