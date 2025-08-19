#!/usr/bin/env bash
set -euo pipefail

# --- Purpose ---------------------------------------------------------------
# Generate a Markdown changelog for all changed OpenAPI specs between two refs.
# Uses Tufin oasdiff "changelog" to summarize API changes (breaking/non-breaking).
#
# Usage:
#   oasdiff-changelog.sh <base_ref> <head_ref> <output_file>
# Example:
#   oasdiff-changelog.sh origin/main HEAD CHANGELOG.md
# --------------------------------------------------------------------------

BASE_REF="${1:?Missing base ref}"
HEAD_REF="${2:?Missing head ref}"
OUT_FILE="${3:?Missing output file}"

# Start/overwrite file
echo "# API Changelog" > "$OUT_FILE"
echo "" >> "$OUT_FILE"
echo "_Generated from OpenAPI diffs between **${BASE_REF}** and **${HEAD_REF}**._" >> "$OUT_FILE"
echo "" >> "$OUT_FILE"

# Find changed specs
CHANGED=$(git diff --name-only "${BASE_REF}" "${HEAD_REF}" -- "apis/*/*/*/openapi.@(yaml|yml)" || true)
if [[ -z "${CHANGED}" ]]; then
  echo "No OpenAPI changes detected." >> "$OUT_FILE"
  exit 0
fi

# Run oasdiff changelog per spec
for SPEC in ${CHANGED}; do
  API_DIR="$(dirname "${SPEC}")"
  echo "## ${API_DIR}" >> "$OUT_FILE"
  echo "" >> "$OUT_FILE"
  set +e
  docker run --rm -v "$PWD":/work -w /work quay.io/tufin/oasdiff:v1.11.6 \
    changelog "${BASE_REF}:${SPEC}" "${HEAD_REF}:${SPEC}" >> "$OUT_FILE" 2>/dev/null
  CODE=$?
  set -e
  echo "" >> "$OUT_FILE"
  if [[ $CODE -ne 0 ]]; then
    echo "> _Failed to generate changelog for '${SPEC}' (code '${CODE}')._" >> "$OUT_FILE"
    echo "" >> "$OUT_FILE"
  fi
done
