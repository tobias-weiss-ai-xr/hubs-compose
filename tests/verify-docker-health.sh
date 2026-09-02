#!/usr/bin/env bash

# verify-docker-health.sh — Check all hubs-stack Docker containers are running and healthy

set -uo pipefail

FAILED=0
PASSED=0

log_pass() {
  echo "✅ PASS  $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo "❌ FAIL  $1"
  FAILED=$((FAILED + 1))
}

# Check Docker daemon is accessible
if docker info &>/dev/null; then
  log_pass "Docker daemon is accessible"
else
  log_fail "Docker daemon is not accessible"
fi

# List of expected containers
EXPECTED_CONTAINERS=(
  "hubs-reticulum"
  "hubs-client"
  "hubs-dialog"
  "hubs-spoke"
  "hubs-admin"
  "hubs-db"
  "hubs-postgrest"
  "hubs-mailrelay"
  "hubs-coturn"
  "traefik"
)

# Check each container is running
for container in "${EXPECTED_CONTAINERS[@]}"; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    log_pass "Container ${container} is running"
  else
    log_fail "Container ${container} is not running"
  fi
done

# Check container health status where applicable
for container in "${EXPECTED_CONTAINERS[@]}"; do
  if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
    HEALTH=$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health")
    if [[ "$HEALTH" == "healthy" ]]; then
      log_pass "Container ${container} health is healthy"
    elif [[ "$HEALTH" == "unhealthy" ]]; then
      log_fail "Container ${container} health is unhealthy"
    elif [[ "$HEALTH" == "no-health" ]]; then
      log_pass "Container ${container} has no health check configured (OK)"
    else
      log_pass "Container ${container} health status: ${HEALTH}"
    fi
  fi
done

# Check hubs-client bundle files exist (original or patched)
# The branding fix creates vendor.*.js.patched and index.*.js.patched files
# Before patching, the original hub-*.js and index-*.js files exist
HUB_BUNDLE=$(ls /opt/git/hubs-client-assets/hub-*.js 2>/dev/null | head -1)
INDEX_BUNDLE=$(ls /opt/git/hubs-client-assets/index-*.js 2>/dev/null | head -1)
PATCHED_VENDOR=$(ls /opt/git/hubs-client-assets/vendor.*.js.patched 2>/dev/null | head -1)
PATCHED_INDEX=$(ls /opt/git/hubs-client-assets/index.*.js.patched 2>/dev/null | head -1)

if [[ -n "$HUB_BUNDLE" ]] || [[ -n "$PATCHED_VENDOR" ]]; then
  log_pass "Client bundle files exist"
else
  log_fail "Client bundle files are missing"
fi

# Check docker-compose file exists
if [[ -f "/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml" ]]; then
  log_pass "Live docker-compose file exists"
else
  log_fail "Live docker-compose file is missing"
fi

# Summary
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi

exit 0