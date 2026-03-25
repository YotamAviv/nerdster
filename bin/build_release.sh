#!/usr/bin/env bash
set -euo pipefail

# Verify version
echo "=== Version ==="
grep "^version:" pubspec.yaml

# Extract build number (the part after '+')
build=$(grep "^version:" pubspec.yaml | sed 's/.*+//')

echo ""
echo "=== Building appbundle (build $build) ==="
flutter build appbundle

echo ""
echo "=== Saving to builds/$build ==="
mkdir -p "builds/$build"
cp build/app/outputs/bundle/release/app-release.aab "builds/$build/"
echo "Saved: builds/$build/app-release.aab"
