#!/bin/bash
# Offline verification that the patched bundle files contain all 8 fallbackImages keys.
#
# Verifies that both minified webpack bundles (index-19b3ec05dc199afecec2.js and
# hub-544153456e8422fbb129.js) in /opt/git/hubs-client-assets/ contain all 8
# fallbackImages keys (logo, logo_dark, company_logo, editor_logo, home_background,
# landing_rooms_thumb, landing_communicate_thumb, landing_media_thumb).
#
# Run with: bash tests/verify-bundle-patch.sh

# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

set -uo pipefail

# Absolute paths to the bundle files
INDEX_BUNDLE="/opt/git/hubs-client-assets/index-19b3ec05dc199afecec2.js"
HUB_BUNDLE="/opt/git/hubs-client-assets/hub-544153456e8422fbb129.js"

# The 8 fallbackImages keys that must be present in both bundles
declare -a FALLBACK_KEYS=(
  "logo"
  "logo_dark"
  "company_logo"
  "editor_logo"
  "home_background"
  "landing_rooms_thumb"
  "landing_communicate_thumb"
  "landing_media_thumb"
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Bundle Patch Verification (Offline Check)"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: index bundle file exists
# ---------------------------------------------------------------------------
echo -n "Test 1: index bundle file exists... "
if [[ -f "$INDEX_BUNDLE" ]]; then
  pass "$INDEX_BUNDLE exists"
else
  fail "$INDEX_BUNDLE not found"
fi

# ---------------------------------------------------------------------------
# Test 2: hub bundle file exists
# ---------------------------------------------------------------------------
echo -n "Test 2: hub bundle file exists... "
if [[ -f "$HUB_BUNDLE" ]]; then
  pass "$HUB_BUNDLE exists"
else
  fail "$HUB_BUNDLE not found"
fi

# ---------------------------------------------------------------------------
# Test 3: index bundle contains all 8 fallbackImages keys
# ---------------------------------------------------------------------------
echo ""
echo "Checking index bundle ($INDEX_BUNDLE) for fallbackImages keys:"
for key in "${FALLBACK_KEYS[@]}"; do
  if grep -q "${key}:" "$INDEX_BUNDLE"; then
    pass "  fallbackImages key '${key}' found in index bundle"
  else
    fail "  fallbackImages key '${key}' NOT found in index bundle"
  fi
done

# ---------------------------------------------------------------------------
# Test 4: hub bundle contains all 8 fallbackImages keys
# ---------------------------------------------------------------------------
echo ""
echo "Checking hub bundle ($HUB_BUNDLE) for fallbackImages keys:"
for key in "${FALLBACK_KEYS[@]}"; do
  if grep -q "${key}:" "$HUB_BUNDLE"; then
    pass "  fallbackImages key '${key}' found in hub bundle"
  else
    fail "  fallbackImages key '${key}' NOT found in hub bundle"
  fi
done

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
