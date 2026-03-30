#!/usr/bin/env bash
set -euo pipefail

# deploy_web.sh
# Builds the Nerdster Flutter web app, restructures the output so that:
#   build/web/app/   <- Flutter app (served at https://nerdster.org/app)
#   build/web/       <- Static site (home page, terms, safety, etc.)
# Then deploys to Firebase Hosting.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_restructure_web.sh"

echo "=== Version ==="
grep "^version:" pubspec.yaml

echo ""
echo "=== Building Flutter web app (base href /app/) ==="
flutter build web --base-href /app/

echo ""
restructure_web

echo ""
echo "=== Deploying to Firebase Hosting ==="
firebase deploy --only hosting --project=nerdster

echo ""
echo "=== Done ==="
echo "Web app: https://nerdster.org/app"
echo "Home:    https://nerdster.org"
