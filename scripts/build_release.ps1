# Budget Me - release build helper (Windows / PowerShell).
#
# Usage:
#   1. Copy dart_defines.example.json -> dart_defines.json and fill in real keys.
#   2. Ensure android/key.properties + the upload keystore exist (release signing).
#   3. .\scripts\build_release.ps1            # builds an AAB for Play
#      .\scripts\build_release.ps1 -Apk       # builds a universal APK instead
#
# All secrets are injected from dart_defines.json at build time - none are
# committed to the repo or baked in as source defaults.

param(
    [switch]$Apk
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$definesFile = Join-Path $repoRoot "dart_defines.json"
if (-not (Test-Path $definesFile)) {
    Write-Error "Missing dart_defines.json. Copy dart_defines.example.json to dart_defines.json and fill in real values."
}

$keyProps = Join-Path $repoRoot "android\key.properties"
if (-not (Test-Path $keyProps)) {
    Write-Warning "android/key.properties not found - the release will fall back to DEBUG signing and Play will reject it. Create your upload keystore first."
}

Write-Host "Fetching dependencies..." -ForegroundColor Cyan
flutter pub get

if ($Apk) {
    Write-Host "Building release APK..." -ForegroundColor Cyan
    flutter build apk --release --dart-define-from-file=dart_defines.json
} else {
    Write-Host "Building release App Bundle (AAB)..." -ForegroundColor Cyan
    flutter build appbundle --release --dart-define-from-file=dart_defines.json
}

Write-Host "Done. Artifact under build\app\outputs." -ForegroundColor Green
