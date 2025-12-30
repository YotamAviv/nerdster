#!/bin/bash
set -e

echo "Running Simpsons Relate Demo..."
echo "Ensure Firebase Emulators and Chromedriver are running."

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/run_simpsons_relate_demo.dart \
  -d chrome

echo "Demo complete."
