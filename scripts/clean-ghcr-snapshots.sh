#!/bin/bash
set -euo pipefail

GH_OWNER="${GH_OWNER:-wendara-org}"
PACKAGE_NAME="${PACKAGE_NAME:?Missing PACKAGE_NAME}"
SNAPSHOT_VERSION="${SNAPSHOT_VERSION:?Missing SNAPSHOT_VERSION}"  # e.g. 1.2.0-SNAPSHOT
KEEP="${KEEP:-5}"

GH_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GH_TOKEN" ]; then
  echo "❌ GITHUB_TOKEN is not set"
  exit 1
fi

echo "▶ Cleaning old GHCR snapshot versions for '$PACKAGE_NAME'"
echo "   Keeping: '$KEEP' latest semver + current version: '$SNAPSHOT_VERSION'"

# Fetch versions
VERSIONS=$(curl -s -H "Authorization: Bearer $GH_TOKEN" \
  "https://api.github.com/orgs/$GH_OWNER/packages/container/$PACKAGE_NAME/versions?per_page=100")

# Build tag,id list
TAGS_AND_IDS=$(echo "$VERSIONS" | jq -r \
  '.[] | {id: .id, tags: .metadata.container.tags}
   | select(.tags != null)
   | .tags[] as $tag
   | select($tag | endswith("SNAPSHOT"))
   | "\($tag),\(.id)"')

if [ -z "$TAGS_AND_IDS" ]; then
  echo "⚠️ No SNAPSHOT tags found. Nothing to clean."
  exit 0
fi

# Extract and sort by semver (ignoring -SNAPSHOT)
mapfile -t SORTED <<< "$(echo "$TAGS_AND_IDS" \
  | grep -v "^$SNAPSHOT_VERSION," \
  | sed 's/-SNAPSHOT,//g' \
  | sort -V \
  | sed 's/$/-SNAPSHOT/')"

# Compute TO_KEEP and TO_DELETE
TO_KEEP=$(echo "${SORTED[@]}" | awk '{for(i=NF-'"$KEEP"'+1;i<=NF;++i) print $i}')
TO_DELETE=$(echo "${SORTED[@]}" | grep -vFf <(echo "$TO_KEEP"))

# Always preserve current version (redundant but safe)
TO_DELETE=$(echo "$TO_DELETE" | grep -v "^$SNAPSHOT_VERSION$" || true)

# 🔍 LOG: Full list
echo "📦 All snapshot versions (oldest → newest):"
for tag in "${SORTED[@]}"; do
  echo "   - '$tag'"
done

# 🔍 LOG: Preserved
echo "✅ Keeping:"
echo "$TO_KEEP" | sort -V | while read tag; do
  echo "   - '$tag'"
done
echo "   - '$SNAPSHOT_VERSION' (current)"

# 🔍 LOG: Deleted
if [ -z "$TO_DELETE" ]; then
  echo "🟢 No versions to delete."
  exit 0
fi

echo "🗑️ Deleting:"
for DELETE_TAG in $TO_DELETE; do
  DELETE_ID=$(echo "$TAGS_AND_IDS" | grep "^$DELETE_TAG," | cut -d',' -f2)
  if [ -n "$DELETE_ID" ]; then
    echo "   - '$DELETE_TAG' (ID: '$DELETE_ID')"
    curl -s -X DELETE \
      -H "Authorization: Bearer $GH_TOKEN" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/orgs/$GH_OWNER/packages/container/$PACKAGE_NAME/versions/$DELETE_ID"
  fi
done

echo "✅ GHCR snapshot cleanup complete."
