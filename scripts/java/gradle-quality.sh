#!/bin/bash
set -euo pipefail

echo "Running quality checks..."

if [ ! -x "./gradlew" ]; then
  echo "❌ Gradle wrapper not found/executable at ./gradlew (expected in 'code/')"
  exit 1
fi

# Detect if any .java files exist in src/main or src/test across submodules
FIRST_JAVA_FILE="$(find . -type f -name '*.java' \( -path '*/src/main/java/*' -o -path '*/src/test/java/*' \) -print -quit || true)"

if [ -z "${FIRST_JAVA_FILE}" ]; then
  echo "⚠️ No Java source files found under 'code/'. Skipping quality checks."
  exit 0
fi
# Checkstyle - Google style (expected config in a known location)
echo "Building Project and verifying Checkstyle, PMD, SpotBugs..."
./gradlew build --no-daemon --stacktrace

echo "✅ Quality checks completed successfully."
