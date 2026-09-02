#!/bin/bash
# Verification script for Hubs client JS bundles.
#
# Verifies that:
#   1. The index bundle (index-*.js) served from https://hubs.chemie-lernen.org/assets/js/
#      has non-trivial size (>100KB) and source map is present (.map HTTP 200).
#   2. The hub bundle (hub-*.js) served from https://hubs.chemie-lernen.org/assets/js/
#      has non-trivial size (>100KB) and source map is present (.map HTTP 200).
#
# Run with: bash tests/verify-client-bundles.sh
# (No sudo needed — hits the live public URL.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"
JS_PATH="${BASE}/assets/js"

# Bundle filenames (content-hash filenames may change, so we detect them)
# For now we use the known filenames from the current deployment
INDEX_BUNDLE="index-19b3ec05dc199afecec2.js"
HUB_BUNDLE="hub-544153456e8422fbb129.js"

# Minimum size thresholds (100KB = 102400 bytes)
MIN_INDEX_SIZE=102400
MIN_HUB_SIZE=102400

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Hubs Client JS Bundle Verification"
echo "  Target: ${JS_PATH}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Index bundle served with non-trivial size (>100KB)
# ---------------------------------------------------------------------------
echo -n "Test 1: index bundle size >100KB... "
BODY=$(curl -sk --max-time 20 "${JS_PATH}/${INDEX_BUNDLE}" || true)
SIZE=${#BODY}
if [[ "$SIZE" -gt "$MIN_INDEX_SIZE" ]]; then
  pass "${INDEX_BUNDLE} is ${SIZE} bytes (>${MIN_INDEX_SIZE})"
else
  fail "${INDEX_BUNDLE} is ${SIZE} bytes (expected >${MIN_INDEX_SIZE})"
fi

# ---------------------------------------------------------------------------
# Test 2: Hub bundle served with non-trivial size (>100KB)
# ---------------------------------------------------------------------------
echo -n "Test 2: hub bundle size >100KB... "
BODY=$(curl -sk --max-time 20 "${JS_PATH}/${HUB_BUNDLE}" || true)
SIZE=${#BODY}
if [[ "$SIZE" -gt "$MIN_HUB_SIZE" ]]; then
  pass "${HUB_BUNDLE} is ${SIZE} bytes (>${MIN_HUB_SIZE})"
else
  fail "${HUB_BUNDLE} is ${SIZE} bytes (expected >${MIN_HUB_SIZE})"
fi

# ---------------------------------------------------------------------------
# Test 3: Index bundle source map (.map file) serves HTTP 200
# ---------------------------------------------------------------------------
echo -n "Test 3: index bundle source map (HTTP 200)... "
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${JS_PATH}/${INDEX_BUNDLE}.map")
if [[ "$CODE" == "200" ]]; then
  pass "${INDEX_BUNDLE}.map returns HTTP 200"
else
  fail "${INDEX_BUNDLE}.map returns HTTP ${CODE} (expected 200)"
fi

# ---------------------------------------------------------------------------
# Test 4: Hub bundle source map (.map file) serves HTTP 200
# ---------------------------------------------------------------------------
echo -n "Test 4: hub bundle source map (HTTP 200)... "
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${JS_PATH}/${HUB_BUNDLE}.map")
if [[ "$CODE" == "200" ]]; then
  pass "${HUB_BUNDLE}.map returns HTTP 200"
else
  fail "${HUB_BUNDLE}.map returns HTTP ${CODE} (expected 200)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
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