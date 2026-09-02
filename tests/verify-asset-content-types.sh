#!/usr/bin/env bash
# verify-asset-content-types.sh — Verify Content-Type headers for all asset types
#
# Verifies that:
#   1. CSS files are served with Content-Type: text/css
#   2. JS bundles are served with Content-Type: application/javascript or text/javascript
#   3. PNG images are served with Content-Type: image/png
#   4. JPG images are served with Content-Type: image/jpeg
#
# Run with: bash tests/verify-asset-content-types.sh
# (No sudo needed — hits the live public URL.)

set -uo pipefail

TARGET_URL="https://hubs.chemie-lernen.org"
CURL_OPTS="-sk --max-time 20"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Asset Content-Type Verification"
echo "  Target: $TARGET_URL"
echo "=========================================="
echo ""

# Discover asset URLs from the homepage
echo "Discovering asset URLs from homepage..."
HOMEPAGE=$(curl $CURL_OPTS "$TARGET_URL/" 2>/dev/null)

# Extract CSS URLs
CSS_URLS=()
while IFS= read -r url; do
  [[ -n "$url" ]] && CSS_URLS+=("$url")
done < <(echo "$HOMEPAGE" | grep -o '/assets/stylesheets/[a-z]*-[a-f0-9]*\.css' | sort -u)

# Extract JS URLs (just index + hub for this test — full coverage in verify-client-bundles.sh)
JS_URLS=()
while IFS= read -r url; do
  [[ -n "$url" ]] && JS_URLS+=("$url")
done < <(echo "$HOMEPAGE" | grep -o '/assets/js/index-[a-f0-9]*\.js' | sort -u)

# Known image asset URLs (logos + cubemap)
IMAGE_URLS=(
  "/assets/images/app-logo-dark-9158488a92771030c385..png"
  "/assets/images/cubemap/posx-818c43c014ca2a6d78cd..jpg"
)

# ---------------------------------------------------------------------------
# Test 1-N: CSS Content-Type = text/css
# ---------------------------------------------------------------------------
echo ""
echo "CSS Content-Type checks:"
for url in "${CSS_URLS[@]}"; do
  full_url="${TARGET_URL}${url}"
  content_type=$(curl $CURL_OPTS -o /dev/null -w '%{content_type}' "$full_url" 2>/dev/null)
  if echo "$content_type" | grep -qi 'text/css'; then
    pass "CSS: $url → $content_type"
  else
    fail "CSS: $url → $content_type (expected text/css)"
  fi
done

# ---------------------------------------------------------------------------
# Test: JS Content-Type = application/javascript or text/javascript
# ---------------------------------------------------------------------------
echo ""
echo "JavaScript Content-Type checks:"
for url in "${JS_URLS[@]}"; do
  full_url="${TARGET_URL}${url}"
  content_type=$(curl $CURL_OPTS -o /dev/null -w '%{content_type}' "$full_url" 2>/dev/null)
  if echo "$content_type" | grep -qi 'application/javascript\|text/javascript'; then
    pass "JS: $url → $content_type"
  else
    fail "JS: $url → $content_type (expected application/javascript or text/javascript)"
  fi
done

# ---------------------------------------------------------------------------
# Test: Image Content-Type (PNG and JPG)
# ---------------------------------------------------------------------------
echo ""
echo "Image Content-Type checks:"
for url in "${IMAGE_URLS[@]}"; do
  full_url="${TARGET_URL}${url}"
  content_type=$(curl $CURL_OPTS -o /dev/null -w '%{content_type}' "$full_url" 2>/dev/null)
  if [[ "$url" == *.png ]]; then
    expected="image/png"
  elif [[ "$url" == *.jpg ]]; then
    expected="image/jpeg"
  else
    expected="image/*"
  fi
  if echo "$content_type" | grep -qi "$expected"; then
    pass "Image: $url → $content_type"
  else
    fail "Image: $url → $content_type (expected $expected)"
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
