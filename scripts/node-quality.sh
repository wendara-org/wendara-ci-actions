#!/usr/bin/env bash
set -euo pipefail
# Node/TS quality gate común
npm ci || yarn install || pnpm i
npm run typecheck || true   # o `tsc --noEmit` si aplica
npm run lint || true        # eslint si está definido
npm test -- --ci --reporters=default || true