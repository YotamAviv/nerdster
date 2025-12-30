#!/bin/bash

# Integration test command from docs/testing.md
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/v2_basic_test.dart \
  -d chrome

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/v2_ui_test.dart \
  -d chrome
