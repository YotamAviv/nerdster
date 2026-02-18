#!/bin/bash

# Track failures
FAILED_TESTS=()
PASSED_TESTS=()

# Checks
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

# 3. Integration Tests
echo "=== Running Integration Tests ==="
shopt -s nullglob
for test_file in integration_test/*.dart; do
    test_name=$(basename "$test_file")
    echo "Running: $test_name"
    if flutter drive --driver=test_driver/integration_test.dart --target="$test_file" -d chrome; then
        PASSED_TESTS+=("$test_name")
    else
        FAILED_TESTS+=("$test_name")
    fi
    echo ""
done

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
