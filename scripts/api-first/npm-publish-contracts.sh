#!/usr/bin/env bash
set -euo pipefail

SPEC_PATH="${1:-}"
RELEASE_CHANNEL="${2:-SNAPSHOT}"   # SNAPSHOT|RELEASE
NPM_SCOPE="${3:-@wendara-org}"
NPM_REGISTRY="${4:-https://npm.pkg.github.com}"

if [[ -z "$SPEC_PATH" ]]; then
  echo "Usage: npm-publish-contracts.sh <specPath> <SNAPSHOT|RELEASE> [@scope] [registry]"
  exit 2
fi

if ! command -v yq >/dev/null 2>&1; then
  echo "❌ yq is required"
  exit 127
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "❌ npm is required"
  exit 127
fi

SPEC_DIR="$(dirname "$SPEC_PATH")"
META_PATH="${SPEC_DIR}/metadata.yml"

# Parse apiName/transport/apiVersion from: apis/<apiName>/<transport>/<apiVersion>/openapi.yaml
IFS='/' read -r _ API_NAME TRANSPORT API_VERSION _ <<< "$SPEC_PATH"
if [[ -z "${API_NAME:-}" || -z "${TRANSPORT:-}" || -z "${API_VERSION:-}" ]]; then
  echo "❌ Invalid spec path: $SPEC_PATH"
  exit 2
fi

# yq v4: do NOT use 'empty' (jq keyword). Use an empty string fallback instead.
BASE_VERSION="$(yq e -r '.info.version // ""' "$SPEC_PATH" 2>/dev/null || true)"
if [[ -z "$BASE_VERSION" ]]; then
  echo "❌ Cannot resolve .info.version from $SPEC_PATH"
  exit 2
fi

# ---- Metadata (fallback: new format .api.* first, then legacy flat keys) ----
PUBLISH="true"
ARTIFACT_ID=""
GROUP_ID=""

if [[ -f "$META_PATH" ]]; then
  # publish flag
  PUBLISH="$(yq e -r '.api.publish // .publish // true' "$META_PATH" 2>/dev/null || echo true)"

  # artifactId / groupId
  ARTIFACT_ID="$(yq e -r '.api.artifactId // .artifactId // ""' "$META_PATH" 2>/dev/null || echo "")"
  GROUP_ID="$(yq e -r '.api.groupId // .groupId // ""' "$META_PATH" 2>/dev/null || echo "")"
fi

if [[ "${PUBLISH}" != "true" ]]; then
  echo "⚠️ Skipping publish (publish=false) for '${SPEC_PATH}'"
  exit 0
fi

# Default artifactId if not provided (align with Maven artifactId convention in your org)
# Example: auth-api-v1
if [[ -z "${ARTIFACT_ID}" ]]; then
  ARTIFACT_ID="${API_NAME}-${API_VERSION}"
fi

# NPM package name = scope + artifactId (equivalent to Maven artifactId)
# NPM requires lowercase
PKG_NAME="${NPM_SCOPE}/$(echo "${ARTIFACT_ID}" | tr '[:upper:]' '[:lower:]')"

# NPM versions must be immutable.
# RELEASE: exact OpenAPI version (1.1.0)
# SNAPSHOT: unique pre-release (1.1.0-snapshot.<run_number>)
if [[ "${RELEASE_CHANNEL}" == "RELEASE" ]]; then
  NPM_VERSION="${BASE_VERSION}"
  DIST_TAG="latest"
else
  RUN="${GITHUB_RUN_NUMBER:-0}"
  NPM_VERSION="${BASE_VERSION}-snapshot.${RUN}"
  DIST_TAG="snapshot"
fi

# Stage
STAGE_ROOT="build/npm-stage"
PKG_DIR="${STAGE_ROOT}/${ARTIFACT_ID}"

rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"

# Copy everything from spec dir (openapi.yaml, metadata.yml, referenced files, etc.)
cp -R "${SPEC_DIR}/." "${PKG_DIR}/"

cat > "${PKG_DIR}/package.json" <<EOF
{
  "name": "${PKG_NAME}",
  "version": "${NPM_VERSION}",
  "description": "Wendara OpenAPI contracts: ${ARTIFACT_ID}",
  "files": ["**/*"],
  "main": "openapi.yaml",
  "license": "UNLICENSED",
  "publishConfig": {
    "registry": "${NPM_REGISTRY}"
  },
  "wendara": {
    "artifactId": "${ARTIFACT_ID}",
    "groupId": "${GROUP_ID}",
    "transport": "${TRANSPORT}",
    "apiName": "${API_NAME}",
    "apiVersion": "${API_VERSION}",
    "specPath": "${SPEC_PATH}"
  }
}
EOF

pushd "${PKG_DIR}" >/dev/null

# Ensure registry is set (defensive)
npm config set registry "${NPM_REGISTRY}" >/dev/null

# Avoid republish conflicts: if this exact version exists, skip.
# Note: this requires auth to the registry (NODE_AUTH_TOKEN set by workflow).
if npm view "${PKG_NAME}@${NPM_VERSION}" version >/dev/null 2>&1; then
  echo "⚠️ Skipping publish: ${PKG_NAME}@${NPM_VERSION} already exists"
  popd >/dev/null
  exit 0
fi

echo "📦 Publishing ${PKG_NAME}@${NPM_VERSION} (tag=${DIST_TAG}) from ${SPEC_DIR}"
npm publish --ignore-scripts --tag "${DIST_TAG}"

popd >/dev/null
