#!/usr/bin/env bash
# Generate android/ and ios/ folders (if missing) and apply RODRU settings.
# Usage: bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org com.rodru --project-name rodru --platforms android,ios .
fi
python3 tool/patch_platforms.py

# On CI only: use the shared test key so new builds install over old ones.
if [ "${CI:-}" = "true" ]; then
  mkdir -p "$HOME/.android"
  cp tool/signing/debug.keystore "$HOME/.android/debug.keystore"
fi
echo "Platforms ready."
