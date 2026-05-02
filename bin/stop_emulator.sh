#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

PIDFILE="$REPO_DIR/.nerdster_emulator.pid"
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping nerdster emulator (PID $PID)..."
        kill "$PID"
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

# Kill any stale processes holding emulator ports
for PORT in 5001 8080 9150; do
    PID=$(lsof -ti :"$PORT" 2>/dev/null)
    if [ -n "$PID" ]; then
        echo "Killing stale process on port $PORT (PID $PID)..."
        kill "$PID" 2>/dev/null
    fi
done
