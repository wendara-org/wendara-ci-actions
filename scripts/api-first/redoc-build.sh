#!/usr/bin/env bash
set -euo pipefail

# Build a static Redoc HTML for a given OpenAPI file.
# Usage: redoc-build.sh <openapi.yaml> <output.html>

SPEC="${1:?Missing spec}"
OUT="${2:?Missing output html}"

npx --yes redoc-cli@0.13.21 bundle "${SPEC}" -o "${OUT}" --options.hideDownloadButton --options.expandResponses=200,201,400,401,403,404
