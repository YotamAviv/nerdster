#!/bin/bash
set -e

# [Aviv, the human]: I tested corruption detection manually and it worked.
# TODO: Automate this after V2 

echo "Generating Corruption Data..."
echo "Ensure Firebase Emulators and Chromedriver are running."

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/generate_corruption_data.dart \
  -d chrome

echo "Data generation complete."
