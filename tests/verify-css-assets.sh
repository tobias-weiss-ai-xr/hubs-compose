#!/bin/bash
# Verification script for CSS stylesheet assets referenced from the homepage.
#
# Verifies that:
#   1. The CSS asset URLs referenced from the homepage (support-*.css, index-*.css)
#      resolve with HTTP 200.
#   2. Each CSS file serves Content-Type: text/css.
#   3. Each CSS file has non-trivial size (>1KB).
#
# Run with: bash tests/verify-css-assets.sh
# (No sudo needed — hits the live public URL.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"

# CSS asset URLs extracted from the homepage <link> tags
declare -a CSS_ASSETS=(
  "support-63d74e7f6dde4789454f.css"
  "index-7f9f32fe19d80324e9b9.css"
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "CSS Stylesheet Asset Verification"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: CSS assets resolve with HTTP 200 and correct Content-Type
# ---------------------------------------------------------------------------
echo "Test 1: CSS asset HTTP 200 + Content-Type: text/css + size >1KB"
echo ""

for css_file in "${CSS_ASSETS[@]}"; do
  URL="${BASE}/assets/stylesheets/${css_file}"
  
  # Get headers and body in one request
  HEADER=$(curl -sk --max-time 20 -I "${URL}" 2>/dev/null || true)
  BODY=$(curl -sk --max-time 20 "${URL}" 2>/dev/null || true)
  
  # Extract status code
  HTTP_CODE=$(echo "${HEADER}" | head -1 | grep -oE 'HTTP/[0-9.]+ [0-9]+' | awk '{print $2}')
  
  # Extract Content-Type (strip trailing whitespace/CR)
  CONTENT_TYPE=$(echo "${HEADER}" | grep -i '^content-type:' | head -1 | cut -d: -f2- | tr -d '\r\n' | awk '{print $1}' | sed 's/;.*//')
  
  # Calculate body size
  BODY_SIZE=${#BODY}
  
  # Test 1a: HTTP 200
  if [[ "$HTTP_CODE" == "200" ]]; then
    pass "${css_file} returns HTTP 200"
  else
    fail "${css_file} returns HTTP ${HTTP_CODE} (expected 200)"
  fi
  
  # Test 1b: Content-Type: text/css
  if [[ "$CONTENT_TYPE" == "text/css" ]]; then
    pass "${css_file} Content-Type is text/css"
  else
    fail "${css_file} Content-Type is '${CONTENT_TYPE}' (expected text/css)"
  fi
  
  # Test 1c: Non-trivial size (>1KB = >1024 bytes)
  if [[ "$BODY_SIZE" -gt 1024 ]]; then
    pass "${css_file} size ${BODY_SIZE} bytes (>1KB)"
  else
    fail "${css_file} size ${BODY_SIZE} bytes (expected >1024)"
  fi
done

# ---------------------------------------------------------------------------
# Test 2: Homepage references the CSS assets correctly
# ---------------------------------------------------------------------------
echo ""
echo "Test 2: Homepage references CSS assets"

HOME_BODY=$(curl -sk --max-time 20 "${BASE}/" 2>/dev/null || true)

if [[ -z "$HOME_BODY" ]]; then
  fail "Homepage returned empty body"
else
  # Check that both CSS files are referenced in the homepage HTML
  SUPPORT_REF='<link href="/assets/stylesheets/support-63d74e7f6dde4789454f.css" rel="stylesheet">'
  INDEX_REF='<link href="/assets/stylesheets/index-7f9f32fe19d80324e9b9.css" rel="stylesheet">'
  
  if grep -q "${SUPPORT_REF}" <<< "${HOME_BODY}"; then
    pass "Homepage references support-63d74e7f6dde4789454f.css"
  else
    fail "Homepage missing support CSS reference"
  fi
  
  if grep -q "${INDEX_REF}" <<< "${HOME_BODY}"; then
    pass "Homepage references index-7f9f32fe19d80324e9b9.css"
  else
    fail "Homepage missing index CSS reference"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ "${FAILED}" -gt 0 ]]; then
  echo ""
  echo "❌ Some tests failed. Check the output above."
  exit 1
else
  echo ""
  echo "✅ All tests passed!"
  exit 0
fi