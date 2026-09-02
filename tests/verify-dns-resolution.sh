#!/bin/bash
# verify-dns-resolution.sh — Verify DNS resolution and Traefik dashboard for
# hubs.chemie-lernen.org.
#
# Checks:
#   1. hubs.chemie-lernen.org resolves via DNS to at least one IPv4 address.
#   2. The resolved address set includes the expected public IP 178.254.2.90.
#   3. https://hubs.chemie-lernen.org/dashboard/ returns HTTP 200.
#   4. /dashboard/ serves non-empty HTML content (sanity check).
#
# DNS is resolved with `host -t A` (queries DNS directly, bypassing /etc/hosts
# so the public A record is verified rather than any local override). If `host`
# is unavailable, `getent ahostsv4` is used as a fallback (note: getent honours
# /etc/hosts first, which may shadow the public record).
#
# Run with: bash tests/verify-dns-resolution.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

HOST="hubs.chemie-lernen.org"
EXPECTED_IP="178.254.2.90"
BASE="https://${HOST}"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "DNS Resolution & Traefik Dashboard Verification"
echo "  Host:     ${HOST}"
echo "  Expected: ${EXPECTED_IP}"
echo "  URL:      ${BASE}/dashboard/"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Resolve A records for HOST once; reuse for the DNS tests.
#
# Prefer `host -t A` (true DNS lookup, ignores /etc/hosts) so we verify the
# public A record. Fall back to `getent ahostsv4` only when `host` is absent.
# RESOLVER records which tool actually produced the addresses for diagnostics.
# ---------------------------------------------------------------------------
ADDRS=""
RESOLVER="none"
if command -v host >/dev/null 2>&1; then
  TMP=$(host -t A "$HOST" 2>/dev/null | awk '/has address/ {print $NF}')
  if [[ -n "$TMP" ]]; then
    ADDRS="$TMP"
    RESOLVER="host"
  fi
fi
if [[ -z "$ADDRS" ]] && command -v getent >/dev/null 2>&1; then
  TMP=$(getent ahostsv4 "$HOST" 2>/dev/null | awk '{print $1}' | sort -u)
  if [[ -n "$TMP" ]]; then
    ADDRS="$TMP"
    RESOLVER="getent"
  fi
fi

# Compact, space-separated render of the resolved addresses for log lines.
ADDRS_DISPLAY=$(tr '\n' ' ' <<< "$ADDRS" | sed 's/ *$//')

# ---------------------------------------------------------------------------
# Test 1: hostname resolves to at least one IPv4 address
# ---------------------------------------------------------------------------
if [[ -n "$ADDRS" ]]; then
  pass "DNS resolves ${HOST} to IPv4 via ${RESOLVER}: ${ADDRS_DISPLAY:-<none>}"
else
  fail "DNS did not resolve ${HOST} to any IPv4 address (tried host/getent)"
fi

# ---------------------------------------------------------------------------
# Test 2: resolved address set includes the expected public IP
# ---------------------------------------------------------------------------
if [[ -n "$ADDRS" ]] && grep -qxF "$EXPECTED_IP" <<< "$ADDRS"; then
  pass "Resolved IP set includes expected ${EXPECTED_IP}"
else
  fail "Resolved IP set does not include expected ${EXPECTED_IP} (got: ${ADDRS_DISPLAY:-<none>})"
fi

# ---------------------------------------------------------------------------
# Test 3: /dashboard/ returns HTTP 200
# ---------------------------------------------------------------------------
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${BASE}/dashboard/")
if [[ "$CODE" == "200" ]]; then
  pass "GET ${BASE}/dashboard/ returns HTTP 200"
else
  fail "GET ${BASE}/dashboard/ returned HTTP ${CODE:-n/a} (expected 200)"
fi

# ---------------------------------------------------------------------------
# Test 4: /dashboard/ serves non-empty HTML content
# ---------------------------------------------------------------------------
BODY=$(curl -sk --max-time 20 "${BASE}/dashboard/" || true)
if [[ -n "$BODY" ]] && grep -qi '<html' <<< "$BODY"; then
  pass "GET ${BASE}/dashboard/ serves HTML content"
else
  fail "GET ${BASE}/dashboard/ did not serve HTML content"
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
