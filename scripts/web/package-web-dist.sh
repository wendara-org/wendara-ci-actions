#!/usr/bin/env bash
# Package dist output into a versioned tarball.
set -euo pipefail

WORKDIR="${1:-.}"
DIST_DIR="${2:-dist}"
VERSION="${3:-}"
OUT_DIR="${4:-.artifacts}"

if [[ -z "${VERSION}" ]]; then
  echo "Error: VERSION is required" >&2
  exit 1
fi

cd "${WORKDIR}"

if [[ ! -d "${DIST_DIR}" ]]; then
  echo "Error: dist directory '${DIST_DIR}' does not exist" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

SAFE_VERSION="${VERSION//\//-}"
PKG_NAME="dist-${SAFE_VERSION}.tgz"
PKG_PATH="${OUT_DIR}/${PKG_NAME}"

# Store files with deterministic owner/group for reproducibility.
tar --sort=name --owner=0 --group=0 --numeric-owner -czf "${PKG_PATH}" -C "${DIST_DIR}" .

SHA_PATH="${PKG_PATH}.sha256"
sha256sum "${PKG_PATH}" | awk '{print $1}' > "${SHA_PATH}"

printf 'PACKAGE_PATH=%s\n' "${PKG_PATH}"
printf 'PACKAGE_NAME=%s\n' "${PKG_NAME}"
printf 'SHA256_PATH=%s\n' "${SHA_PATH}"
