#!/bin/bash
# Verification script for Hubs client branding / asset fix.
#
# Verifies that:
#   1. The home-page index bundle and room hub bundle both ship a populated
#      fallbackImages map (not the empty `var p={}` / `var k={}` that caused
#      the broken logo <img> and black hero background).
#   2. Every fallback image URL resolves with HTTP 200.
#   3. The room environment cubemap (skybox) assets resolve (environment not
#      black).
#   4. The homepage, hub.html, and bundle JS files are served correctly.
#
# Run with: bash tests/verify-client-branding.sh
# (No sudo needed — hits the live public URL.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"

INDEX_BUNDLE="index-19b3ec05dc199afecec2.js"
HUB_BUNDLE="hub-544153456e8422fbb129.js"

# Asset URLs that the patched fallbackImages map references. Each must be a
# literal key in the bundle's fallback object AND resolve over HTTP.
declare -a IMAGES=(
  "app-logo-dark-9158488a92771030c385..png"
  "app-logo-0c370f0aceb17bb14af8..png"
  "company-logo-014ef6e447c1493d01d2..png"
  "editor-logo-6638d3015b5b15d58206..png"
  "home-hero-background-unbranded-0b2d687eb0551518b3a5..png"
)

declare -a CUBEMAP=(
  "posx-818c43c014ca2a6d78cd..jpg"
  "posy-5d7797ed9fb3992e2ad5..jpg"
  "posz-5f0c1deffc75ae72e50f..jpg"
  "negx-87722bb4e14aafeae99a..jpg"
  "negy-e7615093c7905a75b2cd..jpg"
  "negz-4cb0b5db71f1aa66a60c..jpg"
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Hubs Client Branding / Asset Verification"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Home-page index bundle is served and contains populated fallbackImages
# ---------------------------------------------------------------------------
echo -n "Test 1: index bundle served with populated fallbackImages... "
BODY=$(curl -sk --max-time 20 "${BASE}/assets/js/${INDEX_BUNDLE}" || true)
if [[ -z "$BODY" ]]; then
  fail "index bundle returned empty body"
else
  # The built bundle shipped with `var p={};u.image=function` (empty fallback).
  # The patch populates it: `var p={logo:"...",logo_dark:"...",...};u.image=`
  if grep -q 'var p={logo:"/assets/images/' <<< "$BODY"; then
    pass "fallbackImages map populated in index bundle"
  elif grep -q 'var p={};u\.image=function' <<< "$BODY"; then
    fail "index bundle still has EMPTY fallbackImages (var p={}) — patch missing"
  else
    fail "index bundle fallbackImages marker not found (unexpected bundle content)"
  fi
fi

# ---------------------------------------------------------------------------
# Test 2: Room hub bundle is served and contains populated fallbackImages
# ---------------------------------------------------------------------------
echo -n "Test 2: hub bundle served with populated fallbackImages... "
BODY=$(curl -sk --max-time 20 "${BASE}/assets/js/${HUB_BUNDLE}" || true)
if [[ -z "$BODY" ]]; then
  fail "hub bundle returned empty body"
else
  if grep -q 'var k={logo:"/assets/images/' <<< "$BODY"; then
    pass "fallbackImages map populated in hub bundle"
  elif grep -q 'var k={};_\.image=function' <<< "$BODY"; then
    fail "hub bundle still has EMPTY fallbackImages (var k={}) — patch missing"
  else
    fail "hub bundle fallbackImages marker not found (unexpected bundle content)"
  fi
fi

# ---------------------------------------------------------------------------
# Test 3: Every fallback image URL resolves (HTTP 200)
# ---------------------------------------------------------------------------
echo ""
echo "Fallback image assets:"
for img in "${IMAGES[@]}"; do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${BASE}/assets/images/${img}")
  if [[ "$CODE" == "200" ]]; then
    pass "  ${img}"
  else
    fail "  ${img} (HTTP ${CODE})"
  fi
done

# ---------------------------------------------------------------------------
# Test 4: Room environment cubemap resolves (skybox not black)
# ---------------------------------------------------------------------------
echo ""
echo "Room environment cubemap (skybox):"
for face in "${CUBEMAP[@]}"; do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${BASE}/assets/images/cubemap/${face}")
  if [[ "$CODE" == "200" ]]; then
    pass "  cubemap/${face}"
  else
    fail "  cubemap/${face} (HTTP ${CODE})"
  fi
done

# ---------------------------------------------------------------------------
# Test 5: Homepage and hub.html load
# ---------------------------------------------------------------------------
echo ""
echo -n "Test 5: Homepage (index.html)... "
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${BASE}/")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

echo -n "Test 6: Room page (hub.html via slug redirect)... "
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 15 "${BASE}/hub.html")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 7: Bundle sizes are non-trivial (patch did not corrupt/truncate)
# ---------------------------------------------------------------------------
echo -n "Test 7: index bundle integrity (non-trivial size)... "
SIZE=$(curl -sk --max-time 20 "${BASE}/assets/js/${INDEX_BUNDLE}" | wc -c)
if [[ "$SIZE" -gt 450000 ]]; then
  pass "${SIZE} bytes"
else
  fail "${SIZE} bytes (expected >450000 — bundle may be truncated)"
fi

echo -n "Test 8: hub bundle integrity (non-trivial size)... "
SIZE=$(curl -sk --max-time 20 "${BASE}/assets/js/${HUB_BUNDLE}" | wc -c)
if [[ "$SIZE" -gt 1500000 ]]; then
  pass "${SIZE} bytes"
else
  fail "${SIZE} bytes (expected >1500000 — bundle may be truncated)"
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
