#!/bin/bash
# Verification script for the Hubs branding asset fix.
#
# Verifies that:
#   1. All 5 fallback image URLs (PNGs) referenced by the patched
#      fallbackImages map in the index + hub bundles return HTTP 200 from
#      https://hubs.chemie-lernen.org/assets/images/.
#   2. All 6 cubemap skybox faces return HTTP 200 from
#      https://hubs.chemie-lernen.org/assets/images/cubemap/.
#   3. (Offline cross-check) The 5 PNG slugs are literally present in both
#      patched bundles' fallbackImages maps, so the test list cannot drift
#      from what the patched bundles actually request.
#
# Run with: bash tests/verify-asset-urls.sh
# (No sudo needed — hits the live public URL.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"
IMAGES_DIR="${BASE}/assets/images"

# The 5 unique PNGs referenced by the patched fallbackImages map
# (logo, logo_dark, company_logo, editor_logo, home_background + the shared
# landing thumbs, which all point at the same 5 files).
declare -a IMAGES=(
  "app-logo-dark-9158488a92771030c385..png"
  "app-logo-0c370f0aceb17bb14af8..png"
  "company-logo-014ef6e447c1493d01d2..png"
  "editor-logo-6638d3015b5b15d58206..png"
  "home-hero-background-unbranded-0b2d687eb0551518b3a5..png"
)

# The 6 faces of the room environment cubemap (skybox).
declare -a CUBEMAP=(
  "posx-818c43c014ca2a6d78cd..jpg"
  "posy-5d7797ed9fb3992e2ad5..jpg"
  "posz-5f0c1deffc75ae72e50f..jpg"
  "negx-87722bb4e14aafeae99a..jpg"
  "negy-e7615093c7905a75b2cd..jpg"
  "negz-4cb0b5db71f1aa66a60c..jpg"
)

# Patched bundles bind-mounted into the hubs-client container (offline checks).
INDEX_BUNDLE="/opt/git/hubs-client-assets/index-19b3ec05dc199afecec2.js"
HUB_BUNDLE="/opt/git/hubs-client-assets/hub-544153456e8422fbb129.js"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Hubs Fallback Asset URL Verification"
echo "  Target: ${IMAGES_DIR}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: All 5 fallback image PNGs return HTTP 200
# ---------------------------------------------------------------------------
echo "Fallback image assets (5 PNGs):"
for img in "${IMAGES[@]}"; do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${IMAGES_DIR}/${img}")
  if [[ "$CODE" == "200" ]]; then
    pass "${img} (HTTP ${CODE})"
  else
    fail "${img} (HTTP ${CODE})"
  fi
done

# ---------------------------------------------------------------------------
# Test 2: All 6 cubemap skybox faces return HTTP 200
# ---------------------------------------------------------------------------
echo ""
echo "Cubemap skybox faces (6):"
for face in "${CUBEMAP[@]}"; do
  CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${IMAGES_DIR}/cubemap/${face}")
  if [[ "$CODE" == "200" ]]; then
    pass "cubemap/${face} (HTTP ${CODE})"
  else
    fail "cubemap/${face} (HTTP ${CODE})"
  fi
done

# ---------------------------------------------------------------------------
# Test 3: Offline cross-check — the 5 PNG slugs are in the patched bundles'
# fallbackImages maps (prevents this test drifting from bundle content)
# ---------------------------------------------------------------------------
echo ""
echo "Bundle cross-check (patched fallbackImages maps):"
for bundle in "$INDEX_BUNDLE" "$HUB_BUNDLE"; do
  BNAME=$(basename "$bundle")
  if [[ ! -r "$bundle" ]]; then
    fail "bundle not readable: ${bundle}"
    continue
  fi
  NON_FOUND=0
  for img in "${IMAGES[@]}"; do
    if ! grep -q "${img}" "$bundle"; then
      NON_FOUND=$((NON_FOUND+1))
      fail "${BNAME} missing fallback image slug: ${img}"
    fi
  done
  if [[ "$NON_FOUND" -eq 0 ]]; then
    pass "${BNAME} references all 5 fallback image slugs"
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
