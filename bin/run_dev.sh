#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

# Fixed port so Hablotengo can link here (nerdsterAppUrl emulator → localhost:8765).
echo "http://localhost:8765/?fire=emulator"
flutter run -d chrome --web-port=8765
