#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web
# TEMP: TODO: rsync -a --delete web/ build/web/
cp web/oneofus.html build/web/index.html

if [[ "${1:-}" == "deploy" ]]; then
  firebase deploy --only hosting --project=one-of-us-net
fi
