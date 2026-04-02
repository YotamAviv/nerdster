#!/bin/bash

# Track failures
FAILED_TESTS=()
PASSED_TESTS=()

# Per-test timeout includes cold web build (60-90s) + Chrome connection (~15s) + test execution (~60s).
# If a test exceeds this, it is counted as failed rather than hanging forever.
TIMEOUT_SECS=90

# Prerequisites:
#   Firebase emulators: firebase --project=nerdster emulators:start
#                       firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start
echo "Checking prerequisites..."
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

# 3. Web Widget Runner (Chrome Headless)
echo "=== Running Web Widget Tests (Chrome) ==="
if python3 bin/chrome_widget_runner.py --headless -t lib/dev/cloud_source_web_test.dart; then
    PASSED_TESTS+=("cloud_source_web_test (chrome)")
else
    FAILED_TESTS+=("cloud_source_web_test (chrome)")
fi
echo ""

# 4. Integration Tests (Android emulator, if one is running)
ANDROID_DEVICE=$(flutter devices 2>/dev/null | grep '(emulator)' | awk -F'•' '{print $2}' | tr -d ' ' | head -1)
if [ -n "$ANDROID_DEVICE" ]; then
    echo "=== Running Integration Tests (Android emulator: $ANDROID_DEVICE, timeout=${TIMEOUT_SECS}s each) ==="
    
    # We explicitly specify the tests to run according to the plan
    ANDROID_TESTS=(
        "integration_test/ui_test.dart"
        "integration_test/cloud_source_android_test.dart"
        "integration_test/magic_paste_test.dart"
    )

    for test_file in "${ANDROID_TESTS[@]}"; do
        if [ ! -f "$test_file" ]; then
            echo "Warning: $test_file not found. Skipping."
            continue
        fi

        test_name=$(basename "$test_file")
        echo "Running: $test_name"

        if [ "$test_file" = "integration_test/cloud_source_android_test.dart" ]; then
            # This test signals pass/fail via PASS/FAIL/ERROR strings (not flutter exit code),
            # so we use the sentinel-aware Python runner, which enforces its own timeout.
            if python3 bin/android_test_runner.py -t "$test_file" -d "$ANDROID_DEVICE" --timeout "$TIMEOUT_SECS"; then
                PASSED_TESTS+=("$test_name (android)")
            else
                FAILED_TESTS+=("$test_name (android)")
            fi
        else
            if timeout "$TIMEOUT_SECS" flutter test "$test_file" -d "$ANDROID_DEVICE"; then
                PASSED_TESTS+=("$test_name (android)")
            else
                exit_code=$?
                [ "$exit_code" -eq 124 ] && echo "TIMEOUT: $test_name exceeded ${TIMEOUT_SECS}s"
                FAILED_TESTS+=("$test_name (android)")
            fi
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
