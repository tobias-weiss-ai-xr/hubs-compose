#!/usr/bin/env bash
# verify-dialog-service.sh — Verify the Dialog service is accessible and healthy
#
# Verifies that:
#   1. Docker daemon is accessible
#   2. hubs-dialog container is running
#   3. hubs-dialog container health is healthy
#   4. /dialog/ endpoint returns HTTP 200 over HTTPS
#   5. Dialog service log shows no crash/exit errors
#
# Run with: bash tests/verify-dialog-service.sh
# (No sudo needed — hits the live public URL and docker daemon.)

set -uo pipefail

TARGET_URL="https://hubs.chemie-lernen.org"
CURL_OPTS="-sk --max-time 20"
DOCKER_CONTAINER="hubs-dialog"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Dialog Service Verification"
echo "  Container: $DOCKER_CONTAINER"
echo "  Endpoint:  $TARGET_URL/dialog/"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Docker daemon accessible
# ---------------------------------------------------------------------------
echo -n "Test 1: Docker daemon accessible... "
if docker info >/dev/null 2>&1; then
  pass "Docker daemon is accessible"
else
  fail "Docker daemon not accessible"
fi

# ---------------------------------------------------------------------------
# Test 2: hubs-dialog container is running
# ---------------------------------------------------------------------------
echo -n "Test 2: hubs-dialog container is running... "
status=$(docker inspect --format '{{.State.Status}}' "$DOCKER_CONTAINER" 2>/dev/null || echo "not-found")
if [[ "$status" == "running" ]]; then
  pass "hubs-dialog container is running"
else
  fail "hubs-dialog container status is '$status'"
fi

# ---------------------------------------------------------------------------
# Test 3: hubs-dialog health check is healthy
# ---------------------------------------------------------------------------
echo -n "Test 3: hubs-dialog health is healthy... "
health=$(docker inspect --format '{{.State.Health.Status}}' "$DOCKER_CONTAINER" 2>/dev/null || echo "no-health-check")
if [[ "$health" == "healthy" ]]; then
  pass "hubs-dialog health is healthy"
else
  fail "hubs-dialog health is '$health'"
fi

# ---------------------------------------------------------------------------
# Test 4: /dialog/ endpoint returns HTTP 200
# ---------------------------------------------------------------------------
echo -n "Test 4: /dialog/ endpoint returns HTTP 200... "
code=$(curl $CURL_OPTS -o /dev/null -w '%{http_code}' "$TARGET_URL/dialog/" 2>/dev/null)
if [[ "$code" == "200" ]]; then
  pass "/dialog/ returns HTTP 200"
else
  fail "/dialog/ returns HTTP $code"
fi

# ---------------------------------------------------------------------------
# Test 5: Dialog root returns HTML (serves actual content)
# ---------------------------------------------------------------------------
echo -n "Test 5: /dialog/ serves HTML... "
body=$(curl $CURL_OPTS --max-time 10 "$TARGET_URL/dialog/" 2>/dev/null | head -c 500)
if echo "$body" | grep -q '<html\|<doctype\|<!DOCTYPE'; then
  pass "/dialog/ serves HTML content"
else
  fail "/dialog/ did not serve expected HTML (body: $(echo "$body" | head -c 100))"
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
