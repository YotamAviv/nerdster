#!/bin/bash
set -e

NOW=${1:-$(date +%y-%m-%d--%H-%M)}
echo "Exporting with timestamp: $NOW"

mkdir -p exports

echo "=== Exporting nerdster ==="
firebase use nerdster
gcloud config set project nerdster
gcloud firestore export gs://nerdster/nerdster-$NOW
gsutil -m cp -r gs://nerdster/nerdster-$NOW exports/

echo "Export complete: exports/nerdster-$NOW"
