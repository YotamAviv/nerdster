#!/usr/bin/env bash
set -euo pipefail
mkdir -p build/web
rsync -a --delete web/ build/web/

if [[ "${1:-}" == "deploy" ]]; then
  firebase deploy --only hosting --project=nerdster
fi
