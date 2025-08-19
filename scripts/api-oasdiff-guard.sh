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
#  - Docker available to run Tufin oasdiff (quay.io/tufin/oasdiff)
#
# Usage:
#  api-oasdiff-guard.sh <base_ref> <head_ref> <spec_path>
# Example:
#  api-oasdiff-guard.sh origin/main HEAD apis/emotion-journal/openapi.yaml
# --------------------------------------------------------------------------

BASE_REF="${1:?Missing base ref}"
HEAD_REF="${2:?Missing head ref}"
SPEC_PATH="${3:?Missing spec path}"

# Resolve temporary copies of base and head specs
mkdir -p .oasguard
BASE_FILE=".oasguard/base.yaml"
HEAD_FILE=".oasguard/head.yaml"

git show "${BASE_REF}:${SPEC_PATH}" > "${BASE_FILE}" || {
  echo "::warning title=Base spec missing::Could not read '${SPEC_PATH}' at '${BASE_REF}'. Treating as new API."
  # For new APIs require MINOR or MAJOR (not PATCH). We'll enforce MINOR+.
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

read -r BASE_M BASE_m BASE_p <<< "$(semver_parts "${BASE_VERSION}")"
read -r HEAD_M HEAD_m HEAD_p <<< "$(semver_parts "${HEAD_VERSION}")"

# Run oasdiff to detect breaking changes (exit code 2 -> breaking)
# https://github.com/Tufin/oasdiff
DIFF_OUT=".oasguard/diff.txt"
set +e
oasdiff breaking "${BASE_FILE}" "${HEAD_FILE}" --fail-on-diff > "${DIFF_OUT}" 2>&1
OAS_CODE=$?
set -e

# Classify required bump
REQUIRED="patch"
if [[ "${NEW_API:-false}" == "true" ]]; then
  REQUIRED="minor"
elif [[ ${OAS_CODE} -eq 2 ]]; then
  REQUIRED="major"
elif [[ ${OAS_CODE} -eq 0 ]]; then
  # no diff at all
  REQUIRED="none"
elif [[ ${OAS_CODE} -eq 3 || ${OAS_CODE} -eq 1 ]]; then
  # non-breaking diffs (added endpoints, etc.)
  REQUIRED="minor"
else
  echo "::error title=oasdiff execution failed::Exit code '${OAS_CODE}'. Output follows:"
  sed -n '1,200p' "${DIFF_OUT}"
  exit 1
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

echo "Base version: ${BASE_VERSION}"
echo "Head version: ${HEAD_VERSION}"
echo "Required bump: ${REQUIRED}"

if ! $ok; then
  echo "::error title=Semantic version guard failed::Required '${REQUIRED}' bump not satisfied by '${HEAD_VERSION}' (base '${BASE_VERSION}')."
  echo "---- oasdiff (breaking) summary ----"
  sed -n '1,200p' "${DIFF_OUT}" || true
  exit 1
fi
