#!/bin/bash
set -euo pipefail

# Resolve VERSION from (in order): env, gradle.properties, latest tag.
if [ -n "${VERSION:-}" ]; then
  echo "$VERSION"
  exit 0
fi

if [ -f "gradle.properties" ]; then
  V=$(grep -E '^version\s*=' gradle.properties | head -n1 | cut -d= -f2 | xargs)
  if [ -n "$V" ]; then
    echo "$V"
    exit 0
  fi
fi

if git rev-parse --git-dir > /dev/null 2>&1; then
  if TAG=$(git describe --tags --abbrev=0 2>/dev/null); then
    echo "$TAG" | sed 's/^v//'
    exit 0
  fi
fi

echo "Error: VERSION not found (env/gradle.properties/tag)" >&2
exit 1
