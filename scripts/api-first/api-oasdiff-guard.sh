#!/usr/bin/env bash
set -euo pipefail

# --- Purpose ---------------------------------------------------------------
# Validate that the new OpenAPI version bump matches the actual diff:
# - If breaking changes -> require MAJOR bump
# - If non-breaking (but changes) -> require MINOR bump
# - If only documentation/patch-level changes -> allow PATCH
#
# Requires:
#  - yq (mikefarah) to read YAML
#  - oasdiff installed as a CLI binary in the runner (not Docker)
#
# Usage:
#  api-oasdiff-guard.sh <base_ref> <head_ref> <spec_path>
# Example:
#  api-oasdiff-guard.sh origin/main HEAD apis/emotion-journal/openapi.yaml
# --------------------------------------------------------------------------

BASE_REF="${1:?Missing base ref}"
HEAD_REF="${2:?Missing head ref}"
SPEC_PATH="${3:?Missing spec path}"

# Ensure required binaries exist early and fail fast.
command -v oasdiff >/dev/null || { echo "::error::oasdiff not found"; exit 127; }
command -v yq >/dev/null || { echo "::error::yq not found"; exit 127; }

# Pass token for reviewdog when running in reusable workflows.
export REVIEWDOG_GITHUB_API_TOKEN="${REVIEWDOG_GITHUB_API_TOKEN:-${GITHUB_TOKEN:-}}"

# sanity: oasdiff must be a binary
file "$(command -v oasdiff)" | grep -qi 'text' && { echo "::error::Invalid oasdiff binary (looks like text/HTML)"; exit 127; }

# Resolve temporary copies of base and head specs
mkdir -p .oasguard
BASE_FILE=".oasguard/base.yaml"
HEAD_FILE=".oasguard/head.yaml"

# Check if spec exists in base branch
if ! git ls-tree -r "${BASE_REF}" --name-only | grep -q "^${SPEC_PATH}$"; then
  echo "::notice title=New API::Spec '${SPEC_PATH}' does not exist in '${BASE_REF}'. Skipping semantic diff check."
  exit 0
fi

git show "${BASE_REF}:${SPEC_PATH}" > "${BASE_FILE}" || {
  echo "::warning title=Base spec missing::Could not read '${SPEC_PATH}' at '${BASE_REF}'."
  BASE_VERSION="0.0.0"
  NEW_API=true
}
if [[ -f "${SPEC_PATH}" ]]; then
  cp "${SPEC_PATH}" "${HEAD_FILE}"
else
  echo "::error title=Head spec missing::'${SPEC_PATH}' not found in HEAD."
  exit 1
fi

# Read versions
if [[ "${NEW_API:-false}" != "true" ]]; then
  BASE_VERSION="$(yq '.info.version' "${BASE_FILE}")"
fi
HEAD_VERSION="$(yq '.info.version' "${HEAD_FILE}")"

if [[ -z "${HEAD_VERSION}" || "${HEAD_VERSION}" == "null" ]]; then
  echo "::error title=Missing version::info.version is missing in head spec."
  exit 1
fi

# Helper: semver parts
semver_parts() {
  local v="${1}"
  v="${v#v}"
  v="${v%%-*}" # strip pre-release e.g., -SNAPSHOT
  IFS='.' read -r MA MI PA <<< "${v}"
  echo "${MA:-0} ${MI:-0} ${PA:-0}"
}

read -r BASE_M BASE_m BASE_p <<< "$(semver_parts "${BASE_VERSION:-0.0.0}")"
read -r HEAD_M HEAD_m HEAD_p <<< "$(semver_parts "${HEAD_VERSION}")"

# Run oasdiff v1 to detect breaking changes.
# v1 does not support --fail-on-diff; instead, we use `--fail-on ERR` to exit(1) on breaking.
DIFF_OUT=".oasguard/breaking.out"
set +e
oasdiff breaking "${BASE_FILE}" "${HEAD_FILE}" --format text --fail-on ERR > "${DIFF_OUT}" 2>&1
OAS_CODE=$?
set -e

# Classify required bump (pragmatic policy for v1 CLI)
REQUIRED="patch"
if [[ "${NEW_API:-false}" == "true" ]]; then
  REQUIRED="minor"
elif [[ ${OAS_CODE} -eq 1 ]]; then
  # oasdiff exited with error level due to breaking changes
  REQUIRED="major"
else
  # No breaking changes; detect "any change" vs "no change".
  # We fallback to a byte-level comparison (semantic-only would need extra tooling).
  if cmp -s "${BASE_FILE}" "${HEAD_FILE}"; then
    REQUIRED="none"
  else
    REQUIRED="minor"
  fi
fi

# Validate bump policy
ok=false
if [[ "${REQUIRED}" == "none" ]]; then
  ok=true
elif [[ "${REQUIRED}" == "major" && ${HEAD_M} -gt ${BASE_M} ]]; then
  ok=true
elif [[ "${REQUIRED}" == "minor" && ( ${HEAD_M} -gt ${BASE_M} || ( ${HEAD_M} -eq ${BASE_M} && ${HEAD_m} -gt ${BASE_m} ) ) ]]; then
  ok=true
elif [[ "${REQUIRED}" == "patch" && ( ${HEAD_M} -gt ${BASE_M} || ( ${HEAD_M} -eq ${BASE_M} && ( ${HEAD_m} -gt ${BASE_m} || ( ${HEAD_m} -eq ${BASE_m} && ${HEAD_p} -gt ${BASE_p} ) ) ) ) ]]; then
  ok=true
fi

echo "Base version: ${BASE_VERSION:-0.0.0}"
echo "Head version: ${HEAD_VERSION}"
echo "Required bump: ${REQUIRED}"

if ! $ok; then
  echo "$SPEC_PATH:1 Required '${REQUIRED}' version bump not satisfied by '${HEAD_VERSION}' (base: '${BASE_VERSION:-0.0.0}')" | \
  reviewdog -efm="%f:%l %m" \
    -name="OASDiff Guard" \
    -reporter=github-pr-check \
    -level=error \
    -fail-on-error=true

  echo "---- oasdiff (breaking) summary ----"
  sed -n '1,200p' "${DIFF_OUT}" || true
  exit 1
fi
