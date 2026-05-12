# Release build script - reads secrets from dart_defines.env (gitignored)
# Usage: .\build_release.ps1

$envFile = "dart_defines.env"
if (-not (Test-Path $envFile)) {
    Write-Error "Missing $envFile - create it with PROXY_BASE_URL, PROXY_CLIENT_SECRET, RC_ANDROID_KEY"
    exit 1
}

$defines = Get-Content $envFile |
    Where-Object { $_ -match '^\w+=' } |
    ForEach-Object { "--dart-define=$_" }

Write-Host "Building release AAB..."
flutter build appbundle --release --no-tree-shake-icons @defines
