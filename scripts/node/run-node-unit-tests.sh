#!/usr/bin/env bash
set -euo pipefail

echo "🧪 Running Node unit tests..."

if [ -f "jest.config.js" ] || [ -f "jest.config.ts" ] || [ -f "vitest.config.ts" ]; then
  if npx --yes vitest --version &>/dev/null; then
    echo "✅ Detected Vitest — running tests..."
    npx vitest run
  else
    echo "✅ Detected Jest — running tests..."
    npx jest --ci
  fi
else
  echo "⚠️  No test config found — skipping tests"
fi
