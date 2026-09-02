#!/usr/bin/env bash
# verify-legacy-redirect-variants.sh — legacy /hub/<id>[/<slug>] redirect edge cases
#
# The static server (static-server.py) 301-redirects legacy room URLs of the
# form /hub/<7-char-id>[/<slug>] to the canonical /<id>[/<slug>] form. These
# legacy URLs exist in bookmarks/chat logs from before the 2026-09-02 fix.
# This test locks down the redirect contract's edge cases:
#   1. /hub/<id>              (no slug)  -> 301 -> /<id>
#   2. /hub/<id>/             (trailing) -> 301 -> /<id>
#   3. /hub/<id>/<slug>?q=1   query preserved in Location
#   4. /hub/<id>/<slug>/objects.gltf  NOT redirected (dot-path exclusion)
#   5. /hub/ab1               (too short) NOT redirected (SPA fallback 200)
#   6. /hubathon              NOT redirected
#   7. the 301 response itself carries Strict-Transport-Security
#
# NOTE: the element API throttles to ~1 rps/IP (PlugAttack); requests are
# paced and we only fetch it once.
set -uo pipefail

HOST="hubs.chemie-lernen.org"
PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Legacy Redirect Variant Verification"
echo "  Target: https://${HOST}"
echo "=========================================="

# --- pick a real room id from the element API (single paced request) ---
ELEMENT_JSON=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null)
if ! jq -e '.hubs | type == "array" and length > 0' <<< "$ELEMENT_JSON" >/dev/null 2>&1; then
  sleep 1.2
  ELEMENT_JSON=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null)
fi
ROOM_ID=$(jq -r '[.hubs[] | select(.hub_id != null)] | first | .hub_id // empty' <<< "$ELEMENT_JSON" 2>/dev/null)
ROOM_SLUG=$(jq -r --arg id "$ROOM_ID" '[.hubs[] | select(.hub_id == $id)] | first | .slug // "raum"' <<< "$ELEMENT_JSON" 2>/dev/null)

if [[ -z "$ROOM_ID" ]]; then
  echo "❌ FAIL  Could not fetch a room id from the element API — cannot run variants"
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi
echo "  Using room: /${ROOM_ID}/${ROOM_SLUG}"
echo ""

# helper: "<path>" -> "<code> <redirect_url>"
probe() {
  curl -sk -o /dev/null -w '%{http_code} %{redirect_url}' --max-time 20 "https://${HOST}$1"
}

# --- 1. no slug: /hub/<id> -> /<id> ---
OUT=$(probe "/hub/${ROOM_ID}")
CODE=${OUT%% *}; LOC=${OUT#* }
if [[ "$CODE" == "301" && "$LOC" == "https://${HOST}/${ROOM_ID}" ]]; then
  pass "No-slug /hub/<id> -> 301 -> /<id>"
else
  fail "No-slug /hub/<id>: expected 301 -> https://${HOST}/${ROOM_ID}, got '$OUT'"
fi

# --- 2. trailing slash: /hub/<id>/ -> /<id> ---
OUT=$(probe "/hub/${ROOM_ID}/")
CODE=${OUT%% *}; LOC=${OUT#* }
if [[ "$CODE" == "301" && "$LOC" == "https://${HOST}/${ROOM_ID}" ]]; then
  pass "Trailing slash /hub/<id>/ -> 301 -> /<id>"
else
  fail "Trailing slash /hub/<id>/: expected 301 -> https://${HOST}/${ROOM_ID}, got '$OUT'"
fi

# --- 3. query preservation: /hub/<id>/<slug>?test=1 keeps ?test=1 ---
OUT=$(probe "/hub/${ROOM_ID}/${ROOM_SLUG}?test=1")
CODE=${OUT%% *}; LOC=${OUT#* }
if [[ "$CODE" == "301" && "$LOC" == "https://${HOST}/${ROOM_ID}/${ROOM_SLUG}?test=1" ]]; then
  pass "Query string preserved on redirect"
else
  fail "Query preservation: expected 301 -> .../${ROOM_SLUG}?test=1, got '$OUT'"
fi

# --- 4. dot-path exclusion: /hub/<id>/<slug>/objects.gltf NOT redirected ---
OUT=$(probe "/hub/${ROOM_ID}/${ROOM_SLUG}/objects.gltf")
CODE=${OUT%% *}
if [[ "$CODE" != "301" ]]; then
  pass "Dot-path /hub/<id>/<slug>/objects.gltf NOT redirected (got $CODE)"
else
  fail "Dot-path /hub/<id>/<slug>/objects.gltf unexpectedly redirected: $OUT"
fi

# --- 5. too-short id: /hub/ab1 NOT redirected (SPA fallback) ---
OUT=$(probe "/hub/ab1")
CODE=${OUT%% *}
if [[ "$CODE" != "301" && "$CODE" != "404" ]]; then
  pass "Too-short id /hub/ab1 NOT redirected (got $CODE)"
else
  fail "/hub/ab1 unexpectedly $CODE (expected non-redirect SPA fallback)"
fi

# --- 6. /hubathon NOT redirected ---
OUT=$(probe "/hubathon")
CODE=${OUT%% *}
if [[ "$CODE" != "301" ]]; then
  pass "/hubathon NOT redirected (got $CODE)"
else
  fail "/hubathon unexpectedly redirected: $OUT"
fi

# --- 7. HSTS present on the 301 response ---
HSTS=$(curl -skI --max-time 20 "https://${HOST}/hub/${ROOM_ID}/${ROOM_SLUG}" | grep -i '^strict-transport-security' | tr -d '\r')
if [[ -n "$HSTS" ]]; then
  pass "301 response carries HSTS (${HSTS})"
else
  fail "301 response missing Strict-Transport-Security header"
fi

echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ $FAILED -eq 0 ]]; then
  exit 0
fi
exit 1
