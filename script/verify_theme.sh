#!/bin/bash
set -euo pipefail
if [[ $# != 1 ]]; then echo "Usage: $0 theme.cape" >&2; exit 2; fi
theme="$1"
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun clang -fblocks -include Mousecape/mousecloak/mousecloak-Prefix.pch \
    -I Mousecape/mousecloak -I Mousecape/mousecloak/CGSInternal \
    -framework Cocoa -framework ApplicationServices \
    tests/cursor-readback.m Mousecape/mousecloak/MCDefs.m \
    -o build/tests/cursor-readback
build/tests/cursor-readback "$theme"
