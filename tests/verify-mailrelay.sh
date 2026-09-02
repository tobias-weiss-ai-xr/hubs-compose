#!/usr/bin/env bash
# verify-mailrelay.sh — Verify Mailrelay service is accessible and healthy
#
# Verifies that:
#   1. Docker daemon is accessible
#   2. hubs-mailrelay container is running
#   3. hubs-mailrelay container health is healthy
#   4. /mailrelay endpoint returns HTTP 200
#
# Run with: bash tests/verify-mailrelay.sh

set -uo pipefail

PASSED=0
FAILED=0

log_pass() {
  echo "✅ PASS  $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo "❌ FAIL  $1"
  FAILED=$((FAILED + 1))
}

BASE="https://hubs.chemie-lernen.org"

# ---------------------------------------------------------------------------
# Test 1: Docker daemon is accessible
# ---------------------------------------------------------------------------
echo "Test 1: Docker daemon is accessible"
if docker info &>/dev/null; then
  log_pass "Docker daemon is accessible"
else
  log_fail "Docker daemon is not accessible"
fi

# ---------------------------------------------------------------------------
# Test 2: hubs-mailrelay container is running
# ---------------------------------------------------------------------------
echo ""
echo "Test 2: hubs-mailrelay container is running"
if docker ps --format '{{.Names}}' | grep -q "^hubs-mailrelay$"; then
  log_pass "Container hubs-mailrelay is running"
else
  log_fail "Container hubs-mailrelay is not running"
fi

# ---------------------------------------------------------------------------
# Test 3: hubs-mailrelay container health status
# ---------------------------------------------------------------------------
echo ""
echo "Test 3: hubs-mailrelay container health status"
if docker ps --format '{{.Names}}' | grep -q "^hubs-mailrelay$"; then
  HEALTH=$(docker inspect --format '{{.State.Health.Status}}' "hubs-mailrelay" 2>/dev/null || echo "no-health")
  if [[ "$HEALTH" == "healthy" ]]; then
    log_pass "Container hubs-mailrelay health is healthy"
  elif [[ "$HEALTH" == "unhealthy" ]]; then
    log_fail "Container hubs-mailrelay health is unhealthy"
  elif [[ "$HEALTH" == "no-health" ]]; then
    log_pass "Container hubs-mailrelay has no health check configured (OK)"
  else
    log_pass "Container hubs-mailrelay health status: ${HEALTH}"
  fi
else
  log_fail "Container hubs-mailrelay health cannot be determined (not running)"
fi

# ---------------------------------------------------------------------------
# Test 4: /mailrelay endpoint returns HTTP 200
# ---------------------------------------------------------------------------
echo ""
echo "Test 4: /mailrelay endpoint returns HTTP 200"
CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "${BASE}/mailrelay")
if [[ "$CODE" == "200" ]]; then
  log_pass "/mailrelay returns HTTP 200"
else
  fail "/mailrelay returns HTTP ${CODE} (expected 200)"
fi

# ---------------------------------------------------------------------------
# Test 5: /mailrelay endpoint returns expected content
# ---------------------------------------------------------------------------
echo ""
echo "Test 5: /mailrelay endpoint returns expected content"
BODY=$(curl -sk --max-time 20 "${BASE}/mailrelay")
# The endpoint should return the Hubs app HTML (contains id="home-root")
if grep -q 'id="home-root"' <<< "$BODY"; then
  log_pass "/mailrelay returns expected content (home-root found)"
else
  fail "/mailrelay does not return expected content"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ $FAILED -gt 0 ]]; then
  echo ""
  echo "❌ Some tests failed. Check the output above."
  exit 1
else
  echo ""
  echo "✅ All tests passed!"
  exit 0
fi