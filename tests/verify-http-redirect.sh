#!/usr/bin/env bash
#
# verify-http-redirect.sh — Verify that HTTP port 80 redirects to HTTPS
#
# Checks:
#   1. http://hubs.chemie-lernen.org/ returns HTTP 308 Permanent Redirect
#   2. The Location response header points to https://
#
# Run with: bash tests/verify-http-redirect.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

HOST="hubs.chemie-lernen.org"
HTTP_URL="http://${HOST}/"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "HTTP to HTTPS Redirect Verification"
echo "  Target: ${HTTP_URL}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: HTTP endpoint returns 308 Permanent Redirect (HEAD request)
# ---------------------------------------------------------------------------
# Use HEAD request to get the redirect status without following it
HTTP_CODE=$(curl -sk -I -o /dev/null -w '%{http_code}' --max-time 20 "${HTTP_URL}" 2>/dev/null)
if [[ "$HTTP_CODE" == "308" ]]; then
  pass "HTTP ${HTTP_URL} returns 308 Permanent Redirect"
else
  fail "HTTP ${HTTP_URL} returned HTTP ${HTTP_CODE:-n/a} (expected 308)"
fi

# ---------------------------------------------------------------------------
# Test 2: HTTP endpoint returns 3xx redirect (fallback check for GET)
# ---------------------------------------------------------------------------
GET_HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "${HTTP_URL}" 2>/dev/null)
if [[ "$GET_HTTP_CODE" =~ ^3[0-9]{2}$ ]]; then
  pass "HTTP GET ${HTTP_URL} returns a 3xx redirect status (${GET_HTTP_CODE})"
else
  fail "HTTP GET ${HTTP_URL} did not return a 3xx redirect (got ${GET_HTTP_CODE:-n/a})"
fi

# ---------------------------------------------------------------------------
# Test 3: Location header points to HTTPS (from HEAD request)
# ---------------------------------------------------------------------------
LOCATION=$(curl -sk -I -o /dev/null -w '%{redirect_url}' --max-time 20 "${HTTP_URL}" 2>/dev/null)
if [[ -n "$LOCATION" ]]; then
  if grep -q '^https://' <<< "$LOCATION"; then
    pass "Location header points to HTTPS: ${LOCATION}"
  else
    fail "Location header does not start with https://: ${LOCATION:-unavailable}"
  fi
else
  # Fallback: parse headers directly
  HEADER_OUTPUT=$(curl -sk -I --max-time 20 "${HTTP_URL}" 2>/dev/null)
  LOCATION=$(grep -i '^Location:' <<< "$HEADER_OUTPUT" | tail -1 | sed 's/^[[:space:]]*Location:[[:space:]]*//' | tr -d '\r')
  if [[ -n "$LOCATION" ]]; then
    if grep -q '^https://' <<< "$LOCATION"; then
      pass "Location header points to HTTPS: ${LOCATION}"
    else
      fail "Location header does not start with https://: ${LOCATION}"
    fi
  else
    fail "No Location header found in HTTP redirect response"
  fi
fi

# ---------------------------------------------------------------------------
# Test 4: Location header points to the same host over HTTPS
# ---------------------------------------------------------------------------
if [[ -n "$LOCATION" ]]; then
  if grep -qi "${HOST}" <<< "$LOCATION"; then
    pass "Location header targets the same host: ${HOST}"
  else
    fail "Location header does not target ${HOST}: ${LOCATION}"
  fi
fi

# ---------------------------------------------------------------------------
# Test 5: Verify the redirect chain ends at HTTPS (follow redirects)
# ---------------------------------------------------------------------------
FINAL_URL=$(curl -sk -L -o /dev/null -w '%{url_effective}' --max-time 20 "${HTTP_URL}" 2>/dev/null)
if [[ -n "$FINAL_URL" ]]; then
  if grep -q '^https://' <<< "$FINAL_URL"; then
    pass "Final URL after following redirects is HTTPS: ${FINAL_URL}"
  else
    fail "Final URL after following redirects is not HTTPS: ${FINAL_URL}"
  fi
else
  fail "Could not determine final URL after following redirects"
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
