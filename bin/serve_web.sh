#!/usr/bin/env bash
set -euo pipefail

# serve_web.sh
# Builds and restructures the Nerdster web app for local dev, then serves it
# at http://localhost:8765 (mirroring production structure).
#
# Flutter app: http://localhost:8765/app?fire=emulator
# Home page:   http://localhost:8765/
#
# For OneOfUs iframe embedding, also run from the oneofusv22 repo:
#   python3 -m http.server 8766 --directory web
# Then open: http://localhost:8766/index.html?fire=emulator

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_restructure_web.sh"

echo "=== Building Flutter web app (base href /app/) ==="
flutter build web --base-href /app/

echo ""
restructure_web

echo ""
echo "=== Serving at http://localhost:8765 ==="
echo "Flutter app: http://localhost:8765/app?fire=emulator"
echo "Home page:   http://localhost:8765/"
echo ""
python3 -m http.server 8765 --directory build/web
