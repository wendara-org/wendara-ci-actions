#!/bin/bash
set -euo pipefail

echo "▶ Running Java integration tests..."

# Check if there are any *TestIT.java files
if ! find . -type f -name "*TestIT.java" | grep -q .; then
  echo "⚠️ No integration tests found. Skipping."
  exit 0
fi

./gradlew integrationTest --tests '*TestIT' --no-daemon

echo "✅ Integration tests completed."
