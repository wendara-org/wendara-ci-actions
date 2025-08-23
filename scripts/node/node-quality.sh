#!/usr/bin/env bash
set -euo pipefail

echo "🔎 Running Node quality checks..."

if [ -f "tsconfig.json" ]; then
  echo "✅ Running TypeScript check..."
  npx tsc --noEmit
else
  echo "⚠️  No tsconfig.json found — skipping TypeScript check"
fi

if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.cjs" ] || [ -f ".eslintrc.json" ]; then
  echo "✅ Running ESLint..."
  npx eslint . --ext .ts,.tsx,.js,.jsx
else
  echo "⚠️  No ESLint config found — skipping ESLint"
fi
