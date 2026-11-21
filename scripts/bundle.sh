#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Builds the package and assembles build/Keyfari.app.
#
# Usage: scripts/bundle.sh [debug|release]
#
# KEYFARI_SIGN_IDENTITY selects the code signing identity. It defaults to "-" (ad-hoc).
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
identity="${KEYFARI_SIGN_IDENTITY:--}"
app="$root/build/Keyfari.app"

cd "$root"
swift build -c "$configuration" --product Keyfari
binary="$(swift build -c "$configuration" --show-bin-path)/Keyfari"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary" "$app/Contents/MacOS/Keyfari"
cp "$root/Resources/Info.plist" "$app/Contents/Info.plist"
# Regenerate the icon with scripts/make-icon.swift and iconutil.
cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"

codesign --force --sign "$identity" --identifier app.keyfari.Keyfari "$app"

echo "Built $app"
