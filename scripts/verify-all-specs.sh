#!/usr/bin/env bash
set -euo pipefail

# Validate all OpenAPI specs in the repository:
# - Lint using Redocly
# - Check that info.version exists and is not null
# - Report issues as PR annotations via reviewdog

echo "🔍 Scanning for OpenAPI specs..."

SPECS=$(find apis -type f -name "openapi.yaml" | sort)

if [[ -z "$SPECS" ]]; then
  echo "::warning title=No specs found::No openapi.yaml files detected"
  exit 0
fi

# Install tools
npm i -g @redocly/cli@1 > /dev/null
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /usr/local/bin

# Run Redocly lint through reviewdog
for spec in $SPECS; do
  echo "🔍 Linting $spec..."
  redocly lint "$spec" 2>&1 | \
    sed "s|^|$spec: |" | \
    reviewdog -efm="%f: %m" \
      -name="Redocly Lint" \
      -reporter=github-pr-check \
      -level=error \
      -fail-on-error=true
done

# Check info.version explicitly
for spec in $SPECS; do
  version=$(yq '.info.version' "$spec")
  if [[ -z "$version" || "$version" == "null" ]]; then
    echo "$spec:1 Missing 'info.version'" | \
    reviewdog -efm="%f:%l %m" \
      -name="Version Check" \
      -reporter=github-pr-check \
      -level=error \
      -fail-on-error=true
  fi
done

echo "✅ All specs passed validation."
