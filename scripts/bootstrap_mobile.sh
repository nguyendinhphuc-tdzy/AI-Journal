#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE_DIR="$REPO_ROOT/mobile"
TEMP_DIR="$REPO_ROOT/.flutter_bootstrap_tmp"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter was not found in PATH. Install Flutter first." >&2
  exit 1
fi

if [ -d "$MOBILE_DIR/android" ]; then
  echo "mobile/android already exists. Nothing to generate."
  exit 0
fi

rm -rf "$TEMP_DIR"
flutter create --platforms=android --org com.aidiary --project-name ai_diary "$TEMP_DIR"
cp -R "$TEMP_DIR/android" "$MOBILE_DIR/android"
rm -rf "$TEMP_DIR"

echo "Android platform generated. Next: cd mobile && flutter pub get && flutter run"
