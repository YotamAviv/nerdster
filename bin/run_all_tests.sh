#!/bin/bash
set -e

# Checks
echo "Ensure Firebase Emulators (8080/5001) & ChromeDriver (4444) are running."

# 1. Backend Tests
(cd functions && npm test)

# 2. Unit Tests
flutter test
flutter test packages/oneofus_common/

# 3. Integration Tests
shopt -s nullglob
for test_file in integration_test/*.dart; do
    echo "Running: $test_file"
    flutter drive --driver=test_driver/integration_test.dart --target="$test_file" -d chrome
done
