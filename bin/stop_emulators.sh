#!/bin/bash

stop_pid() {
    local pid_file=$1
    local name=$2
    if [ -f "$pid_file" ]; then
        PID=$(cat "$pid_file")
        if kill -0 "$PID" 2>/dev/null; then
            echo "Stopping $name (PID $PID)..."
            kill "$PID"
            
            # Wait a few seconds to let it terminate gracefully
            for i in {1..5}; do
                if ! kill -0 "$PID" 2>/dev/null; then
                    break
                fi
                sleep 1
            done
            
            # Force kill if still running
            if kill -0 "$PID" 2>/dev/null; then
                echo "Force stopping $name (PID $PID)..."
                kill -9 "$PID"
            fi
        fi
        rm "$pid_file"
    else
        echo "$name pid file not found (is it running?)"
    fi
}

stop_pid .nerdster_emulator.pid "nerdster emulator"
stop_pid .oneofus_emulator.pid "one-of-us-net emulator"

echo "Done."
