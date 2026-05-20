#!/usr/bin/env bash
# Build a Vite/Node web app and validate dist output.
set -euo pipefail

WORKDIR="${1:-.}"
DIST_DIR="${2:-dist}"

cd "${WORKDIR}"

npm run build

if [[ ! -d "${DIST_DIR}" ]]; then
  echo "Error: build output directory '${DIST_DIR}' was not generated" >&2
  exit 1
fi

echo "Build OK: ${WORKDIR}/${DIST_DIR}"
