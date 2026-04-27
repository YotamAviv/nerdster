#!/bin/bash
# Check status of all three project emulators.

check() {
    local name=$1; local firestore=$2; local functions=$3
    local fs_status functions_status
    nc -z localhost "$firestore" 2>/dev/null && fs_status="UP" || fs_status="DOWN"
    nc -z localhost "$functions" 2>/dev/null && functions_status="UP" || functions_status="DOWN"
    printf "%-12s  Firestore %-4s (:%s)  Functions %-4s (:%s)\n" \
        "$name" "$fs_status" "$firestore" "$functions_status" "$functions"
}

check "nerdster"    8080 5001
check "oneofus"     8081 5002
check "hablotengo"  8082 5003
