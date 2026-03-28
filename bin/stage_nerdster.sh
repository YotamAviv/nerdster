#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web
rsync -a web/ build/web/
cp build/web/.well-known/nerdster_assetlinks.json build/web/.well-known/assetlinks.json
cp web/nerdster_man.html build/web/man.html
if [[ "${1:-}" == "deploy" ]]; then
  firebase deploy --only hosting --project=nerdster
fi
