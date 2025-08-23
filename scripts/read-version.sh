#!/usr/bin/env bash
# scripts/read-version.sh
#
# Purpose:
#   Resolve the build VERSION in this order:
#     1) Explicit env VERSION (highest priority)
#     2) If RELEASE_CHANNEL == develop -> latest git tag (pre-release allowed)
#     3) Gradle property from code/gradle.properties
#     4) Gradle property from ./gradle.properties (root) – fallback
#     5) Latest git tag (strip leading 'v' if present)
#
# Why:
#   - On 'main' we persist the final version in code/gradle.properties (via semantic-release),
#     so we want to read from gradle.properties first.
#   - On 'develop' we DO NOT touch gradle.properties; we publish pre-release tags.
#     For builds on develop we prefer the latest tag (e.g., 1.2.0-develop.1).
#
# Notes:
#   - Ensure the workflow checks out with fetch-depth: 0 or fetches tags before calling this script.
#   - You can pass RELEASE_CHANNEL=develop|main from the workflow inputs.

set -euo pipefail

# --- 0) Explicit env VERSION --------------------------------------------------
if [[ -n "${VERSION:-}" ]]; then
  echo "${VERSION}"
  exit 0
fi

# Helper: print latest tag without leading 'v'
read_latest_tag_version() {
  # make sure tags are available
  if git rev-parse --git-dir > /dev/null 2>&1; then
    # best effort to ensure tags exist in shallow clones
    git fetch --tags --force --quiet || true
    if TAG="$(git describe --tags --abbrev=0 2>/dev/null)"; then
      echo "${TAG#v}"
      return 0
    fi
  fi
  return 1
}

# --- 1) If develop channel -> prefer latest tag -------------------------------
CHANNEL="${RELEASE_CHANNEL:-}"
if [[ "${CHANNEL}" == "develop" ]]; then
  if V_FROM_TAG="$(read_latest_tag_version)"; then
    echo "${V_FROM_TAG}"
    exit 0
  fi
  # If no tags found, fall through to other strategies.
fi

# --- 2) Try Gradle properties (main prefers persisted version) ----------------
if [[ -f "code/gradle.properties" ]]; then
  if V=$(grep -E '^[[:space:]]*version[[:space:]]*=' code/gradle.properties | head -n1 | cut -d= -f2- | xargs); then
    if [[ -n "$V" ]]; then
      echo "$V"
      exit 0
    fi
  fi
fi

if [[ -f "gradle.properties" ]]; then
  if V=$(grep -E '^[[:space:]]*version[[:space:]]*=' gradle.properties | head -n1 | cut -d= -f2- | xargs); then
    if [[ -n "$V" ]]; then
      echo "$V"
      exit 0
    fi
  fi
fi

# --- 3) Fallback: latest tag --------------------------------------------------
if V_FROM_TAG="$(read_latest_tag_version)"; then
  echo "${V_FROM_TAG}"
  exit 0
fi

echo "Error: VERSION not found (env/RELEASE_CHANNEL/gradle.properties/tag)" >&2
exit 1
