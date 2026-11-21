#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Checks formatting and style with the formatter that ships with the Swift toolchain.
# Pass --fix to rewrite the files in place instead.
set -euo pipefail

cd "$(dirname "$0")/.."
paths=(Sources Tests Package.swift scripts/make-icon.swift)

if [ "${1:-}" = "--fix" ]; then
  exec swift format format --in-place --recursive "${paths[@]}"
fi
exec swift format lint --strict --recursive "${paths[@]}"
