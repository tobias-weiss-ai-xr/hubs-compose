#!/usr/bin/env bash
# verify-healthchecks-defined.sh — Verify critical containers define a Docker healthcheck
#
# Uses `docker inspect .Config.Healthcheck` to confirm each critical container
# has a healthcheck configured at the image/config level.
#
# Containers that MUST define a healthcheck:
#   hubs-db        hubs-reticulum  hubs-client
#   hubs-dialog    hubs-spoke      hubs-admin
#
# hubs-coturn by design has NO healthcheck configured. Its absence is reported
# as a FINDING (informational warning) but must NOT fail the script.
#
# Run with: bash tests/verify-healthchecks-defined.sh

set -uo pipefail

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# Containers that MUST define a healthcheck
REQUIRED_CONTAINERS=(
  "hubs-db"
  "hubs-reticulum"
  "hubs-client"
  "hubs-dialog"
  "hubs-spoke"
  "hubs-admin"
)

# Containers whose healthcheck absence is acceptable/tolerated (FINDING only)
FINDING_CONTAINERS=(
  "hubs-coturn"
)

echo "=========================================="
echo "Critical Container Healthcheck Verification"
echo "  Method: docker inspect .Config.Healthcheck"
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
# Helper: does the container define a healthcheck?
#   Returns 0 if .Config.Healthcheck is a non-empty object, 1 otherwise.
#   Recognizes "null", "<no value>", and empty output as "not defined".
#   On inspect failure (missing container, docker error) also returns 1.
# ---------------------------------------------------------------------------
healthcheck_defined() {
  local container="$1"
  local hc
  # If docker inspect fails (missing container, inspect error) treat as not defined
  if ! hc=$(docker inspect --format '{{json .Config.Healthcheck}}' "$container" 2>/dev/null); then
    return 1
  fi
  # Strip any stray newline/CR that docker may emit alongside an error
  hc="${hc//[$'\r\n']/}"
  if [[ -z "$hc" || "$hc" == "null" || "$hc" == "<no value>" ]]; then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Test 2: Required containers MUST define a healthcheck
# ---------------------------------------------------------------------------
echo ""
echo "Checking ${#REQUIRED_CONTAINERS[@]} required containers:"
for container in "${REQUIRED_CONTAINERS[@]}"; do
  echo -n "  $container... "
  if healthcheck_defined "$container"; then
    cmd=$(docker inspect --format '{{.Config.Healthcheck.Test}}' "$container" 2>/dev/null || echo "?")
    pass "$container — healthcheck defined → ${cmd}"
  else
    if docker inspect "$container" >/dev/null 2>&1; then
      hc=$(docker inspect --format '{{json .Config.Healthcheck}}' "$container" 2>/dev/null || true)
      hc="${hc//[$'\r\n']/}"
      fail "$container — healthcheck NOT defined (.Config.Healthcheck = '${hc}')"
    else
      fail "$container — container missing or inspect failed (healthcheck cannot be verified)"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Test 3: hubs-coturn — FINDING if no healthcheck (must NOT fail)
# ---------------------------------------------------------------------------
echo ""
echo "Checking tolerated containers (FINDING only, non-fatal):"
for container in "${FINDING_CONTAINERS[@]}"; do
  echo -n "  $container... "
  if healthcheck_defined "$container"; then
    cmd=$(docker inspect --format '{{.Config.Healthcheck.Test}}' "$container" 2>/dev/null || echo "?")
    pass "$container — healthcheck defined → ${cmd}"
  else
    echo "  ⚠️  FINDING: $container has NO healthcheck configured (.Config.Healthcheck = null)"
    echo "        Reported as a finding; does not fail this script."
    pass "$container — no healthcheck (FINDING reported, tolerated)"
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
