#!/bin/bash

# Track failures
FAILED_TESTS=()
PASSED_TESTS=()

# Per-test timeout = 3× the slowest observed test (ui_test: ~33s → 100s).
# If a test exceeds this, it is counted as failed rather than hanging forever.
TIMEOUT_SECS=100

# Prerequisites:
#   Firebase emulators: firebase --project=nerdster emulators:start
#                       firebase --project=one-of-us-net --config=oneofus.firebase.json emulators:start
#   ChromeDriver:       chromedriver --port=4444
echo "Ensure Firebase Emulators (8080/5001) & ChromeDriver (4444) are running."
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
echo "=== Running Integration Tests (Chrome, timeout=${TIMEOUT_SECS}s each) ==="
shopt -s nullglob
for test_file in integration_test/*.dart; do
    test_name=$(basename "$test_file")
    echo "Running: $test_name"
    if timeout "$TIMEOUT_SECS" flutter drive \
        --driver=test_driver/integration_test.dart \
        --target="$test_file" \
        -d chrome; then
        PASSED_TESTS+=("$test_name (chrome)")
    else
        exit_code=$?
        if [ "$exit_code" -eq 124 ]; then
            echo "TIMEOUT: $test_name exceeded ${TIMEOUT_SECS}s"
        fi
        FAILED_TESTS+=("$test_name (chrome)")
    fi
    echo ""
done

# 4. Integration Tests (Android emulator, if one is running)
ANDROID_DEVICE=$(flutter devices 2>/dev/null | grep '(emulator)' | awk -F'•' '{print $2}' | tr -d ' ' | head -1)
if [ -n "$ANDROID_DEVICE" ]; then
    echo "=== Running Integration Tests (Android emulator: $ANDROID_DEVICE, timeout=${TIMEOUT_SECS}s each) ==="
    for test_file in integration_test/*.dart; do
        test_name=$(basename "$test_file")
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
