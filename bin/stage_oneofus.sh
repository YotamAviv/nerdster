#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web
# TODO: This deletes flutter_bootsrap.js 
# rsync -a --delete web/ build/web/
rsync -a web/ build/web/
cp web/oneofus.html build/web/index.html
if [[ "${1:-}" == "deploy" ]]; then
  firebase deploy --config oneofus.firebase.json --only hosting --project=one-of-us-net
fi
