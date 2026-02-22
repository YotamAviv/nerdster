#!/bin/bash

# Parse options
EXPORT=false
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --export) EXPORT=true ;;
    esac
    shift
done

if [ "$EXPORT" = true ]; then
    NOW=$(date +%y-%m-%d--%H-%M)
    ./bin/export_prod_data.sh "$NOW"
    if [ $? -ne 0 ]; then
        echo "Export failed. Aborting emulator startup."
        exit 1
    fi
    NERDSTER_IMPORT="exports/nerdster-$NOW"
    ONEOFUS_IMPORT="exports/oneofus-$NOW"
else
    if [ -d "exports" ]; then
        NERDSTER_IMPORT=$(ls -td exports/nerdster-* 2>/dev/null | head -1)
        ONEOFUS_IMPORT=$(ls -td exports/oneofus-* 2>/dev/null | head -1)
    fi
fi

echo "=== Starting nerdster emulators ==="
if [ -n "$NERDSTER_IMPORT" ]; then
    echo "Using import: $NERDSTER_IMPORT"
    nohup firebase --project=nerdster emulators:start --import "$NERDSTER_IMPORT/" > nerdster_emulators.log 2>&1 &
else
    echo "No import data found for nerdster."
    nohup firebase --project=nerdster emulators:start > nerdster_emulators.log 2>&1 &
fi
NERDSTER_PID=$!
echo $NERDSTER_PID > .nerdster_emulator.pid
echo "nerdster emulators started with PID $NERDSTER_PID. Output routed to nerdster_emulators.log"

echo ""
echo "=== Starting one-of-us-net emulators ==="
if [ -n "$ONEOFUS_IMPORT" ]; then
    echo "Using import: $ONEOFUS_IMPORT"
    nohup firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start --import "$ONEOFUS_IMPORT/" > oneofus_emulators.log 2>&1 &
else
    echo "No import data found for one-of-us-net."
    nohup firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start > oneofus_emulators.log 2>&1 &
fi
ONEOFUS_PID=$!
echo $ONEOFUS_PID > .oneofus_emulator.pid
echo "one-of-us-net emulators started with PID $ONEOFUS_PID. Output routed to oneofus_emulators.log"

echo ""
echo "Both emulators are running in the background."
echo "To view logs, run:"
echo "  tail -f nerdster_emulators.log"
echo "  tail -f oneofus_emulators.log"
echo ""
echo "To stop the emulators, run:"
echo "  ./bin/stop_emulators.sh"
