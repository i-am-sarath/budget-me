# Debug run script - injects secrets from dart_defines.env (gitignored)
# Usage: .\run_debug.ps1            (runs on default device)
#        .\run_debug.ps1 -d chrome   (or any flutter device id)

param([Parameter(ValueFromRemainingArguments = $true)] $extraArgs)

$envFile = "dart_defines.env"
if (-not (Test-Path $envFile)) {
    Write-Error "Missing $envFile - create it with PROXY_BASE_URL, PROXY_CLIENT_SECRET, RC_ANDROID_KEY"
    exit 1
}

$defines = Get-Content $envFile |
    Where-Object { $_ -match '^\w+=' } |
    ForEach-Object { "--dart-define=$_" }

flutter run @defines @extraArgs
