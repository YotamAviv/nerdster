#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NERDSTER_DIR="$(dirname "$SCRIPT_DIR")"
ONEOFUS_DIR="$(dirname "$NERDSTER_DIR")/oneofus"

PIDFILE="$ONEOFUS_DIR/.karennet_emulator.pid"
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping karennet emulator (PID $PID)..."
        kill -- -$(ps -o pgid= -p "$PID" 2>/dev/null | tr -d ' ') 2>/dev/null || kill "$PID"
        for i in {1..5}; do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 1
        done
        if kill -0 "$PID" 2>/dev/null; then kill -9 "$PID"; fi
    fi
    rm "$PIDFILE"
else
    echo "No PID file found. Is the emulator running?"
fi

for PORT in 5004 8083; do
    PID=$(lsof -ti :"$PORT" -s TCP:LISTEN 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "Killing stale process on port $PORT (PID $PID)..."
        kill "$PID" 2>/dev/null
    fi
done
