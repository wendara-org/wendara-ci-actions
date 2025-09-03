#!/bin/bash
set -euo pipefail

GH_OWNER="${GH_OWNER:-wendara-org}"
PACKAGE_NAME="${PACKAGE_NAME:?Missing PACKAGE_NAME}"
SNAPSHOT_VERSION="${SNAPSHOT_VERSION:?Missing SNAPSHOT_VERSION}"  # e.g. 1.2.0-SNAPSHOT.1
KEEP="${KEEP:-5}"

GH_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GH_TOKEN" ]; then
  echo "❌ GITHUB_TOKEN is not set"
  exit 1
fi

echo "▶ Cleaning old GHCR snapshot versions for '$PACKAGE_NAME'"
echo "   Keeping: '$KEEP' latest semver + current version: '$SNAPSHOT_VERSION'"

# 1) Fetch versions
VERSIONS=$(curl -sS -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/$GH_OWNER/packages/container/$PACKAGE_NAME/versions?per_page=100")

# 2) Must be an array; otherwise show the API error and exit
if ! echo "$VERSIONS" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "❌ Unexpected response from GitHub API (not an array). Raw payload:"
  echo "$VERSIONS"
  exit 1
fi

# 3) Build tag→id mapping (only snapshot tags)
#    Snapshot regex: -SNAPSHOT or -SNAPSHOT.N (N>=0)
SNAPSHOT_RE='-SNAPSHOT(\.[0-9]+)?$'

# Array of "tag id"
mapfile -t TAG_ID_PAIRS < <(
  echo "$VERSIONS" | jq -r '
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

# 4) Build associative map tag→id and list of tags
declare -A TAG2ID=()
TAGS=()
for line in "${TAG_ID_PAIRS[@]}"; do
  tag="${line%% *}"
  id="${line#* }"
  TAG2ID["$tag"]="$id"
  TAGS+=("$tag")
done

# 5) Remove current from candidates (we always keep it)
CANDIDATES=()
for t in "${TAGS[@]}"; do
  if [[ "$t" != "$SNAPSHOT_VERSION" ]]; then
    CANDIDATES+=("$t")
  fi
done

# 6) Sort oldest→newest using -V
IFS=$'\n' SORTED=($(printf "%s\n" "${CANDIDATES[@]}" | sort -V)); unset IFS

echo "📦 All snapshot versions (oldest → newest):"
for t in "${SORTED[@]}"; do echo "   - '$t'"; done

# 7) Compute keep & delete
TO_KEEP=()
TO_DELETE=()

total=${#SORTED[@]}
if (( total > 0 )); then
  # last KEEP are kept
  start_keep=$(( total - KEEP ))
  (( start_keep < 0 )) && start_keep=0
  for i in $(seq 0 $((start_keep-1))); do TO_DELETE+=("${SORTED[$i]}"); done
  for i in $(seq $start_keep $((total-1))); do TO_KEEP+=("${SORTED[$i]}"); done
fi

echo "✅ Keeping:"
for t in "${TO_KEEP[@]}"; do echo "   - '$t'"; done
echo "   - '$SNAPSHOT_VERSION' (current)"

# 8) Final delete set (exclude current defensively)
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
  id="${TAG2ID[$tag]}"
  if [ -n "$id" ]; then
    echo "   - '$tag' (ID: '$id')"
    curl -sS -X DELETE \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/orgs/$GH_OWNER/packages/container/$PACKAGE_NAME/versions/$id" \
      >/dev/null
  else
    echo "   - '$tag' (ID not found) ⚠️"
  fi
done

echo "✅ GHCR snapshot cleanup complete."
