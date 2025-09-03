#!/bin/bash
# Clean old GHCR snapshot container versions for an organization package.
# - Treat 404 (package not found) as "nothing to clean" so first runs don't fail.
# - Supports snapshot tags: X.Y.Z-SNAPSHOT and X.Y.Z-SNAPSHOT.N
# - Keeps the latest KEEP snapshot tags + the current SNAPSHOT_VERSION.
# - Sorts versions using `sort -V`.
# - Paginates the GitHub API (per_page=100).
#

set -euo pipefail

GH_OWNER="${GH_OWNER:-wendara-org}"
PACKAGE_NAME="${PACKAGE_NAME:?Missing PACKAGE_NAME}"
SNAPSHOT_VERSION="${SNAPSHOT_VERSION:?Missing SNAPSHOT_VERSION}"  # e.g. 1.2.0-SNAPSHOT or 1.2.0-SNAPSHOT.3
KEEP="${KEEP:-5}"

GH_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GH_TOKEN" ]; then
  echo "❌ GITHUB_TOKEN is not set"
  exit 1
fi

echo "▶ Cleaning old GHCR snapshot versions for '$PACKAGE_NAME'"
echo "   Keeping: '$KEEP' latest semver + current version: '$SNAPSHOT_VERSION'"

API_BASE="https://api.github.com/orgs/${GH_OWNER}/packages/container/${PACKAGE_NAME}/versions"

# ---- Fetch and paginate all versions ----
# Accumulate pages into a single JSON array in VERSIONS_ALL.
VERSIONS_ALL='[]'
page=1

while :; do
  HTTP_CODE=$(curl -sS -o /tmp/ghcr_versions_page.json -w "%{http_code}" \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "${API_BASE}?per_page=100&page=${page}")

  # First-time runs or no package visible: treat as nothing to clean.
  if [ "$HTTP_CODE" = "404" ]; then
    echo "ℹ️ GHCR package not found (yet) or not accessible. Assuming no snapshots to clean."
    exit 0
  fi

  if [ "$HTTP_CODE" -ge 400 ]; then
    echo "❌ Unexpected response ($HTTP_CODE) from GitHub API:"
    cat /tmp/ghcr_versions_page.json
    exit 1
  fi

  # Validate array payload
  if ! jq -e 'type == "array"' >/dev/null 2>&1 < /tmp/ghcr_versions_page.json; then
    echo "❌ Unexpected payload (not an array):"
    cat /tmp/ghcr_versions_page.json
    exit 1
  fi

  # Merge page into accumulator
  VERSIONS_ALL=$(jq -s 'add' <(echo "${VERSIONS_ALL}") /tmp/ghcr_versions_page.json)

  # If returned less than 100 items, last page reached
  PAGE_LEN=$(jq 'length' /tmp/ghcr_versions_page.json)
  if [ "$PAGE_LEN" -lt 100 ]; then
    break
  fi

  page=$((page + 1))
done

# If still empty after pagination, nothing to do
if [ "$(echo "$VERSIONS_ALL" | jq 'length')" -eq 0 ]; then
  echo "⚠️ No versions found. Nothing to clean."
  exit 0
fi

# ---- Build tag→id mapping for snapshot tags ----
# Snapshot regex: -SNAPSHOT or -SNAPSHOT.N
SNAPSHOT_RE='-SNAPSHOT(\.[0-9]+)?$'

# Create an array of "tag id"
mapfile -t TAG_ID_PAIRS < <(
  echo "$VERSIONS_ALL" | jq -r '
    .[] as $v
    | ($v.metadata.container.tags // [])
    | .[]
    | select(test("'"$SNAPSHOT_RE"'"))
    | "\(.) \($v.id)"
  '
)

if [ ${#TAG_ID_PAIRS[@]} -eq 0 ]; then
  echo "⚠️ No SNAPSHOT tags found. Nothing to clean."
  exit 0
fi

# Build associative map: tag -> id, and a flat list of tags
declare -A TAG2ID=()
TAGS=()
for pair in "${TAG_ID_PAIRS[@]}"; do
  tag="${pair%% *}"
  id="${pair#* }"
  TAG2ID["$tag"]="$id"
  TAGS+=("$tag")
done

# Exclude current snapshot version from deletion candidates
CANDIDATES=()
for t in "${TAGS[@]}"; do
  if [[ "$t" != "$SNAPSHOT_VERSION" ]]; then
    CANDIDATES+=("$t")
  fi
done

# Sort oldest → newest
if [ ${#CANDIDATES[@]} -eq 0 ]; then
  echo "🟢 Only current snapshot is present. Nothing to delete."
  exit 0
fi

IFS=$'\n' SORTED=($(printf "%s\n" "${CANDIDATES[@]}" | sort -V)); unset IFS

echo "📦 All snapshot versions (oldest → newest):"
for t in "${SORTED[@]}"; do
  echo "   - '$t'"
done

# Compute sets to keep/delete: keep last KEEP, delete the rest (excluding current)
TO_KEEP=()
TO_DELETE=()

total=${#SORTED[@]}
start_keep=$(( total - KEEP ))
(( start_keep < 0 )) && start_keep=0

# Older than "start_keep" → delete
for i in $(seq 0 $((start_keep-1))); do
  TO_DELETE+=("${SORTED[$i]}")
done
# From "start_keep" to end → keep
for i in $(seq $start_keep $((total-1))); do
  TO_KEEP+=("${SORTED[$i]}")
done

echo "✅ Keeping:"
for t in "${TO_KEEP[@]}"; do
  echo "   - '$t'"
done
echo "   - '$SNAPSHOT_VERSION' (current)"

# Final delete list (defensive exclude of current)
FINAL_DELETE=()
for t in "${TO_DELETE[@]}"; do
  [[ "$t" == "$SNAPSHOT_VERSION" ]] && continue
  FINAL_DELETE+=("$t")
done

if [ ${#FINAL_DELETE[@]} -eq 0 ]; then
  echo "🟢 No versions to delete."
  exit 0
fi

echo "🗑️ Deleting:"
for tag in "${FINAL_DELETE[@]}"; do
  id="${TAG2ID[$tag]:-}"
  if [ -n "$id" ]; then
    echo "   - '$tag' (ID: '$id')"
    curl -sS -X DELETE \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "${API_BASE}/${id}" \
      >/dev/null
  else
    echo "   - '$tag' (ID not found) ⚠️"
  fi
done

echo "✅ GHCR snapshot cleanup complete."
