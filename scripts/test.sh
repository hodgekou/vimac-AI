#!/bin/bash
# Runs the unit tests.
#
# With only the Command Line Tools installed, the Swift Testing macro plugin is on disk
# but outside the compiler's default plugin search path, so it is passed explicitly.
set -euo pipefail

cd "$(dirname "$0")/.."

plugins="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
if [ -d "$plugins" ]; then
  exec swift test -Xswiftc -plugin-path -Xswiftc "$plugins" "$@"
fi
exec swift test "$@"
