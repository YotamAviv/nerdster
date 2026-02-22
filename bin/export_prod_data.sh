#!/bin/bash
set -e

# Use provided date or generate one
NOW=${1:-$(date +%y-%m-%d--%H-%M)}
echo "Exporting with timestamp: $NOW"

mkdir -p exports

echo "=== Exporting nerdster ==="
firebase use nerdster
gcloud config set project nerdster
gcloud firestore export gs://nerdster/nerdster-$NOW
gsutil -m cp -r gs://nerdster/nerdster-$NOW exports/

echo "=== Exporting one-of-us-net ==="
firebase use one-of-us-net
gcloud config set project one-of-us-net
gcloud firestore export gs://one-of-us-net/oneofus-$NOW
gsutil -m cp -r gs://one-of-us-net/oneofus-$NOW exports/

echo "Export complete."
