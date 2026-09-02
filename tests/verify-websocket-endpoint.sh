#!/bin/bash
# verify-websocket-endpoint.sh — Verify the Phoenix socket endpoint routes correctly.
#
# Checks:
#   1. GET /socket/websocket?vsn=2.0.0 WITHOUT upgrade headers must return
#      HTTP 426 Upgrade Required (measured).
#   2. HTTP 404/502/503 means routing is broken.
#
# Run with: bash tests/verify-websocket-endpoint.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

HOST="hubs.chemie-lernen.org"
BASE="https://${HOST}"
ENDPOINT="/socket/websocket?vsn=2.0.0"
URL="${BASE}${ENDPOINT}"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Phoenix Socket Endpoint Verification"
echo "  Host:     ${HOST}"
echo "  Endpoint: ${ENDPOINT}"
echo "  URL:      ${URL}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: GET /socket/websocket?vsn=2.0.0 WITHOUT upgrade headers
#         must return HTTP 426 Upgrade Required
# ---------------------------------------------------------------------------
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${URL}")

if [[ "$CODE" == "426" ]]; then
  pass "GET ${ENDPOINT} without upgrade headers returns HTTP 426 Upgrade Required"
elif [[ "$CODE" == "404" ]] || [[ "$CODE" == "502" ]] || [[ "$CODE" == "503" ]]; then
  fail "GET ${ENDPOINT} returned HTTP ${CODE} — routing is BROKEN (expected 426)"
else
  fail "GET ${ENDPOINT} returned HTTP ${CODE} (expected 426 Upgrade Required)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
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
