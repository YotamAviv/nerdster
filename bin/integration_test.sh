#!/bin/bash

# Integration test command replacing `flutter drive`.
# This calls a Python wrapper that runs the DEV UI test runner 
# using `flutter run --dart-define=AUTORUN_TESTS=true`.
# This circumvents flutter drive websocket hanging issues entirely.

python3 bin/run_dev_tests.py
