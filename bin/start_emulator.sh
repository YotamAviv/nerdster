#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

EXPORT=false
EMPTY=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --export) EXPORT=true ;;
        --empty) EMPTY=true ;;
    esac
    shift
done

if [ "$EXPORT" = true ]; then
    NOW=$(date +%y-%m-%d--%H-%M)
    echo "=== Exporting nerdster from production ==="
    mkdir -p exports
    firebase use nerdster
    gcloud config set project nerdster
    gcloud firestore export gs://nerdster/nerdster-$NOW
    gsutil -m cp -r gs://nerdster/nerdster-$NOW exports/
    IMPORT="exports/nerdster-$NOW"
elif [ "$EMPTY" = true ]; then
    IMPORT=""
else
    IMPORT=$(ls -td exports/nerdster-* 2>/dev/null | head -1 || true)
fi

echo "=== Starting nerdster emulator (Firestore 8080, Functions 5001, UI 4000) ==="
if [ -n "${IMPORT:-}" ]; then
    echo "Using import: $IMPORT"
    nohup firebase --project=nerdster emulators:start --import "$IMPORT/" \
        > "$REPO_DIR/nerdster_emulator.log" 2>&1 &
else
    echo "No import data found. Starting with empty data."
    nohup firebase --project=nerdster emulators:start \
        > "$REPO_DIR/nerdster_emulator.log" 2>&1 &
fi

echo $! > "$REPO_DIR/.nerdster_emulator.pid"
echo "Started. Log: nerdster_emulator.log"
echo "UI: http://localhost:4000"
echo "Stop with: ./bin/stop_emulator.sh"

echo "Waiting for emulator to be ready..."
for i in $(seq 1 90); do
    if grep -q "All emulators ready" "$REPO_DIR/nerdster_emulator.log" 2>/dev/null; then
        echo "Emulator ready! (${i}s)"
        break
    fi
    if [ "$i" -eq 90 ]; then
        echo "ERROR: Emulator did not become ready within 90s. Check nerdster_emulator.log"
        exit 1
    fi
    sleep 1
done
