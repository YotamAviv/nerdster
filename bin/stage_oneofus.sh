#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web
rsync -a web/ build/web/
cp build/web/.well-known/oneofus_assetlinks.json build/web/.well-known/assetlinks.json
cp web/oneofus_man.html build/web/man.html
cp web/oneofus.html build/web/index.html
if [[ "${1:-}" == "deploy" ]]; then
  firebase deploy --config oneofus.firebase.json --only hosting --project=one-of-us-net
fi
