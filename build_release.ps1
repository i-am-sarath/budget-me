# Release build (wrapper). Delegates to scripts\build_release.ps1 so there is
# ONE build path and ONE config source (dart_defines.json). All secrets -
# Supabase, GOOGLE_WEB_CLIENT_ID, Sentry, RevenueCat - come from that file.
#
# Usage:
#   .\build_release.ps1          # builds an AAB for Play
#   .\build_release.ps1 -Apk     # builds a universal APK instead

param(
    [switch]$Apk
)

& "$PSScriptRoot\scripts\build_release.ps1" @PSBoundParameters
