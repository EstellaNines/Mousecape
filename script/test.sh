#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
xcrun clang -fblocks -fobjc-weak \
    -include Mousecape/mousecloak/mousecloak-Prefix.pch \
    -I Mousecape/mousecloak -I Mousecape/mousecloak/CGSInternal \
    -framework Cocoa -framework ApplicationServices \
    tests/cursor-registration.m Mousecape/mousecloak/apply.m \
    Mousecape/mousecloak/MCDefs.m Mousecape/mousecloak/backup.m \
    Mousecape/mousecloak/restore.m Mousecape/mousecloak/NSBitmapImageRep+ColorSpace.m \
    -o build/tests/cursor-registration
build/tests/cursor-registration modern
build/tests/cursor-registration legacy
