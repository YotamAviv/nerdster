#!/bin/bash

# Ports required for Nerdster and One-of-us-net emulators + ChromeDriver
PORTS=(8080 8081 5001 5002 4444 5005)

echo "Checking required ports..."
ALL_UP=true

for port in "${PORTS[@]}"; do
  if lsof -i :$port > /dev/null; then
    echo "✅ Port $port is ACTIVE"
  else
    echo "❌ Port $port is CLOSED"
    ALL_UP=false
  fi
done

if [ "$ALL_UP" = true ]; then
  echo "All required services appear to be running."
  exit 0
else
  echo "Some services are missing. Please start the emulators and chromedriver as per docs/testing.md."
  exit 1
fi
