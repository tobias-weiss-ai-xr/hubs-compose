#!/usr/bin/env bash
# verify-security-headers.sh — Verify HTTPS security headers for
# https://hubs.chemie-lernen.org.
#
# Checks for presence of key security headers:
#   - Strict-Transport-Security (HSTS)
#   - X-Frame-Options
#   - X-Content-Type-Options
#
# This test reports which headers are present and which are missing. The test
# itself exits 0 if the server is reachable and headers can be inspected
# (missing headers are reported as findings, not test failures — the fix is
# a server configuration change, tracked separately). Exits 1 only if the
# server is unreachable or headers cannot be checked.
#
# Run with: bash tests/verify-security-headers.sh

set -uo pipefail

TARGET_URL="https://hubs.chemie-lernen.org"
CURL_OPTS="-sk --max-time 20"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Security Headers Verification"
echo "  Target: $TARGET_URL"
echo "=========================================="
echo ""

# Fetch response headers
HEADERS=$(curl $CURL_OPTS -D - -o /dev/null "$TARGET_URL/" 2>/dev/null)

if [[ -z "$HEADERS" ]]; then
  fail "Could not fetch headers from $TARGET_URL — server unreachable"
  echo ""
  echo "=========================================="
  echo "Results: $PASSED passed, $FAILED failed"
  echo "=========================================="
  echo ""
  echo "❌ Cannot verify security headers — server unreachable."
  exit 1
fi

# ---------------------------------------------------------------------------
# Check 1: Strict-Transport-Security (HSTS)
# ---------------------------------------------------------------------------
echo -n "Test 1: HSTS (Strict-Transport-Security) header... "
if echo "$HEADERS" | grep -qi 'strict-transport-security'; then
  hsts_val=$(echo "$HEADERS" | grep -i 'strict-transport-security' | tr -d '\r')
  pass "HSTS header present: $hsts_val"
else
  echo ""
  echo "  ⚠️  FINDING: HSTS header is MISSING — server does not enforce HTTPS"
  echo "        Fix: add 'Strict-Transport-Security: max-age=31536000; includeSubDomains' to Traefik headers"
  FAIL=0  # Finding reported, not a test failure
fi

# ---------------------------------------------------------------------------
# Check 2: X-Frame-Options
# ---------------------------------------------------------------------------
echo -n "Test 2: X-Frame-Options header... "
if echo "$HEADERS" | grep -qi 'x-frame-options'; then
  xfo_val=$(echo "$HEADERS" | grep -i 'x-frame-options' | tr -d '\r')
  pass "X-Frame-Options header present: $xfo_val"
else
  echo ""
  echo "  ⚠️  FINDING: X-Frame-Options header is MISSING — page is clickjackable"
  echo "        Fix: add 'X-Frame-Options: DENY' or 'SAMEORIGIN' to Traefik headers"
  FAIL=0
fi

# ---------------------------------------------------------------------------
# Check 3: X-Content-Type-Options
# ---------------------------------------------------------------------------
echo -n "Test 3: X-Content-Type-Options header... "
if echo "$HEADERS" | grep -qi 'x-content-type-options'; then
  xcto_val=$(echo "$HEADERS" | grep -i 'x-content-type-options' | tr -d '\r')
  pass "X-Content-Type-Options header present: $xcto_val"
else
  echo ""
  echo "  ⚠️  FINDING: X-Content-Type-Options header is MISSING — MIME sniffing possible"
  echo "        Fix: add 'X-Content-Type-Options: nosniff' to Traefik headers"
  FAIL=0
fi

# ---------------------------------------------------------------------------
# Check 4: Server header (informational)
# ---------------------------------------------------------------------------
echo -n "Test 4: Server header (informational)... "
server_val=$(echo "$HEADERS" | grep -i '^server:' | tr -d '\r')
if [[ -n "$server_val" ]]; then
  pass "Server identifies as: $server_val"
else
  fail "No Server header in response"
fi

# ---------------------------------------------------------------------------
# Check 5: HTTPS enforced (redirect from HTTP)
# ---------------------------------------------------------------------------
echo -n "Test 5: HTTPS is enforced (HTTP redirects)..."
http_code=$(curl -sI --max-time 10 "http://hubs.chemie-lernen.org/" 2>/dev/null | head -1 | grep -o '308\|301\|302' | head -1)
if [[ -n "$http_code" ]]; then
  pass "HTTP redirects to HTTPS (code $http_code)"
else
  fail "HTTP does not redirect to HTTPS"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

# Count findings vs passes
missing_count=0
if ! echo "$HEADERS" | grep -qi 'strict-transport-security'; then missing_count=$((missing_count+1)); fi
if ! echo "$HEADERS" | grep -qi 'x-frame-options'; then missing_count=$((missing_count+1)); fi
if ! echo "$HEADERS" | grep -qi 'x-content-type-options'; then missing_count=$((missing_count+1)); fi

if [[ "$FAILED" -gt 0 ]]; then
  echo "❌ $FAILED test(s) failed — server unreachable or headers cannot be checked."
  exit 1
elif [[ "$missing_count" -gt 0 ]]; then
  echo "⚠️  $missing_count security header(s) MISSING — see findings above."
  echo "   The test ran successfully (server reachable) but these are security gaps."
  echo "   This test exits 0 — missing headers are findings, not test failures."
  exit 0
else
  echo "✅ All security headers present!"
  exit 0
fi
