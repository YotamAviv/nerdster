#!/bin/bash

# Track failures
FAILED_TESTS=()
PASSED_TESTS=()

# Per-test timeout includes cold web build (60-90s) + Chrome connection (~15s) + test execution (~60s).
# If a test exceeds this, it is counted as failed rather than hanging forever.
TIMEOUT_SECS=300

# Prerequisites:
#   Firebase emulators: firebase --project=nerdster emulators:start
#                       firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start
#   ChromeDriver:       chromedriver --port=4444
echo "Checking prerequisites..."
curl -sf http://localhost:4444/status | grep -q '"ready":true' \
    || { echo "ERROR: ChromeDriver not ready on port 4444. Start it with: chromedriver --port=4444"; exit 1; }
curl -s --max-time 3 http://localhost:8080/ > /dev/null \
    || { echo "ERROR: Firebase emulator not responding on port 8080."; exit 1; }
curl -s --max-time 3 http://localhost:5001/ > /dev/null \
    || { echo "ERROR: Firebase emulator not responding on port 5001."; exit 1; }
echo "Prerequisites OK."
echo ""

# 1. Backend Tests
echo "=== Running Backend Tests ==="
if (cd functions && npm test); then
    PASSED_TESTS+=("Backend tests")
else
    FAILED_TESTS+=("Backend tests")
fi
echo ""

# 2. Unit Tests
echo "=== Running Flutter Unit Tests ==="
if flutter test; then
    PASSED_TESTS+=("Flutter unit tests")
else
    FAILED_TESTS+=("Flutter unit tests")
fi
echo ""

echo "=== Running oneofus_common Package Tests ==="
if flutter test packages/oneofus_common/; then
    PASSED_TESTS+=("oneofus_common tests")
else
    FAILED_TESTS+=("oneofus_common tests")
fi
echo ""

# 3. Integration Tests (Chrome)
#
# WHY flutter drive (not flutter test -d chrome):
#   Firebase plugins (cloud_firestore) have no Linux native implementation.
#   Tests must run inside a browser. flutter test -d chrome refuses integration
#   tests ("Web devices are not supported for integration tests yet"), so
#   flutter drive with ChromeDriver is the only supported path on Linux.
#
# WHY the background+poll approach:
#   flutter drive on web never exits after tests complete. This is a known,
#   unresolved Flutter bug: driver.requestData() (inside integrationDriver())
#   hangs indefinitely after the test finishes. There is no clean fix.
#   We work around it by running flutter drive in the background, polling the
#   output for the definitive result markers, and killing the process as soon
#   as we see one. This trades live output for prompt exit.
#
# PASS marker: "All tests passed!"  — printed by integrationDriver() on success
# FAIL marker: "Some tests failed"  — printed by integrationDriver() on failure
echo "=== Running Integration Tests (Chrome, timeout=${TIMEOUT_SECS}s each) ==="
shopt -s nullglob
for test_file in integration_test/*.dart; do
    test_name=$(basename "$test_file")
    # screenshot_test.dart is an iOS-only App Store screenshot tool, not a test.
    if [[ "$test_name" == *screenshot* ]]; then continue; fi
    echo "Running: $test_name"
    tmpout=$(mktemp)
    flutter drive \
        --driver=test_driver/integration_test.dart \
        --target="$test_file" \
        -d chrome >"$tmpout" 2>&1 &
    flutter_pid=$!

    elapsed=0
    result=""
    while kill -0 "$flutter_pid" 2>/dev/null; do
        if grep -q "All tests passed" "$tmpout"; then
            result="passed"
            kill "$flutter_pid" 2>/dev/null
            break
        elif grep -q "Some tests failed" "$tmpout"; then
            result="failed"
            kill "$flutter_pid" 2>/dev/null
            break
        fi
        sleep 2
        elapsed=$((elapsed + 2))
        if [[ $elapsed -ge $TIMEOUT_SECS ]]; then
            echo "TIMEOUT: $test_name exceeded ${TIMEOUT_SECS}s"
            kill "$flutter_pid" 2>/dev/null
            result="timeout"
            break
        fi
    done
    wait "$flutter_pid" 2>/dev/null

    # Print captured output so it's visible in the terminal.
    cat "$tmpout"
    rm -f "$tmpout"

    if [[ "$result" == "passed" ]]; then
        PASSED_TESTS+=("$test_name (chrome)")
    else
        FAILED_TESTS+=("$test_name (chrome)")
    fi
    # Kill any Chrome instance launched by ChromeDriver so next test gets a clean session.
    pkill -f "remote-debugging-port" 2>/dev/null; sleep 2

    echo ""
done

# 4. Integration Tests (Android emulator, if one is running)
ANDROID_DEVICE=$(flutter devices 2>/dev/null | grep '(emulator)' | awk -F'•' '{print $2}' | tr -d ' ' | head -1)
if [ -n "$ANDROID_DEVICE" ]; then
    echo "=== Running Integration Tests (Android emulator: $ANDROID_DEVICE, timeout=${TIMEOUT_SECS}s each) ==="
    for test_file in integration_test/*.dart; do
        test_name=$(basename "$test_file")
        # screenshot_test.dart is an iOS-only App Store screenshot tool, not a test.
        if [[ "$test_name" == *screenshot* ]]; then continue; fi
        echo "Running: $test_name"
        if timeout "$TIMEOUT_SECS" flutter test "$test_file" -d "$ANDROID_DEVICE"; then
            PASSED_TESTS+=("$test_name (android)")
        else
            exit_code=$?
            if [ "$exit_code" -eq 124 ]; then
                echo "TIMEOUT: $test_name exceeded ${TIMEOUT_SECS}s"
            fi
            FAILED_TESTS+=("$test_name (android)")
        fi
        echo ""
    done
else
    echo "=== No Android emulator running — skipping Android integration tests ==="
    echo "    (Start one with: flutter emulators --launch Pixel_3a_API_35)"
    echo ""
fi

# Summary
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo "PASSED (${#PASSED_TESTS[@]}):"
for test in "${PASSED_TESTS[@]}"; do
    echo "  ✅ $test"
done
echo ""
echo "FAILED (${#FAILED_TESTS[@]}):"
if [ ${#FAILED_TESTS[@]} -eq 0 ]; then
    echo "  (none)"
else
    for test in "${FAILED_TESTS[@]}"; do
        echo "  ❌ $test"
    done
fi
echo "========================================"

# Exit with failure if any tests failed
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    exit 1
fi
