#!/bin/bash
set -euo pipefail

echo "▶ Running quality checks..."

# Detect if any .java files exist in src/main or src/test across submodules
if ! find . -type f \( -path "*/src/main/java/*.java" -o -path "*/src/test/java/*.java" \) | grep -q .; then
  echo "⚠️ No Java source files found in any module. Skipping quality checks."
  exit 0
fi

# Checkstyle - Google style (expected config in a known location)
echo "🔍 Running Checkstyle..."
${GRADLEW:-./gradlew} checkstyleMain checkstyleTest --no-daemon

# PMD
echo "🧹 Running PMD..."
${GRADLEW:-./gradlew} pmdMain pmdTest --no-daemon

# SpotBugs
echo "🐞 Running SpotBugs..."
${GRADLEW:-./gradlew} spotbugsMain spotbugsTest --no-daemon

echo "✅ Quality checks completed successfully."
