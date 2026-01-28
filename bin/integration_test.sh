#!/bin/bash

# Integration test command from docs/testing.md
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/basic_test.dart \
  -d chrome

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ui_test.dart \
  -d chrome
