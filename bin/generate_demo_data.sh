#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "=== Generating Simpsons Demo Data ==="
echo "Requires: both emulators running (nerdster on 8080/5001, oneofus on 8081/5002)"
echo ""

OUTPUT=$(python3 bin/chrome_widget_runner.py --headless -t lib/dev/simpsons_demo_generator.dart 2>&1)
echo "$OUTPUT"

DEMO_DATA=$(echo "$OUTPUT" | awk '/===DEMO_DATA_JS_START===/{flag=1; next} /===DEMO_DATA_JS_END===/{flag=0} flag')
PRIVATE_KEYS=$(echo "$OUTPUT" | awk '/===PRIVATE_KEYS_JS_START===/{flag=1; next} /===PRIVATE_KEYS_JS_END===/{flag=0} flag')

if [ -z "$DEMO_DATA" ]; then
    echo "ERROR: Could not extract demo data — did the test PASS?"
    exit 1
fi

echo "$DEMO_DATA" > web/common/data/demoData.js
echo "Written: web/common/data/demoData.js"

if [ -n "$PRIVATE_KEYS" ]; then
    echo "$PRIVATE_KEYS" > web/common/data/demoPrivateKeys.js
    echo "Written: web/common/data/demoPrivateKeys.js"
else
    echo "WARNING: Could not extract private keys"
fi
