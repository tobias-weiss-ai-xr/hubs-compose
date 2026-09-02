#!/usr/bin/env bash
#
# verify-element-api-contract.sh — Verify the Periodensystem element API
# response contract and its ~1 request/second throttle behavior.
#
# The home page's Periodensystem room list is served by the Reticulum fork
# endpoint GET /api/v1/hubs/element/<symbol>. Two properties are checked:
#
#   A. Response contract — the endpoint returns valid JSON: an object with a
#      "hubs" array, and every hub entry carries the `hub_id`, `slug` and
#      `scene` fields the Hubs client depends on (room links, PSE theming).
#
#   B. Throttle — the endpoint throttles to ~1 request/second per source IP.
#      A small burst (~2 requests) is served with HTTP 200, then further
#      rapid requests are answered HTTP 403 "Forbidden" until the token
#      bucket refills (~1s); after a short cooldown the endpoint recovers to
#      200 again. (Observed on live: 200,200,403,403 and 200,403,403,403 on
#      rapid-fire; recovery after ~2-3s.)
#
# Checks:
#   Contract:
#     1. GET /api/v1/hubs/element/H returns HTTP 200
#     2. Response is a JSON object envelope ({ ... "hubs": [...] })
#     3. "hubs" array is non-empty (at least one hub)
#     4. Every hub entry carries a non-empty "hub_id"
#     5. Every hub entry carries a non-empty "slug"
#     6. Every hub entry carries a "scene" field
#     7. Scene payloads are populated (each scene has a "scene_id")
#     8. hub_id values match the canonical 7-char room-id format
#   Throttle (~1 rps, burst 2 then 403):
#     9.  After a cooldown a single request returns 200 (bucket refilled)
#    10. A rapid burst is capped at the documented ~1 rps allowance —
#        1..2 × 200 then 403, never an unlimited run of 200s
#    11. Throttled responses are HTTP 403 (not 429 / not a 5xx outage)
#    12. After a cooldown the endpoint recovers to 200 again
#
# Run with: bash tests/verify-element-api-contract.sh
#
# Conventions:
#   - NO `set -e`: a verification script must run ALL checks and report the
#     full matrix, never bail on the first failure
#   - Uses FAILED=$((FAILED+1)), never ((FAILED++)) — the latter returns exit
#     status 1 when the counter is 0, which `set -e` would treat as fatal
#   - grep -q and count extraction fed via here-strings, never pipes
#     (`echo $large | grep -q` can SIGPIPE on 1.6MB bundles)
#   - Uses `set -uo pipefail`
#   - curl -sk --max-time 20 for live HTTP checks

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"
ENDPOINT="${BASE}/api/v1/hubs/element/H"

TMP_BODY=$(mktemp /tmp/verify-element-api.XXXXXX.json)
trap 'rm -f "$TMP_BODY"' EXIT

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# ---------------------------------------------------------------------------
# fetch_contract_body — pull a clean 200 response into $CODE/$BODY.
# Retries with pacing because the throttle may still 403 a leftover burst.
# ---------------------------------------------------------------------------
fetch_contract_body() {
  local attempt code
  for attempt in 1 2 3 4 5; do
    sleep 1.5
    code=$(curl -sk --max-time 20 -o "$TMP_BODY" -w "%{http_code}" "$ENDPOINT" 2>/dev/null)
    if [[ "$code" == "200" ]]; then
      CODE="$code"
      BODY=$(cat "$TMP_BODY")
      return 0
    fi
  done
  CODE="${code:-000}"
  BODY=""
  return 1
}

echo "=========================================="
echo "Element API Contract + Throttle Verification"
echo "  Target: ${ENDPOINT}"
echo "=========================================="
echo ""

# Let any pre-existing throttle drain from this source IP before probing.
sleep 3

# ---------------------------------------------------------------------------
# Group A — response contract
# ---------------------------------------------------------------------------
echo "*** Response contract ***"

fetch_contract_body

# Test 1: HTTP 200
if [[ "$CODE" == "200" ]]; then
  pass "GET /api/v1/hubs/element/H returns HTTP 200"
else
  fail "GET /api/v1/hubs/element/H returns HTTP ${CODE} (expected 200)"
fi

# Test 2: JSON object envelope
if [[ "$BODY" == \{* && "$BODY" == *\} ]] && grep -q '"hubs":' <<< "$BODY"; then
  pass "Response is a JSON object with a 'hubs' array"
else
  fail "Response is not a JSON object with a 'hubs' array: ${BODY:0:80}"
fi

# Compute per-field occurrence counts from the (single-line) JSON body.
HUB_COUNT=$(grep -o '"hub_id"' <<< "$BODY" | wc -l)
NONEMPTY_IDS=$(grep -oE '"hub_id":"[^"]+"' <<< "$BODY" | wc -l)
NONEMPTY_SLUGS=$(grep -oE '"slug":"[^"]+"' <<< "$BODY" | wc -l)
SCENE_COUNT=$(grep -o '"scene":' <<< "$BODY" | wc -l)
SCENE_ID_COUNT=$(grep -o '"scene_id":' <<< "$BODY" | wc -l)

# Test 3: at least one hub
if [[ "${HUB_COUNT:-0}" -ge 1 ]]; then
  pass "'hubs' array is non-empty (${HUB_COUNT} hub(s))"
else
  fail "'hubs' array is empty or missing — element API returned no rooms"
fi

# Test 4: every hub carries non-empty hub_id
if [[ "${HUB_COUNT:-0}" -ge 1 && "${NONEMPTY_IDS:-0}" -eq "${HUB_COUNT:-0}" ]]; then
  pass "Every hub entry carries a non-empty 'hub_id' (${NONEMPTY_IDS}/${HUB_COUNT})"
else
  fail "Not every hub entry has a non-empty 'hub_id' (${NONEMPTY_IDS:-0}/${HUB_COUNT:-0})"
fi

# Test 5: every hub carries non-empty slug
if [[ "${HUB_COUNT:-0}" -ge 1 && "${NONEMPTY_SLUGS:-0}" -eq "${HUB_COUNT:-0}" ]]; then
  pass "Every hub entry carries a non-empty 'slug' (${NONEMPTY_SLUGS}/${HUB_COUNT})"
else
  fail "Not every hub entry has a non-empty 'slug' (${NONEMPTY_SLUGS:-0}/${HUB_COUNT:-0})"
fi

# Test 6: every hub carries a scene field
if [[ "${HUB_COUNT:-0}" -ge 1 && "${SCENE_COUNT:-0}" -eq "${HUB_COUNT:-0}" ]]; then
  pass "Every hub entry carries a 'scene' field (${SCENE_COUNT}/${HUB_COUNT})"
else
  fail "Not every hub entry has a 'scene' field (${SCENE_COUNT:-0}/${HUB_COUNT:-0})"
fi

# Test 7: scene payloads are populated (scene_id present)
if [[ "${SCENE_ID_COUNT:-0}" -ge 1 ]]; then
  pass "Scene payloads are populated ('scene_id' present in ${SCENE_ID_COUNT} hub(s))"
else
  fail "Scene payloads are empty — no hub carries a scene with a 'scene_id'"
fi

# Test 8: canonical 7-char room-id format
if grep -qE '"hub_id":"[A-Za-z0-9]{7}"' <<< "$BODY"; then
  pass "hub_id values match the canonical 7-char room-id format"
else
  fail "No hub_id matches the canonical 7-char room-id format"
fi

# ---------------------------------------------------------------------------
# Group B — throttle behavior (~1 rps, burst 2 then 403)
# ---------------------------------------------------------------------------
echo ""
echo "*** Throttle (~1 rps, burst 2 then 403) ***"

# Test 9: recovery — after a cooldown the endpoint serves a single request
sleep 3
PROBE=$(curl -sk --max-time 20 -o /dev/null -w "%{http_code}" "$ENDPOINT" 2>/dev/null)
if [[ "$PROBE" == "200" ]]; then
  pass "After cooldown a single request returns 200 (bucket refilled)"
else
  fail "After cooldown a single request returns HTTP ${PROBE} (expected 200)"
fi

# Let the bucket refill fully, then fire a rapid burst of 5.
sleep 2
SUCCESSES=0
THROTTLED=0
OTHER=0
OTHER_CODES=""
for i in 1 2 3 4 5; do
  RC=$(curl -sk --max-time 20 -o /dev/null -w "%{http_code}" "$ENDPOINT" 2>/dev/null)
  case "$RC" in
    200) SUCCESSES=$((SUCCESSES+1)) ;;
    403) THROTTLED=$((THROTTLED+1)) ;;
    *)   OTHER=$((OTHER+1)); OTHER_CODES="${OTHER_CODES} ${RC:-000}" ;;
  esac
done

# Test 10: burst is capped at the documented ~1 rps allowance
if [[ "$SUCCESSES" -ge 1 && "$THROTTLED" -ge 1 && "$SUCCESSES" -le 2 ]]; then
  pass "Rapid burst capped as documented: ${SUCCESSES}×200 then ${THROTTLED}×403 (~1 rps, max burst ~2)"
else
  fail "Burst pattern unexpected (${SUCCESSES}×200, ${THROTTLED}×403) — expected 1–2×200 then 403"
fi

# Test 11: throttled responses are exactly HTTP 403, not 429 or a 5xx outage
if [[ "$OTHER" -eq 0 ]]; then
  pass "All throttled burst responses are HTTP 403 (no 429 / no 5xx)"
else
  fail "Burst produced non-403 response(s):${OTHER_CODES} — possible endpoint outage"
fi

# Test 12: recovery after throttle
sleep 3
PROBE2=$(curl -sk --max-time 20 -o /dev/null -w "%{http_code}" "$ENDPOINT" 2>/dev/null)
if [[ "$PROBE2" == "200" ]]; then
  pass "After throttle cooldown the endpoint recovers to 200 again"
else
  fail "After throttle cooldown the endpoint returns HTTP ${PROBE2} (expected 200)"
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
  echo "❌ Some checks failed. See the matrix above."
  exit 1
else
  echo ""
  echo "✅ All checks passed!"
  exit 0
fi
