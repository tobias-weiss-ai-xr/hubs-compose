#!/bin/bash
# Verification script for hubs-client bind-mount entries in the live compose file.
#
# Verifies that /opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml defines
# bind-mount entries for BOTH patched client bundles under the hubs-client
# service volumes:
#   - index-19b3ec05dc199afecec2.js  (home-page index bundle — fallbackImages)
#   - hub-544153456e8422fbb129.js    (room hub bundle — fallbackImages + crash fixes)
#
# These bind-mounts override the built-in bundles in /code/dist/assets/js/ with
# the patched copies in /opt/git/hubs-client-assets/. Without them the branding
# fix (populated fallbackImages map) is not served, so the home-page logo <img>
# and hero background render empty/black.
#
# This is an OFFLINE file check — no network/curl needed. It reads the compose
# file and the source bundle files directly from disk with absolute paths.
#
# Run with: bash tests/verify-bind-mounts.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

set -uo pipefail

COMPOSE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"
ASSETS_DIR="/opt/git/hubs-client-assets"

INDEX_BUNDLE="index-19b3ec05dc199afecec2.js"
HUB_BUNDLE="hub-544153456e8422fbb129.js"

# Expected container-side mount targets (where the patched bundle overrides the
# built-in one inside the hubs-client container).
INDEX_TARGET="/code/dist/assets/js/${INDEX_BUNDLE}"
HUB_TARGET="/code/dist/assets/js/${HUB_BUNDLE}"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# ---------------------------------------------------------------------------
# extract_hubs_client_block
#
# Prints the hubs-client service block from the compose file: every line from
# `  hubs-client:` (2-space indent) up to — but not including — the next
# 2-space-indented service or any 0-indent top-level key (networks:/volumes:).
#
# This isolates the volumes: section so we only match mounts that belong to
# hubs-client (not hubs-admin, spoke, etc., which share /code but do NOT
# bind-mount these patched bundles).
#
# Pure bash (no awk/sed) — only depends on bash + grep per conventions.
# ---------------------------------------------------------------------------
extract_hubs_client_block() {
  local line in_block=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]{2}hubs-client:[[:space:]]*$ ]]; then
      in_block=1
      continue
    fi
    if [[ "$in_block" -eq 1 ]]; then
      # Next service: exactly 2-space indent followed by a letter (e.g. "  hubs-admin:").
      # Lines indented 4+ spaces (service properties) start with a space at pos 3, so
      # they do NOT match ^[[:space:]]{2}[A-Za-z].
      if [[ "$line" =~ ^[[:space:]]{2}[A-Za-z] ]]; then
        break
      fi
      # Top-level key (0 indent) such as networks: or volumes:.
      if [[ "$line" =~ ^[A-Za-z] ]]; then
        break
      fi
      printf '%s\n' "$line"
    fi
  done < "$COMPOSE"
}

echo "=========================================="
echo "Hubs-Client Bind-Mount Verification"
echo "  Compose: $COMPOSE"
echo "  Assets:  $ASSETS_DIR"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Compose file exists and is readable
# ---------------------------------------------------------------------------
echo -n "Test 1: compose file exists and is readable... "
if [[ -f "$COMPOSE" && -r "$COMPOSE" ]]; then
  pass "$COMPOSE"
else
  fail "compose file not found or not readable: $COMPOSE"
fi

# ---------------------------------------------------------------------------
# Extract the hubs-client service block once (empty if compose missing).
# ---------------------------------------------------------------------------
CLIENT_BLOCK=""
if [[ -r "$COMPOSE" ]]; then
  CLIENT_BLOCK="$(extract_hubs_client_block)"
fi

# ---------------------------------------------------------------------------
# Test 2: hubs-client service is defined
# ---------------------------------------------------------------------------
echo -n "Test 2: hubs-client service defined in compose... "
if [[ -n "$CLIENT_BLOCK" ]]; then
  pass "hubs-client service block found"
else
  fail "hubs-client service not found in compose"
fi

# ---------------------------------------------------------------------------
# Test 3: hubs-client has a volumes: section
# ---------------------------------------------------------------------------
echo -n "Test 3: hubs-client has a volumes: section... "
if grep -qE '^[[:space:]]{4}volumes:[[:space:]]*$' <<< "$CLIENT_BLOCK"; then
  pass "volumes: section present under hubs-client"
else
  fail "no volumes: section found under hubs-client"
fi

# ---------------------------------------------------------------------------
# Test 4: index bundle bind-mount present under hubs-client
#   Matches a YAML list item that mounts the patched index bundle from the
#   assets dir to the container's dist/assets/js path.
# ---------------------------------------------------------------------------
echo -n "Test 4: index bundle bind-mount under hubs-client... "
if grep -qE "^[[:space:]]*-[[:space:]]+/opt/git/hubs-client-assets/${INDEX_BUNDLE//./\\.}:${INDEX_TARGET//./\\.}" <<< "$CLIENT_BLOCK"; then
  pass "${ASSETS_DIR}/${INDEX_BUNDLE} -> ${INDEX_TARGET}"
else
  fail "bind-mount for ${INDEX_BUNDLE} not found under hubs-client volumes"
fi

# ---------------------------------------------------------------------------
# Test 5: hub bundle bind-mount present under hubs-client
# ---------------------------------------------------------------------------
echo -n "Test 5: hub bundle bind-mount under hubs-client... "
if grep -qE "^[[:space:]]*-[[:space:]]+/opt/git/hubs-client-assets/${HUB_BUNDLE//./\\.}:${HUB_TARGET//./\\.}" <<< "$CLIENT_BLOCK"; then
  pass "${ASSETS_DIR}/${HUB_BUNDLE} -> ${HUB_TARGET}"
else
  fail "bind-mount for ${HUB_BUNDLE} not found under hubs-client volumes"
fi

# ---------------------------------------------------------------------------
# Test 6: index bundle source file exists and is non-empty on disk
#   A bind-mount to a missing/empty source file would shadow the bundle with
#   nothing (or a directory), breaking the home page.
# ---------------------------------------------------------------------------
echo -n "Test 6: index bundle source file exists... "
if [[ -s "${ASSETS_DIR}/${INDEX_BUNDLE}" ]]; then
  pass "${ASSETS_DIR}/${INDEX_BUNDLE} (non-empty)"
else
  fail "source file missing or empty: ${ASSETS_DIR}/${INDEX_BUNDLE}"
fi

# ---------------------------------------------------------------------------
# Test 7: hub bundle source file exists and is non-empty on disk
# ---------------------------------------------------------------------------
echo -n "Test 7: hub bundle source file exists... "
if [[ -s "${ASSETS_DIR}/${HUB_BUNDLE}" ]]; then
  pass "${ASSETS_DIR}/${HUB_BUNDLE} (non-empty)"
else
  fail "source file missing or empty: ${ASSETS_DIR}/${HUB_BUNDLE}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
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
