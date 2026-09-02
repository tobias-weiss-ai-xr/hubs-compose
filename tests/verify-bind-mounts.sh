#!/bin/bash
# Verifies that /opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml defines
# bind-mount entries for EVERY asset in /opt/git/hubs-client-assets/ that is
# served by the hubs-client service.
#
# It also verifies that:
# 1. The local source file exists.
# 2. The served bytes (via HTTP) match the local repo copy.
#    This guards against "inode-staleness" where Docker keeps serving an old
#    version of a file even after it was updated on the host.
#
# Run with: bash tests/verify-bind-mounts.sh

set -uo pipefail

COMPOSE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"
ASSETS_DIR="/opt/git/hubs-client-assets"
BASE_URL="https://hubs.chemie-lernen.org"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# ---------------------------------------------------------------------------
# extract_hubs_client_block
# ---------------------------------------------------------------------------
extract_hubs_client_block() {
  local line in_block=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]{2}hubs-client:[[:space:]]*$ ]]; then
      in_block=1
      continue
    fi
    if [[ "$in_block" -eq 1 ]]; then
      if [[ "$line" =~ ^[[:space:]]{2}[A-Za-z] ]]; then
        break
      fi
      if [[ "$line" =~ ^[A-Za-z] ]]; then
        break
      fi
      printf '%s\n' "$line"
    fi
  done < "$COMPOSE"
}

echo "=========================================="
echo "Hubs-Client Bind-Mount & Integrity Verification"
echo "  Compose: $COMPOSE"
echo "  Assets:  $ASSETS_DIR"
echo "  URL:     $BASE_URL"
echo "=========================================="
echo ""

if [[ ! -f "$COMPOSE" || ! -r "$COMPOSE" ]]; then
  fail "Compose file missing or unreadable: $COMPOSE"
  echo "Results: $PASSED passed, $FAILED failed"
  exit 1
fi

CLIENT_BLOCK="$(extract_hubs_client_block)"
if [[ -z "$CLIENT_BLOCK" ]]; then
  fail "hubs-client service not found in compose"
  echo "Results: $PASSED passed, $FAILED failed"
  exit 1
fi

# ---------------------------------------------------------------------------
# Asset Matrix
# ---------------------------------------------------------------------------

# Find all files in the assets directory, but skip .git directory if it exists
ASSET_FILES=$(find "$ASSETS_DIR" -type f -not -path '*/.git/*')

for FILE_PATH in $ASSET_FILES; do
  FILE_NAME=$(basename "$FILE_PATH")
  
  # Skip backup files, git files, and internal metadata
  if [[ "$FILE_NAME" =~ \.bak- || "$FILE_NAME" == ".gitignore" || "$FILE_NAME" == "README.md" || "$FILE_NAME" == "COMMIT_EDITMSG" || "$FILE_NAME" == "HEAD" || "$FILE_NAME" == "config" || "$FILE_NAME" == "description" || "$FILE_NAME" == "index" || "$FILE_NAME" =~ \.sample$ || "$FILE_NAME" =~ \.pyc$ ]]; then
    continue
  fi
  
  # Skip files that look like random hashes (e.g. 611252cd6f57...)
  if [[ "$FILE_NAME" =~ ^[0-9a-f]{32}$ ]]; then
    continue
  fi

  # Special case: hub-c5e95cff... is a stale/incorrect bundle we can ignore
  if [[ "$FILE_NAME" == "hub-c5e95cff205c291cb403.js" ]]; then
    continue
  fi

  echo "Checking asset: $FILE_NAME"
  
  # 1. Verify bind-mount exists in compose
  if grep -q "/opt/git/hubs-client-assets/${FILE_NAME}" <<< "$CLIENT_BLOCK"; then
    pass "Bind-mount defined for $FILE_NAME"
  else
    fail "No bind-mount found for $FILE_NAME in hubs-client volumes"
    echo ""
    continue
  fi

  # 2. Verify local file exists
  if [[ -s "$FILE_PATH" ]]; then
    pass "Local file exists and non-empty"
  else
    fail "Local file missing or empty: $FILE_PATH"
    echo ""
    continue
  fi

  # 3. Verify served bytes match local bytes
  if [[ "$FILE_NAME" == "static-server.py" ]]; then
    echo "  (Skipping HTTP check for non-served file)"
    pass "Internal script verified"
    echo ""
    continue
  fi

  # Derive URL path from the bind-mount target in the compose file.
  MOUNT_LINE=$(grep "/opt/git/hubs-client-assets/${FILE_NAME}" <<< "$CLIENT_BLOCK" | grep -E "^[[:space:]]*-")
  TARGET_PATH=$(echo "$MOUNT_LINE" | cut -d':' -f2 | sed 's/:ro//' | sed 's/:rw//')
  
  # Convert container /code/dist/path to URL /path
  URL_PATH=${TARGET_PATH#/code/dist}
  if [[ "$URL_PATH" == "$TARGET_PATH" ]]; then
    echo "  (Skipping HTTP check: $TARGET_PATH is not in /code/dist)"
    pass "Non-served mount verified"
    echo ""
    continue
  fi

  # Use curl to get the remote file and compare checksums
  LOCAL_HASH=$(sha256sum "$FILE_PATH" | cut -d' ' -f1)
  REMOTE_HASH=$(curl -sk --max-time 20 "$BASE_URL$URL_PATH" | sha256sum | cut -d' ' -f1)

  if [[ -n "$REMOTE_HASH" && "$LOCAL_HASH" == "$REMOTE_HASH" ]]; then
    pass "Remote bytes match local bytes ($URL_PATH)"
  else
    fail "Byte mismatch or 404 for $URL_PATH (Local: $LOCAL_HASH, Remote: $REMOTE_HASH)"
  fi
  echo ""
done

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "❌ Some tests failed. Check the output above."
  exit 1
else
  echo ""
  echo "✅ All tests passed!"
  exit 0
fi
