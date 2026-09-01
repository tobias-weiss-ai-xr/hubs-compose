#!/bin/bash
# Regression test: the EMPTY fallbackImages patterns must NOT be present in
# the LIVE bundles served from https://hubs.chemie-lernen.org/assets/js/.
#
# Background: the minified webpack Hub client ships an EMPTY fallbackImages
# map. When the branding fix is missing, the bundles contain:
#     index bundle:  var p={};u.image=function
#     hub bundle:    var k={};_.image=function
# which breaks configs.image("logo"), configs.image("home_background"), etc.
# The fix populates the map instead (e.g. var p={logo:"/assets/images/...}; ).
#
# This script guards against regression by asserting, against the LIVE
# deployment AND the bind-mounted patched sources:
#   1. The EMPTY fallback patterns are ABSENT from the live bundles.
#   2. The populated fallbackImages markers are PRESENT instead.
#   3. The read-only bind mounts wire the patched bundles into the hub client.
#
# Run with: bash tests/verify-bundle-regression.sh
#
# Conventions honored (see docs):
#   - NO `set -e`: a test script must run ALL tests and report the full matrix
#     ((FAILED++) returns exit 1 when the counter is 0, which set -e treats as
#     fatal). We use FAILED=$((FAILED+1)).
#   - set -uo pipefail
#   - Here-strings, not pipes, for grep on large bodies:
#         grep -q 'pat' <<< "$BODY"
#     NOT echo "$BODY" | grep -q 'pat'. grep -q exits on the first match and
#     would SIGPIPE `echo` on the 1.6MB hub bundle under pipefail.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"

# Known-good hashed bundle names for the current build (fallback if HTML
# discovery fails). The live bundles are discovered dynamically below so the
# test survives a rebuild that rehashes the filenames.
INDEX_BUNDLE_FALLBACK="index-19b3ec05dc199afecec2.js"
HUB_BUNDLE_FALLBACK="hub-544153456e8422fbb129.js"

# Regressed EMPTY fallback patterns — these must NOT appear in the live bundles:
EMPTY_INDEX_PATTERN='var p={};u.image=function'
EMPTY_HUB_PATTERN='var k={};_.image=function'
# Populated markers the branding patch installs instead of the empty maps:
POPULATED_INDEX_MARKER='var p={logo:"/assets/images/'
POPULATED_HUB_MARKER='var k={logo:"/assets/images/'

# Bind-mounted patched sources (live container serves these exact files,
# wired read-only in the compose file):
PATCHED_INDEX="/opt/git/hubs-client-assets/${INDEX_BUNDLE_FALLBACK}"
PATCHED_HUB="/opt/git/hubs-client-assets/${HUB_BUNDLE_FALLBACK}"
COMPOSE_FILE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Bundle regression: EMPTY fallbackImages patterns absent"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Discovery: resolve the live bundle URLs from the served HTML so the test is
# robust to hashed filename changes (falls back to known-good names).
# ---------------------------------------------------------------------------
IDX_MATCH=$(curl -sk --max-time 20 "${BASE}/" | grep -oE 'assets/js/index-[a-z0-9]+\.js' | head -n1 || true)
HUB_MATCH=$(curl -sk --max-time 20 "${BASE}/hub.html" | grep -oE 'assets/js/hub-[a-z0-9]+\.js' | head -n1 || true)

if [[ -n "$IDX_MATCH" ]]; then
  INDEX_NAME="${IDX_MATCH##*/}"
  echo "  Discovered index bundle: /${IDX_MATCH}"
else
  INDEX_NAME="${INDEX_BUNDLE_FALLBACK}"
  echo "  ⚠️  HTML discovery of index bundle failed — using fallback ${INDEX_NAME}"
fi

if [[ -n "$HUB_MATCH" ]]; then
  HUB_NAME="${HUB_MATCH##*/}"
  echo "  Discovered hub bundle: /${HUB_MATCH}"
else
  HUB_NAME="${HUB_BUNDLE_FALLBACK}"
  echo "  ⚠️  HTML discovery of hub bundle failed — using fallback ${HUB_NAME}"
fi

echo ""
echo "--- Live bundle checks ---"
echo ""

# ---------------------------------------------------------------------------
# Test 1: Index bundle is served (non-empty body)
# ---------------------------------------------------------------------------
echo -n "Test 1: index bundle served (${INDEX_NAME})... "
INDEX_BODY=$(curl -sk --max-time 20 "${BASE}/assets/js/${INDEX_NAME}" || true)
if [[ -n "$INDEX_BODY" ]]; then
  pass "bundle body is non-empty ($(printf '%s' "$INDEX_BODY" | wc -c) bytes)"
else
  fail "bundle returned an EMPTY body — cannot verify content"
fi

# ---------------------------------------------------------------------------
# Test 2: EMPTY fallback pattern ABSENT from the live index bundle
# ---------------------------------------------------------------------------
echo -n "Test 2: EMPTY pattern '${EMPTY_INDEX_PATTERN}' NOT in live index bundle... "
if [[ -z "$INDEX_BODY" ]]; then
  fail "skipped (index bundle body empty)"
elif grep -qF "$EMPTY_INDEX_PATTERN" <<< "$INDEX_BODY"; then
  fail "REGRESSION: EMPTY fallbackImages pattern found in live index bundle"
else
  pass "pattern absent"
fi

# ---------------------------------------------------------------------------
# Test 3: Populated fallbackImages marker PRESENT in live index bundle
# ---------------------------------------------------------------------------
echo -n "Test 3: populated fallbackImages marker present in live index bundle... "
if [[ -z "$INDEX_BODY" ]]; then
  fail "skipped (index bundle body empty)"
elif grep -qF "$POPULATED_INDEX_MARKER" <<< "$INDEX_BODY"; then
  pass "marker '${POPULATED_INDEX_MARKER}' found"
else
  fail "marker not found — fix may be missing or bundle unexpected"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 4: Hub bundle is served (non-empty body)
# ---------------------------------------------------------------------------
echo -n "Test 4: hub bundle served (${HUB_NAME})... "
HUB_BODY=$(curl -sk --max-time 20 "${BASE}/assets/js/${HUB_NAME}" || true)
if [[ -n "$HUB_BODY" ]]; then
  pass "bundle body is non-empty ($(printf '%s' "$HUB_BODY" | wc -c) bytes)"
else
  fail "bundle returned an EMPTY body — cannot verify content"
fi

# ---------------------------------------------------------------------------
# Test 5: EMPTY fallback pattern ABSENT from the live hub bundle
# ---------------------------------------------------------------------------
echo -n "Test 5: EMPTY pattern '${EMPTY_HUB_PATTERN}' NOT in live hub bundle... "
if [[ -z "$HUB_BODY" ]]; then
  fail "skipped (hub bundle body empty)"
elif grep -qF "$EMPTY_HUB_PATTERN" <<< "$HUB_BODY"; then
  fail "REGRESSION: EMPTY fallbackImages pattern found in live hub bundle"
else
  pass "pattern absent"
fi

# ---------------------------------------------------------------------------
# Test 6: Populated fallbackImages marker PRESENT in live hub bundle
# ---------------------------------------------------------------------------
echo -n "Test 6: populated fallbackImages marker present in live hub bundle... "
if [[ -z "$HUB_BODY" ]]; then
  fail "skipped (hub bundle body empty)"
elif grep -qF "$POPULATED_HUB_MARKER" <<< "$HUB_BODY"; then
  pass "marker '${POPULATED_HUB_MARKER}' found"
else
  fail "marker not found — fix may be missing or bundle unexpected"
fi

echo ""
echo "--- Bind-mounted source checks (offline) ---"
echo ""

# ---------------------------------------------------------------------------
# Test 7: Patched index bundle on disk has no EMPTY pattern
# ---------------------------------------------------------------------------
echo -n "Test 7: bind-mounted index bundle has no EMPTY pattern... "
if [[ ! -f "$PATCHED_INDEX" ]]; then
  fail "file missing: $PATCHED_INDEX"
elif grep -qF "$EMPTY_INDEX_PATTERN" "$PATCHED_INDEX"; then
  fail "REGRESSION: EMPTY pattern present in $PATCHED_INDEX"
else
  pass "pattern absent in $PATCHED_INDEX"
fi

# ---------------------------------------------------------------------------
# Test 8: Patched hub bundle on disk has no EMPTY pattern
# ---------------------------------------------------------------------------
echo -n "Test 8: bind-mounted hub bundle has no EMPTY pattern... "
if [[ ! -f "$PATCHED_HUB" ]]; then
  fail "file missing: $PATCHED_HUB"
elif grep -qF "$EMPTY_HUB_PATTERN" "$PATCHED_HUB"; then
  fail "REGRESSION: EMPTY pattern present in $PATCHED_HUB"
else
  pass "pattern absent in $PATCHED_HUB"
fi

# ---------------------------------------------------------------------------
# Test 9: Compose file bind-mounts the patched bundles (read-only)
# ---------------------------------------------------------------------------
echo -n "Test 9: compose file bind-mounts patched bundles read-only... "
if [[ ! -f "$COMPOSE_FILE" ]]; then
  fail "compose file missing: $COMPOSE_FILE"
else
  MOUNTED_INDEX=$(grep -c "${PATCHED_INDEX}:/code/dist/assets/js/" "$COMPOSE_FILE")
  MOUNTED_HUB=$(grep -c "${PATCHED_HUB}:/code/dist/assets/js/" "$COMPOSE_FILE")
  if [[ "$MOUNTED_INDEX" -ge 1 && "$MOUNTED_HUB" -ge 1 ]]; then
    pass "index and hub bundles are wired into the container"
  else
    fail "bind mounts missing (index=${MOUNTED_INDEX}, hub=${MOUNTED_HUB})"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "❌ Regression detected — EMPTY fallbackImages patterns present or"
  echo "   patch not deployed. See failures above."
  exit 1
else
  echo ""
  echo "✅ All tests passed — no EMPTY fallbackImages regression."
  exit 0
fi
