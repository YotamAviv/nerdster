#!/bin/bash

# Test command replacing `flutter drive`.
# This calls a Python wrapper that visually mounts a designated Flutter widget 
# using `flutter run --dart-define=RUN_WIDGET=true`.
# This circumvents flutter drive websocket hanging issues entirely.

python3 bin/run_test_widget.py
