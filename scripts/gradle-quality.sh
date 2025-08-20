#!/usr/bin/env bash
set -euo pipefail

# Install reviewdog if not available
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /usr/local/bin

# Clean and build with test and quality plugins
./gradlew clean build test jacocoTestReport \
  checkstyleMain checkstyleTest \
  spotbugsMain spotbugsTest \
  pmdMain pmdTest

# Checkstyle
find . -name 'checkstyle-result.xml' | while read -r file; do
  cat "$file" | reviewdog -f=checkstyle \
    -name="Checkstyle" \
    -reporter=github-pr-check \
    -level=error \
    -fail-on-error=true
done

# SpotBugs
find . -name 'spotbugsXml.xml' | while read -r file; do
  cat "$file" | reviewdog -f=spotbugs \
    -name="SpotBugs" \
    -reporter=github-pr-check \
    -level=warning \
    -fail-on-error=false
done

# PMD
find . -name 'pmd.xml' | while read -r file; do
  cat "$file" | reviewdog -f=pmd \
    -name="PMD" \
    -reporter=github-pr-check \
    -level=warning \
    -fail-on-error=false
done
