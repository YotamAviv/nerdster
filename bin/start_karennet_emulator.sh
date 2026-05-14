#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NERDSTER_DIR="$(dirname "$SCRIPT_DIR")"
ONEOFUS_DIR="$(dirname "$NERDSTER_DIR")/oneofus"

cd "$ONEOFUS_DIR"

echo "=== Starting karennet.net emulator (Firestore 8083, Functions 5004, UI 4003) ==="
nohup firebase --project=karennet --config=firebase_karennet.json emulators:start --only functions,firestore \
    > "$NERDSTER_DIR/karennet_emulator.log" 2>&1 &

echo $! > "$NERDSTER_DIR/.karennet_emulator.pid"
echo "Started. Log: karennet_emulator.log"
echo "UI: http://localhost:4002"
echo "Stop with: ./bin/stop_karennet_emulator.sh"

echo "Waiting for emulator to be ready..."
for i in $(seq 1 90); do
    if grep -q "All emulators ready" "$NERDSTER_DIR/karennet_emulator.log" 2>/dev/null; then
        echo "Emulator ready! (${i}s)"
        break
    fi
    if [ "$i" -eq 90 ]; then
        echo "ERROR: Emulator did not become ready within 90s. Check karennet_emulator.log"
        exit 1
    fi
    sleep 1
done
