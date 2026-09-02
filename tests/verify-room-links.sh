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
#   8. Bundle's create call passes the ElementRoom scene id (mhezdAw) so new
#      Periodensystem rooms are themed instead of loading the placeholder
#      environment (empty dark space)
#   9. Every element-API room carries a scene with model_url (themed rooms)
#  10. The themed scene GLB has lights baked in (KHR_lights_punctual) —
#      without lights PBR materials render pitch black (Hubs disables
#      A-Frame default lights)
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

# The element API throttles to ~1 request/second per IP (403 "Forbidden"
# beyond a small burst — measured 200,200,403,403 on rapid-fire). Pace every
# call and retry on throttle responses.
fetch_element_api() {
  local attempt body
  for attempt in 1 2 3 4 5; do
    sleep 1.1
    body=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null)
    if [[ -n "$body" && "$body" != "Forbidden"* ]]; then
      printf '%s' "$body"
      return 0
    fi
  done
  return 1
}

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
read -r ROOM_ID ROOM_SLUG <<< "$(fetch_element_api | python3 -c "
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
ROOM_TARGETS=$(fetch_element_api | python3 -c "
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

# ---------------------------------------------------------------------------
# Test 8: Create call in the bundle assigns the themed scene
# ---------------------------------------------------------------------------
# Without a scene, new rooms load the placeholder environment (empty dark
# space). The create call must pass the self-hosted ElementRoom scene sid.
SCENE_CALLS=$(grep -c -- '-Raum","mhezdAw",!0,null,{chemistry:' "$TMP_BUNDLE" 2>/dev/null || true)
if [[ "${SCENE_CALLS:-0}" -ge 1 ]]; then
  pass "Create call passes ElementRoom scene (mhezdAw) — new rooms are themed"
else
  fail "Create call does NOT pass a scene — new Periodensystem rooms open in empty dark space"
fi

# ---------------------------------------------------------------------------
# Test 9: Element-API rooms are themed (scene with model_url)
# ---------------------------------------------------------------------------
read -r UNTHEMED TOTAL_SCENED <<< "$(fetch_element_api | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    hubs = d.get('hubs', [])
    unthemed = [h['hub_id'] for h in hubs if not (h.get('scene') or {}).get('model_url')]
    print(len(unthemed), len(hubs))
except Exception:
    print('?', '?')
" 2>/dev/null)"

if [[ "${TOTAL_SCENED:-?}" == "?" ]]; then
  fail "Element API unreachable — cannot verify themed rooms"
elif [[ "${UNTHEMED:-1}" -eq 0 && "${TOTAL_SCENED:-0}" -gt 0 ]]; then
  pass "All ${TOTAL_SCENED} element-API rooms carry a themed scene"
else
  fail "${UNTHEMED:-?}/${TOTAL_SCENED:-?} element-API rooms have no scene (would open in empty dark space)"
fi

# ---------------------------------------------------------------------------
# Test 10: Scene GLB has lights (no-pitch-black-room regression)
# ---------------------------------------------------------------------------
MODEL_URL=$(fetch_element_api | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    for h in d.get('hubs', []):
        s = h.get('scene') or {}
        if s.get('model_url'):
            print(s['model_url'])
            break
except Exception:
    pass
" 2>/dev/null)

if [[ -n "${MODEL_URL:-}" ]]; then
  curl -sk --max-time 30 "$MODEL_URL" -o "$TMP_HTML"
  if python3 - "$TMP_HTML" <<'PYEOF' >/dev/null 2>&1
import struct, json, sys
d = open(sys.argv[1], "rb").read()
assert d[:4] == b"glTF", "not a GLB"
jl = struct.unpack("<II", d[12:20])[0]
j = json.loads(d[20:20+jl])
assert "KHR_lights_punctual" in j.get("extensionsUsed", []), "no lights baked in"
PYEOF
  then
    pass "Scene GLB (${MODEL_URL##*/}) has baked lights (KHR_lights_punctual)"
  else
    fail "Scene GLB has no lights — PBR room renders pitch black"
  fi
else
  fail "No scene model_url found — cannot verify baked lights"
fi

echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
