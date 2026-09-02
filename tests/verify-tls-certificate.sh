#!/usr/bin/env bash
#
# verify-tls-certificate.sh — Verify the TLS certificate served by
# https://hubs.chemie-lernen.org.
#
# Checks:
#   1. Site is served over HTTPS and answers HTTP 200.
#   2. TLS chain is valid and trusted (plain curl, no -k / verify_result 0).
#   3. Certificate is retrievable from the server (openssl s_client).
#   4. Certificate Common Name (CN) is hubs.chemie-lernen.org.
#   5. Subject Alternative Name (SAN) includes DNS:hubs.chemie-lernen.org.
#   6. Certificate issuer is Let's Encrypt.
#   7. Certificate is not expired: notAfter > now + 7 days (renewal margin).
#
# Run with: bash tests/verify-tls-certificate.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

HOST="hubs.chemie-lernen.org"
URL="https://${HOST}"
GRACE_SECONDS=$(( 7 * 86400 ))   # 7-day renewal margin

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "TLS Certificate Verification"
echo "  Target: ${URL}"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: HTTPS endpoint is reachable and serves HTTP 200
# ---------------------------------------------------------------------------
CODE=$(curl -sk -o /dev/null -w '%{http_code}' --max-time 20 "${URL}")
if [[ "$CODE" == "200" ]]; then
  pass "HTTPS endpoint ${URL} responds HTTP 200"
else
  fail "HTTPS endpoint ${URL} responded HTTP ${CODE:-n/a} (expected 200)"
fi

# ---------------------------------------------------------------------------
# Test 2: TLS chain validates against the system trust store (no -k)
# ---------------------------------------------------------------------------
VERIFY=$(curl -s -o /dev/null -w '%{ssl_verify_result}' --max-time 20 "${URL}" 2>/dev/null)
if [[ "$VERIFY" == "0" ]]; then
  pass "TLS certificate chain is valid and trusted (ssl_verify_result=0)"
else
  fail "TLS certificate chain failed verification (ssl_verify_result=${VERIFY:-n/a})"
fi

# ---------------------------------------------------------------------------
# Fetch the live certificate once, reuse it for all certificate checks
# ---------------------------------------------------------------------------
if ! command -v openssl >/dev/null 2>&1; then
  fail "openssl not installed — required to inspect the TLS certificate"
  CERT_PEM=""
else
  CERT_PEM=$(echo | timeout 20 openssl s_client \
    -connect "${HOST}:443" \
    -servername "${HOST}" \
    2>/dev/null | openssl x509 -outform PEM 2>/dev/null)
fi

if [[ -n "$CERT_PEM" ]]; then
  pass "Retrieved live TLS certificate from ${HOST}:443"
else
  fail "Could not retrieve TLS certificate from ${HOST}:443"
fi

# ---------------------------------------------------------------------------
# Test: certificate subject CN is hubs.chemie-lernen.org
# ---------------------------------------------------------------------------
SUBJECT=$(printf '%s\n' "$CERT_PEM" | openssl x509 -noout -subject 2>/dev/null)
if grep -qi 'CN[[:space:]]*=[[:space:]]*hubs\.chemie-lernen\.org' <<< "$SUBJECT"; then
  pass "Certificate CN is hubs.chemie-lernen.org (${SUBJECT#subject=})"
else
  fail "Certificate CN mismatch: ${SUBJECT:-unavailable}"
fi

# ---------------------------------------------------------------------------
# Test: SAN includes DNS:hubs.chemie-lernen.org
# ---------------------------------------------------------------------------
SAN=$(printf '%s\n' "$CERT_PEM" | openssl x509 -noout -ext subjectAltName 2>/dev/null)
if grep -qi 'DNS:hubs\.chemie-lernen\.org' <<< "$SAN"; then
  pass "Certificate SAN includes DNS:hubs.chemie-lernen.org"
else
  fail "Certificate SAN missing hubs.chemie-lernen.org: ${SAN:-unavailable}"
fi

# ---------------------------------------------------------------------------
# Test: issuer is Let's Encrypt
# ---------------------------------------------------------------------------
ISSUER=$(printf '%s\n' "$CERT_PEM" | openssl x509 -noout -issuer 2>/dev/null)
if grep -qi "Let's Encrypt" <<< "$ISSUER"; then
  pass "Certificate issuer is Let's Encrypt (${ISSUER#issuer=})"
else
  fail "Certificate issuer is not Let's Encrypt: ${ISSUER:-unavailable}"
fi

# ---------------------------------------------------------------------------
# Test: certificate is not expired — notAfter > now + 7 days
# ---------------------------------------------------------------------------
NOT_AFTER=$(printf '%s\n' "$CERT_PEM" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2-)
NOW=$(date +%s)
NOW_PLUS_GRACE=$(( NOW + GRACE_SECONDS ))
if [[ -n "$NOT_AFTER" ]] && NOT_AFTER_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null); then
  if [[ "$NOT_AFTER_EPOCH" -gt "$NOW_PLUS_GRACE" ]]; then
    REMAINING=$(( (NOT_AFTER_EPOCH - NOW) / 86400 ))
    pass "Certificate not expired: valid for ~${REMAINING} more days (notAfter ${NOT_AFTER}, threshold > 7 days)"
  else
    fail "Certificate expires too soon: notAfter ${NOT_AFTER} is within the 7-day grace window"
  fi
else
  fail "Could not parse certificate notAfter date: ${NOT_AFTER:-unavailable}"
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
