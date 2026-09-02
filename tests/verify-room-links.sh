#!/usr/bin/env bash
#
# verify-room-links.sh — Regression test for the Periodensystem room-link bug
#
# Root cause (fixed 2026-09-02): chemie-portal.js built room links as
#   /hub/<hub_sid>/<slug>
# but the static server's ROOM_RE only rewrites /<hub_sid>/<slug> to hub.html.
# The "/hub/" prefix fell through to the SPA fallback, which serves index.html
# (landing page) — clicking a Periodensystem room link bounced back to the
# landing page instead of entering the room. Additionally getCurrentHubId()
# would have extracted "hub" as the room id.
#
# Fix: bundle patched to href="/"+<hub_id>+"/"+<slug> (matches Hub.url_for()
# in Reticulum). Source fixed in services/hubs/src/chemie-portal.js.
#
# Checks:
#   1. Live index bundle does NOT contain the broken  href="/hub/"+X.hub_id
#   2. Live index bundle DOES contain the fixed    href="/"+X.hub_id  pattern
#   3. Local bundle on disk matches the live one (bind-mount sanity)
#   4. A canonical room URL /<7char>/<slug> serves hub.html (ui-root marker)
#   5. The legacy broken URL /hub/<7char>/<slug> serves index.html (SPA
#      fallback) — documents the failure mode; the client must never link it
#   6. The landing page itself still serves index.html (home-root marker)
#   7. Element API (Periodensystem room list) returns rooms whose canonical
#      /<hub_id>/<slug> URLs serve hub.html (end-to-end user story)
#
# Run with: bash tests/verify-room-links.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

HOST="hubs.chemie-lernen.org"
BUNDLE_NAME="index-19b3ec05dc199afecec2.js"
LIVE_BUNDLE_URL="https://${HOST}/assets/js/${BUNDLE_NAME}"
LOCAL_BUNDLE="/opt/git/hubs-client-assets/${BUNDLE_NAME}"
TMP_BUNDLE=$(mktemp /tmp/verify-room-links.XXXXXX.js)
TMP_HTML=$(mktemp /tmp/verify-room-links.XXXXXX.html)
trap 'rm -f "$TMP_BUNDLE" "$TMP_HTML"' EXIT

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Room Link (Periodensystem) Verification"
echo "  Target: https://${HOST}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Live index bundle has NO broken /hub/-prefixed room-link pattern
# ---------------------------------------------------------------------------
curl -sk --max-time 30 "$LIVE_BUNDLE_URL" -o "$TMP_BUNDLE"
BROKEN_COUNT=$(grep -c 'href="/hub/"+[A-Za-z_$][A-Za-z0-9_$]*\.hub_id' "$TMP_BUNDLE" 2>/dev/null || true)
if [[ "${BROKEN_COUNT:-1}" == "0" ]]; then
  pass "Live bundle has no broken '/hub/<id>/' room-link pattern"
else
  fail "Live bundle contains broken room-link pattern (count: ${BROKEN_COUNT:-?}) — room links bounce to landing page"
fi

# ---------------------------------------------------------------------------
# Test 2: Live index bundle HAS the fixed canonical room-link pattern
# ---------------------------------------------------------------------------
FIXED_COUNT=$(grep -c 'href="/"+[A-Za-z_$][A-Za-z0-9_$]*\.hub_id' "$TMP_BUNDLE" 2>/dev/null || true)
if [[ "${FIXED_COUNT:-0}" -ge 1 ]]; then
  pass "Live bundle builds room links as /<hub_id>/<slug> (canonical format)"
else
  fail "Live bundle is missing the fixed room-link pattern — chemie-portal room links broken"
fi

# ---------------------------------------------------------------------------
# Test 3: Local bind-mounted bundle matches live bundle (mount sanity)
# ---------------------------------------------------------------------------
if [[ -f "$LOCAL_BUNDLE" ]] && cmp -s "$TMP_BUNDLE" "$LOCAL_BUNDLE"; then
  pass "Local bundle ${LOCAL_BUNDLE} matches live bundle (bind mount in sync)"
else
  fail "Local bundle ${LOCAL_BUNDLE} differs from live bundle — patch the file, then recreate hubs-client (sed -i changes the inode and breaks single-file bind mounts)"
fi

# ---------------------------------------------------------------------------
# Helper: pick a live room id from the element API (Periodensystem H list)
# ---------------------------------------------------------------------------
read -r ROOM_ID ROOM_SLUG <<< "$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null \
  | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    hubs = [h for h in d.get('hubs', []) if h.get('slug')]
    if hubs:
        h = hubs[0]
        print(h['hub_id'], h['slug'])
except Exception:
    pass
" 2>/dev/null)"

# ---------------------------------------------------------------------------
# Test 4: Canonical room URL /<hub_id>/<slug> serves hub.html
# ---------------------------------------------------------------------------
if [[ -n "${ROOM_ID:-}" && -n "${ROOM_SLUG:-}" ]]; then
  curl -sk --max-time 30 "https://${HOST}/${ROOM_ID}/${ROOM_SLUG}" -o "$TMP_HTML"
  if grep -q 'id="ui-root"' <<< "$(cat "$TMP_HTML")"; then
    pass "Canonical room URL /${ROOM_ID}/${ROOM_SLUG} serves hub.html (ui-root)"
  else
    fail "Canonical room URL /${ROOM_ID}/${ROOM_SLUG} does NOT serve hub.html"
  fi
else
  fail "Could not fetch a live room from the element API — cannot verify canonical room URL routing"
fi

# ---------------------------------------------------------------------------
# Test 5: Legacy broken URL /hub/<hub_id>/<slug> falls back to index.html
# ---------------------------------------------------------------------------
# This documents the failure mode. The static server is expected to serve the
# SPA fallback here; the client bundles must simply never generate this form.
if [[ -n "${ROOM_ID:-}" ]]; then
  curl -sk --max-time 30 "https://${HOST}/hub/${ROOM_ID}/${ROOM_SLUG}" -o "$TMP_HTML"
  if grep -q 'id="home-root' <<< "$(cat "$TMP_HTML")"; then
    pass "Legacy /hub/<id>/<slug> URL falls back to index.html (client must not generate it — bundle verified in Test 1)"
  else
    pass "Legacy /hub/<id>/<slug> URL does not serve index.html (routing changed? informational)"
  fi
fi

# ---------------------------------------------------------------------------
# Test 6: Landing page still serves index.html (SPA fallback unregressed)
# ---------------------------------------------------------------------------
curl -sk --max-time 30 "https://${HOST}/" -o "$TMP_HTML"
if grep -q 'id="home-root' <<< "$(cat "$TMP_HTML")"; then
  pass "Landing page / serves index.html (home-root)"
else
  fail "Landing page / does not serve index.html"
fi

# ---------------------------------------------------------------------------
# Test 7: End-to-end — every Periodensystem room link target serves hub.html
# ---------------------------------------------------------------------------
ROOM_TARGETS=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null \
  | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for h in d.get('hubs', []):
        if h.get('slug'):
            print(f\"{h['hub_id']}/{h['slug']}\")
except Exception:
    pass
" 2>/dev/null)

if [[ -n "$ROOM_TARGETS" ]]; then
  TOTAL=0; GOOD=0
  while IFS= read -r target; do
    TOTAL=$((TOTAL+1))
    BODY=$(curl -sk --max-time 30 "https://${HOST}/${target}")
    if grep -q 'id="ui-root"' <<< "$BODY"; then
      GOOD=$((GOOD+1))
    else
      echo "        room /${target} does not serve hub.html"
    fi
  done <<< "$ROOM_TARGETS"
  if [[ "$GOOD" -eq "$TOTAL" && "$TOTAL" -gt 0 ]]; then
    pass "All ${TOTAL} Periodensystem (element/h) room links serve hub.html"
  else
    fail "Only ${GOOD}/${TOTAL} Periodensystem room links serve hub.html"
  fi
else
  fail "Element API returned no rooms with slugs — cannot run end-to-end link check"
fi

echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
