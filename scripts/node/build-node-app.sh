#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Running Node production build..."

if npm run | grep -q " build"; then
  echo "✅ Running 'npm run build'..."
  npm run build
else
  echo "⚠️  No 'build' script defined in package.json — skipping build"
fi
