#!/usr/bin/env bash
set -euo pipefail

# Install reviewdog if not available
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b /usr/local/bin

# Install dependencies
npm ci || yarn install || pnpm i

# Type checking (optional, no inline feedback for now)
npm run typecheck || true  # or: tsc --noEmit

# ESLint via reviewdog
if npx eslint -f unix . | reviewdog -f=eslint -name="ESLint" -reporter=github-pr-check -level=warning -fail-on-error=false; then
  echo "✅ ESLint passed."
else
  echo "⚠️ ESLint found issues."
fi

# Unit tests (optional – doesn't annotate inline, just logs)
npm test -- --ci --reporters=default || true
