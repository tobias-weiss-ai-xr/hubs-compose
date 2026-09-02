#!/bin/bash
# Verification script for Reticulum API endpoints
#
# Verifies that:
#   1. /api/v1/meta returns HTTP 200 with required fields: version, phx_port, phx_host
#   2. /api/v1/hubs returns a JSON array (or HTTP 404 if no hubs exist)
#   3. TURN credential endpoint exists and returns a valid response
#
# Run with: bash tests/verify-reticulum-api.sh
#
# Conventions honored:
#   - NO `set -e`: verification scripts must run ALL tests and report full matrix
#   - Uses FAILED=$((FAILED+1)) not ((FAILED++)) because `set -e` treats exit 1 fatal
#   - Uses here-strings, not pipes, for grep on large inputs
#   - Uses `set -uo pipefail`

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Reticulum API Verification"
echo "  Target: ${BASE}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: /api/v1/meta returns HTTP 200
# ---------------------------------------------------------------------------
echo "Test 1: /api/v1/meta returns HTTP 200"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${BASE}/api/v1/meta")
if [[ "$CODE" == "200" ]]; then
  pass "/api/v1/meta returns HTTP 200"
else
  fail "/api/v1/meta returns HTTP ${CODE} (expected 200)"
fi

# ---------------------------------------------------------------------------
# Test 2: /api/v1/meta response contains required fields
# ---------------------------------------------------------------------------
echo ""
echo "Test 2: /api/v1/meta response contains required fields"
BODY=$(curl -sk --max-time 20 "${BASE}/api/v1/meta")

for field in version phx_port phx_host; do
  if grep -q "\"${field}\"" <<< "$BODY"; then
    pass "/api/v1/meta contains '${field}' field"
  else
    fail "/api/v1/meta missing '${field}' field"
  fi
done

# ---------------------------------------------------------------------------
# Test 3: /api/v1/hubs returns 200 with JSON array or 404
# ---------------------------------------------------------------------------
echo ""
echo "Test 3: /api/v1/hubs returns valid response"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${BASE}/api/v1/hubs")
BODY=$(curl -sk --max-time 20 "${BASE}/api/v1/hubs")

if [[ "$CODE" == "200" ]]; then
  # Check if response is a JSON array
  if grep -q '^\[\|^\s*\[\s*' <<< "$BODY"; then
    pass "/api/v1/hubs returns HTTP 200 with JSON array"
  else
    fail "/api/v1/hubs returns HTTP 200 but not a JSON array: ${BODY:0:100}"
  fi
elif [[ "$CODE" == "404" ]]; then
  pass "/api/v1/hubs returns HTTP 404 (no hubs exist)"
else
  fail "/api/v1/hubs returns HTTP ${CODE} (expected 200 or 404)"
fi

# ---------------------------------------------------------------------------
# Test 4: TURN credential endpoint behavior
# ---------------------------------------------------------------------------
echo ""
echo "Test 4: TURN credential endpoint exists and responds"
# The TURN credential endpoint is at /api/v1/turn-credentials
# It should exist and return a valid HTTP response (not 5xx server error)
# It may return 404 with "bad Room ID" if no room parameter is provided
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${BASE}/api/v1/turn-credentials")

# We accept any non-5xx response as valid - the endpoint exists and responds
# 2xx = success (with valid room ID)
# 4xx = client error (missing/invalid room ID, or not authenticated)
# 5xx = server error (would be a failure)
if [[ "$CODE" =~ ^[24][0-9]{2}$ ]]; then
  pass "TURN credential endpoint returns HTTP ${CODE} (endpoint exists and responds)"
else
  fail "TURN credential endpoint returns HTTP ${CODE} (unexpected server error)"
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
  echo "❌ Some tests failed. Check the output above."
  exit 1
else
  echo ""
  echo "✅ All tests passed!"
  exit 0
fi
