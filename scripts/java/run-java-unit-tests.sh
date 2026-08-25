#!/bin/bash
set -euo pipefail

echo "▶ Running Java unit tests..."

# Check if there are any *Test.java files excluding *TestIT.java
if find . -type f -name "*Test.java" ! -name "*TestIT.java" -print -quit | grep -q .; then
  ${GRADLEW:-./gradlew} \
    test \
    --tests '*Test' \
    --build-cache \
    --parallel \
    --configuration-cache
  echo "✅ Unit tests completed."
else
  echo "⚠️ No unit tests found. Skipping."
fi
