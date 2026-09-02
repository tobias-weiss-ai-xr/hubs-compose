#!/usr/bin/env bash
# verify-cache-cors-headers.sh — cache-control + CORS on hubs-client routes
#
# The static server sends `Cache-Control: no-cache` on everything and
# `Access-Control-Allow-Origin: *`. no-cache on HTML/JS is what makes client
# bundle fixes (branding, room links, scene creation) reach visitors on their
# next reload — this is a fix-propagation regression guard.
# Scope: ONLY routes served by the hubs-client static server (port 8080 via
# hubs-root router). Traefik/Reticulum routes (/api/*, /files/*) are out of
# scope — they set their own cache semantics.
set -uo pipefail

HOST="hubs.chemie-lernen.org"
PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Cache + CORS Header Verification (hubs-client routes)"
echo "  Target: https://${HOST}"
echo "=========================================="

headers_for() {
  curl -skI --max-time 20 "https://${HOST}$1" | tr -d '\r'
}

# --- 1. landing page: no-cache + ACAO ---
H=$(headers_for "/")
CC=$(grep -i '^cache-control:' <<< "$H" | head -1)
ACAO=$(grep -i '^access-control-allow-origin:' <<< "$H" | head -1)
if grep -qi 'no-cache' <<< "$CC"; then
  pass "Landing page sends Cache-Control: no-cache"
else
  fail "Landing page Cache-Control missing no-cache (got: ${CC:-none})"
fi
if [[ -n "$ACAO" ]]; then
  pass "Landing page sends Access-Control-Allow-Origin (${ACAO})"
else
  fail "Landing page missing Access-Control-Allow-Origin"
fi

# --- 2. JS bundle (URL discovered from the homepage HTML) ---
HTML=$(curl -sk --max-time 20 "https://${HOST}/")
BUNDLE=$(grep -o '/assets/js/index-[a-f0-9]*\.js' <<< "$HTML" | head -1)
if [[ -n "$BUNDLE" ]]; then
  H=$(headers_for "$BUNDLE")
  CC=$(grep -i '^cache-control:' <<< "$H" | head -1)
  ACAO=$(grep -i '^access-control-allow-origin:' <<< "$H" | head -1)
  if grep -qi 'no-cache' <<< "$CC"; then
    pass "JS bundle ${BUNDLE} sends Cache-Control: no-cache"
  else
    fail "JS bundle Cache-Control missing no-cache (got: ${CC:-none}) — bundle fixes would get stuck in browser caches"
  fi
  if [[ -n "$ACAO" ]]; then
    pass "JS bundle sends Access-Control-Allow-Origin"
  else
    fail "JS bundle missing Access-Control-Allow-Origin"
  fi
else
  fail "Could not discover index bundle URL from homepage HTML"
fi

# --- 3. webmanifest: no-cache + correct content type ---
H=$(headers_for "/manifest.webmanifest")
CC=$(grep -i '^cache-control:' <<< "$H" | head -1)
CT=$(grep -i '^content-type:' <<< "$H" | head -1)
if grep -qi 'no-cache' <<< "$CC"; then
  pass "manifest.webmanifest sends Cache-Control: no-cache"
else
  fail "manifest.webmanifest Cache-Control missing no-cache"
fi
if grep -qi 'manifest+json' <<< "$CT"; then
  pass "manifest.webmanifest served as application/manifest+json"
else
  fail "manifest.webmanifest wrong content type (got: ${CT:-none})"
fi

# --- 4. a room URL (hub.html): no-cache; element API paced 1.1s first ---
sleep 1.2
ELEMENT_JSON=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null)
ROOM_ID=$(jq -r '[.hubs[] | select(.hub_id != null)] | first | .hub_id // empty' <<< "$ELEMENT_JSON" 2>/dev/null)
if [[ -n "$ROOM_ID" ]]; then
  H=$(headers_for "/${ROOM_ID}")
  CC=$(grep -i '^cache-control:' <<< "$H" | head -1)
  if grep -qi 'no-cache' <<< "$CC"; then
    pass "Room page /<id> sends Cache-Control: no-cache"
  else
    fail "Room page Cache-Control missing no-cache (got: ${CC:-none})"
  fi
else
  fail "Could not fetch a room id from element API — room page cache check skipped as failure"
fi

echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ $FAILED -eq 0 ]]; then
  exit 0
fi
exit 1
