#!/bin/bash
set -euo pipefail

echo "▶ Running Java integration tests..."

# Check if there are any *TestIT.java files
if ! find . -type f -name "*TestIT.java" -print -quit | grep -q .; then
  echo "⚠️ No integration tests found. Skipping."
  exit 0
fi

if ! ${GRADLEW:-./gradlew} \
  integrationTest \
  --tests '*TestIT' \
  --build-cache \
  --parallel \
  --stacktrace \
  --configuration-cache; then
  echo "❌ Integration tests failed. Printing a short failure summary:"
  "$(dirname "$0")/summarize-java-test-failures.sh" integrationTest
  exit 1
fi

echo "✅ Integration tests completed."
