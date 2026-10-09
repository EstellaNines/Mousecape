#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in
    --cli|--reuse-installed-resources)
        exec python3 script/build_with_clt.py "$1"
        ;;
    "")
        if ! xcrun --find ibtool >/dev/null 2>&1; then
            echo "Full Xcode is required. Use --cli for the core, or --reuse-installed-resources for a local development app." >&2
            exit 1
        fi
        xcodebuild -project Mousecape/Mousecape.xcodeproj -target Mousecape \
            -configuration Debug CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= \
            CONFIGURATION_BUILD_DIR="$PWD/build" build
        codesign --force --deep --sign - build/Mousecape.app
        ;;
    *) echo "Usage: $0 [--cli|--reuse-installed-resources]" >&2; exit 2 ;;
esac
