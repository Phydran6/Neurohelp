# Bootstrap für Windows-Entwicklungsrechner.
#
# Erzeugt die von Flutter generierten Plattform-Ordner (android/, ios/) im
# bestehenden Repository und stellt anschließend die kuratierten Projektdateien
# wieder her, die `flutter create` sonst überschreiben würde.
#
# Aufruf aus dem Repo-Wurzelverzeichnis:
#   pwsh -File scripts/bootstrap.ps1

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "==> Flutter prüfen" -ForegroundColor Cyan
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error @"
Flutter wurde nicht gefunden.

Installation (einmalig):
  winget install --id Google.Flutter -e
  # danach neue Shell öffnen, dann:
  flutter doctor

Alternativ manuell: https://docs.flutter.dev/get-started/install/windows
"@
}

flutter --version

Write-Host "==> Plattform-Ordner erzeugen (android, ios)" -ForegroundColor Cyan
flutter create `
    --project-name neurohelp `
    --org de.phytech `
    --platforms android,ios `
    --overwrite `
    .

Write-Host "==> Kuratierte Projektdateien wiederherstellen" -ForegroundColor Cyan
# `flutter create` überschreibt Template-Dateien. Unsere Versionen gewinnen.
$curated = @(
    "lib", "test", "integration_test",
    "pubspec.yaml", "analysis_options.yaml",
    "README.md", ".gitignore"
)
foreach ($path in $curated) {
    if (Test-Path $path) {
        git checkout -- $path 2>$null
    }
}

Write-Host "==> Abhängigkeiten holen" -ForegroundColor Cyan
flutter pub get

Write-Host "==> Formatieren" -ForegroundColor Cyan
dart format .

Write-Host "==> Analyse & Tests" -ForegroundColor Cyan
flutter analyze
flutter test

Write-Host ""
Write-Host "Fertig." -ForegroundColor Green
Write-Host "Naechste Schritte:" -ForegroundColor Yellow
Write-Host "  - android/ und ios/ committen (ab jetzt Teil des Repos)"
Write-Host "  - android/app/build.gradle.kts um die Release-Signatur ergaenzen"
Write-Host "  - GitHub-Secrets fuer Play Store / TestFlight hinterlegen"
Write-Host "  Details: docs/RELEASING.md"
