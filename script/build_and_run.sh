#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--cli" ]]; then exec ./script/build.sh "$@"; fi
pkill -x Mousecape || true
./script/build.sh "$@"
open -n "$PWD/build/Mousecape.app"
