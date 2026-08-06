#!/usr/bin/env bash
# Budget Me — release build helper (macOS / Linux / CI).
#
# Usage:
#   1. Copy dart_defines.example.json -> dart_defines.json and fill in real keys.
#   2. Ensure android/key.properties + the upload keystore exist (release signing).
#   3. ./scripts/build_release.sh            # builds an AAB for Play
#      ./scripts/build_release.sh --apk       # builds a universal APK instead
#
# All secrets are injected from dart_defines.json at build time — none are
# committed to the repo or baked in as source defaults.

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f dart_defines.json ]]; then
  echo "ERROR: Missing dart_defines.json. Copy dart_defines.example.json to dart_defines.json and fill in real values." >&2
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "WARNING: android/key.properties not found — the release will fall back to DEBUG signing and Play will reject it. Create your upload keystore first." >&2
fi

echo "Fetching dependencies..."
flutter pub get

if [[ "${1:-}" == "--apk" ]]; then
  echo "Building release APK..."
  flutter build apk --release --dart-define-from-file=dart_defines.json
else
  echo "Building release App Bundle (AAB)..."
  flutter build appbundle --release --dart-define-from-file=dart_defines.json
fi

echo "Done. Artifact under build/app/outputs/."
