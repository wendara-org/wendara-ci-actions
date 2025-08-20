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
./gradlew checkstyleMain checkstyleTest --no-daemon

# PMD
echo "🧹 Running PMD..."
./gradlew pmdMain pmdTest --no-daemon

# SpotBugs
echo "🐞 Running SpotBugs..."
./gradlew spotbugsMain spotbugsTest --no-daemon

# JaCoCo coverage (only for unit tests)
echo "📊 Generating JaCoCo coverage report..."
./gradlew jacocoTestReport --no-daemon

echo "✅ Quality checks completed successfully."
