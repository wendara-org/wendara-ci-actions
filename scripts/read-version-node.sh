#!/usr/bin/env bash
# scripts/read-version-node.sh
#
# Purpose:
#   Read the app version for Node/ReactNative projects.
# Order:
#   1) env VERSION
#   2) package.json "version"
#   3) latest git tag (strip leading v)
set -euo pipefail

if [[ -n "${VERSION:-}" ]]; then
  echo "${VERSION}"
  exit 0
fi

if [[ -f "package.json" ]]; then
  node -p "require('./package.json').version" 2>/dev/null && exit 0 || true
fi

if git rev-parse --git-dir > /dev/null 2>&1; then
  git fetch --tags --force --quiet || true
  if TAG="$(git describe --tags --abbrev=0 2>/dev/null)"; then
    echo "${TAG#v}"
    exit 0
  fi
fi

echo "Error: VERSION not found (env/package.json/tag)" >&2
exit 1
