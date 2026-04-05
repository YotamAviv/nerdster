#!/usr/bin/env bash
set -euo pipefail

# Verify version
echo "=== Version ==="
grep "^version:" pubspec.yaml

# Extract build number (the part after '+')
build=$(grep "^version:" pubspec.yaml | sed 's/.*+//')

if [ -d "builds/$build" ]; then
  echo "ERROR: builds/$build already exists. Did you forget to increment the build number?" >&2
  exit 1
fi

echo ""
echo "=== Building appbundle (build $build) ==="
flutter build appbundle

echo ""
echo "=== Saving to builds/$build ==="
mkdir -p "builds/$build"
cp build/app/outputs/bundle/release/app-release.aab "builds/$build/"
echo "Saved: builds/$build/app-release.aab"
