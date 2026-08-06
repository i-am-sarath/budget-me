# Debug run script - injects ALL secrets from dart_defines.json (gitignored),
# the same single config source the release build uses. This guarantees debug
# and release behave identically (Google sign-in, Supabase, RevenueCat, Sentry).
#
# Usage:
#   .\run_debug.ps1              (runs on default device)
#   .\run_debug.ps1 -d chrome    (or any flutter device id)

param([Parameter(ValueFromRemainingArguments = $true)] $extraArgs)

$definesFile = "dart_defines.json"
if (-not (Test-Path $definesFile)) {
    Write-Error "Missing $definesFile - copy dart_defines.example.json to dart_defines.json and fill in real values."
    exit 1
}

flutter run --dart-define-from-file=$definesFile @extraArgs
