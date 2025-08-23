#!/usr/bin/env bash
# bump-gradle-version.sh
#
# Purpose:
#   Update the Gradle project version in `code/gradle.properties`
#   to the release version computed by semantic-release (main branch only).
#
# Usage:
#   bash scripts/bump-gradle-version.sh 1.2.3
#
# Notes:
#   - This script is idempotent: if `version = ...` exists, it replaces it;
#     otherwise it appends a new `version = ...` line at the end.
#   - It rejects pre-release identifiers on purpose (no "-rc", "-beta", etc.)
#     because only final releases should touch gradle.properties on `main`.

set -euo pipefail

NEW_VERSION="${1:-}"
PROP_FILE="code/gradle.properties"

# --- Validation --------------------------------------------------------------

if [[ -z "$NEW_VERSION" ]]; then
  echo "ERROR: Missing version argument. Example: 1.2.3" >&2
  exit 1
fi

# Reject pre-releases (e.g., 1.2.3-beta.1). main should only commit finals.
if [[ "$NEW_VERSION" == *-* ]]; then
  echo "ERROR: Pre-release detected ('$NEW_VERSION')." >&2
  echo "Only final versions (e.g., 1.2.3) should bump gradle.properties on main." >&2
  exit 1
fi

# Basic semver (major.minor.patch) check. Keep it simple on purpose.
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: Version '$NEW_VERSION' does not match SemVer 'X.Y.Z'." >&2
  exit 1
fi

# --- Ensure target file exists ----------------------------------------------

if [[ ! -f "$PROP_FILE" ]]; then
  echo "Creating $PROP_FILE ..."
  mkdir -p "$(dirname "$PROP_FILE")"
  echo "version = $NEW_VERSION" > "$PROP_FILE"
  echo "✅ Gradle version set to '$NEW_VERSION' in '$PROP_FILE'"
  exit 0
fi

# --- Update or append `version = ...` ---------------------------------------

# Portable replacement using awk (no GNU sed -i assumptions).
TMP_FILE="$(mktemp)"
awk -v ver="$NEW_VERSION" '
  BEGIN { updated=0 }
  {
    # Match lines like: version=..., version = ..., with or without spaces
    if ($0 ~ /^[[:space:]]*version[[:space:]]*=/) {
      print "version = " ver
      updated=1
    } else {
      print $0
    }
  }
  END {
    if (updated == 0) {
      print "version = " ver
    }
  }
' "$PROP_FILE" > "$TMP_FILE"

mv "$TMP_FILE" "$PROP_FILE"

echo "✅ Gradle version set to $NEW_VERSION in $PROP_FILE"
