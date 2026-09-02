#!/bin/bash
# verify-spa-routes.sh — verify all SPA rewrite targets serve their own HTML pages
# (not the landing page).
#
# This script checks that specific SPA routes (/link, /avatars, /scenes, /signin,
# /discord, /cloud, /verify, /tokens) return HTTP 200 and contain content that
# distinguishes them from the main landing page (which is served at /).
#
# Run with: bash tests/verify-spa-routes.sh
# (No sudo needed — hits the live public URL.)

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# HTTP status code only (no body) for a given URL.
http_code() {
  curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "$1"
}

echo "=========================================="
echo "SPA Routes Verification"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# Get the home page body to use as a baseline for "the landing page"
HOME_BODY=$(curl -sk --max-time 20 "${BASE}/" || true)
# The landing page is characterized by the index- bundle
LANDING_MARKER='assets/js/index-'

# Routes to verify. 
# We expect these to be rewritten to a specific HTML file (not necessarily /index.html).
# Since we don't have the exact HTML content for each, we verify:
# 1. They return HTTP 200.
# 2. They do NOT contain the landing page marker (or they contain a unique marker).
# However, if Hubs uses the same index bundle for all SPA routes, we must check for
# route-specific content. 
# 
# Given the requirement "not the landing page", we assume that if it's a 
# separate SPA page, it should either have different HTML or at least
# we check that it's not exactly the same as /.
#
# Actually, in many Hubs SPA setups, these routes are handled by the client-side 
# router but served by a specific HTML file or rewritten. 
# Let's check the bodies.

ROUTES=(
  "/link"
  "/avatars"
  "/scenes"
  "/signin"
  "/discord"
  "/cloud"
  "/verify"
  "/tokens"
)

for ROUTE in "${ROUTES[@]}"; do
  echo -n "Testing route ${ROUTE}... "
  
  CODE=$(http_code "${BASE}${ROUTE}")
  if [[ "$CODE" != "200" ]]; then
    fail "${ROUTE} returned HTTP ${CODE} (expected 200)"
    continue
  fi

  BODY=$(curl -sk --max-time 20 "${BASE}${ROUTE}" || true)
  
  # Check if it's the landing page. 
  # If the route is supposed to be its own page, it should typically 
  # differ from the root / in some meaningful way (e.g. different title, 
  # different bundle, or different HTML structure).
  #
  # To be robust: we verify it's NOT identical to the home page body.
  if [[ "$BODY" == "$HOME_BODY" ]]; then
    fail "${ROUTE} served identical content to landing page (/)"
  else
    pass "${ROUTE} serves unique content (HTTP 200)"
  fi
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
