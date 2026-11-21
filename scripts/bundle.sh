#!/bin/bash
# Builds the package and assembles build/Vimac-AI.app.
#
# Usage: scripts/bundle.sh [debug|release]
#
# VIMAC_SIGN_IDENTITY selects the code signing identity. It defaults to "-" (ad-hoc).
# An ad-hoc signature changes on every build, so macOS may ask for the Accessibility
# permission again. A stable identity from the keychain avoids that.
set -euo pipefail

configuration="${1:-debug}"
case "$configuration" in
  debug | release) ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 64
    ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
identity="${VIMAC_SIGN_IDENTITY:--}"
app="$root/build/Vimac-AI.app"

cd "$root"
swift build -c "$configuration" --product Vimac-AI
binary="$(swift build -c "$configuration" --show-bin-path)/Vimac-AI"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Vimac-AI"
cp "$root/Support/Info.plist" "$app/Contents/Info.plist"

codesign --force --sign "$identity" --identifier dev.vimac-ai.Vimac "$app"

echo "Built $app"
