#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${RELEASE_TAG:?RELEASE_TAG is required}"
: "${RELEASE_NOTES_FILE:?RELEASE_NOTES_FILE is required}"
: "${RELEASE_ASSET_DIR:?RELEASE_ASSET_DIR is required}"
: "${IS_STABLE:?IS_STABLE is required}"

retry() {
  local attempt=1
  local max_attempts=4
  local delay=5

  until "$@"; do
    if (( attempt >= max_attempts )); then
      echo "Command failed after ${attempt} attempts: $1" >&2
      return 1
    fi
    echo "Attempt ${attempt} failed for $1; retrying in ${delay}s..." >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

release_json=$(mktemp)
trap 'rm -f "$release_json"' EXIT

if gh release view "$RELEASE_TAG" \
  --repo "$GITHUB_REPOSITORY" \
  --json isDraft \
  >"$release_json" 2>/dev/null; then
  if [ "$(jq -r '.isDraft' "$release_json")" != "true" ]; then
    echo "Release $RELEASE_TAG is already published; leaving it unchanged."
    exit 0
  fi
  echo "Resuming draft release $RELEASE_TAG."
else
  create_args=(
    release create "$RELEASE_TAG"
    --repo "$GITHUB_REPOSITORY"
    --draft
    --verify-tag
    --title "$RELEASE_TAG"
    --notes-file "$RELEASE_NOTES_FILE"
  )
  if [ "$IS_STABLE" != "true" ]; then
    create_args+=(--prerelease)
  fi
  retry gh "${create_args[@]}"
fi

mapfile -d '' assets < <(
  find "$RELEASE_ASSET_DIR" -maxdepth 1 -type f -print0 | sort -z
)
if (( ${#assets[@]} == 0 )); then
  echo "No release assets found in $RELEASE_ASSET_DIR." >&2
  exit 1
fi

remote_asset_size() {
  local asset_name=$1
  gh release view "$RELEASE_TAG" \
    --repo "$GITHUB_REPOSITORY" \
    --json assets \
    | jq -r --arg name "$asset_name" \
      '.assets[] | select(.name == $name) | .size' \
    | tail -n 1
}

for asset in "${assets[@]}"; do
  asset_name=$(basename "$asset")
  local_size=$(stat -c '%s' "$asset")
  existing_size=$(remote_asset_size "$asset_name")

  if [ "$existing_size" = "$local_size" ]; then
    echo "Asset $asset_name is already uploaded and verified."
    continue
  fi

  retry gh release upload "$RELEASE_TAG" "$asset" \
    --repo "$GITHUB_REPOSITORY" \
    --clobber

  uploaded_size=$(remote_asset_size "$asset_name")
  if [ "$uploaded_size" != "$local_size" ]; then
    echo "Uploaded asset size mismatch for $asset_name." >&2
    exit 1
  fi
done

edit_args=(
  release edit "$RELEASE_TAG"
  --repo "$GITHUB_REPOSITORY"
  --draft=false
  --notes-file "$RELEASE_NOTES_FILE"
)
if [ "$IS_STABLE" = "true" ]; then
  edit_args+=(--prerelease=false --latest)
else
  edit_args+=(--prerelease --latest=false)
fi
retry gh "${edit_args[@]}"

echo "Release $RELEASE_TAG published successfully."
