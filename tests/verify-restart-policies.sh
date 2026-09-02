#!/usr/bin/env bash
# verify-restart-policies.sh — Verify all critical containers have a restart policy
#
# Verifies that all hubs-stack and infrastructure containers have a restart
# policy of 'unless-stopped' or 'always'. These policies ensure containers
# survive host reboots and accidental docker daemon restarts.
#
# Containers checked:
#   hubs-reticulum  hubs-client     hubs-dialog     hubs-spoke
#   hubs-admin      hubs-db         hubs-postgrest  hubs-coturn
#   hubs-mailrelay  traefik
#
# Run with: bash tests/verify-restart-policies.sh

set -uo pipefail

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# All critical containers that must have a restart policy
CRITICAL_CONTAINERS=(
  "hubs-reticulum"
  "hubs-client"
  "hubs-dialog"
  "hubs-spoke"
  "hubs-admin"
  "hubs-db"
  "hubs-postgrest"
  "hubs-coturn"
  "hubs-mailrelay"
  "traefik"
)

echo "=========================================="
echo "Container Restart Policy Verification"
echo "  Expected: unless-stopped | always"
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
# Test 2: Each critical container has a restart policy
# ---------------------------------------------------------------------------
echo ""
echo "Checking restart policies for ${#CRITICAL_CONTAINERS[@]} containers:"
for container in "${CRITICAL_CONTAINERS[@]}"; do
  echo -n "  $container... "
  policy=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$container" 2>/dev/null || echo "not-found")
  if [[ "$policy" == "unless-stopped" || "$policy" == "always" ]]; then
    pass "$container → $policy"
  else
    fail "$container → '$policy' (expected: unless-stopped or always)"
  fi
done

# ---------------------------------------------------------------------------
# Test 3: All critical containers are running
# ---------------------------------------------------------------------------
echo ""
echo "Checking all critical containers are running:"
for container in "${CRITICAL_CONTAINERS[@]}"; do
  echo -n "  $container... "
  status=$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "not-found")
  if [[ "$status" == "running" ]]; then
    pass "$container → running"
  else
    fail "$container → '$status'"
  fi
done

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
