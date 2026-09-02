#!/usr/bin/env bash
# verify-docker-volumes.sh — Verify Docker volumes are healthy and present
#
# Verifies that:
#   1. Docker daemon is accessible
#   2. compose_postgres_data volume exists
#   3. compose_redis_data volume exists
#   4. letsencrypt/ACM E certificate volume exists
#   5. Hubs compose service volumes exist
#   6. Volume data is accessible (via docker exec)
#
# Run with: bash tests/verify-docker-volumes.sh

set -uo pipefail

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Docker Volume Verification"
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
# Test 2: compose_postgres_data volume exists
# ---------------------------------------------------------------------------
echo -n "Test 2: compose_postgres_data volume exists... "
if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q 'compose_postgres_data'; then
  pass "compose_postgres_data volume present"
else
  fail "compose_postgres_data volume not found"
fi

# ---------------------------------------------------------------------------
# Test 3: compose_redis_data volume exists
# ---------------------------------------------------------------------------
echo -n "Test 3: compose_redis_data volume exists... "
if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q 'compose_redis_data'; then
  pass "compose_redis_data volume present"
else
  fail "compose_redis_data volume not found"
fi

# ---------------------------------------------------------------------------
# Test 4: LetsEncrypt ACME certificate volume exists
# ---------------------------------------------------------------------------
echo -n "Test 4: LetsEncrypt ACME volume exists... "
le_volume=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -iE 'letsencrypt|acme' | head -1)
if [[ -n "$le_volume" ]]; then
  pass "ACME certificate volume present: $le_volume"
else
  fail "No LetsEncrypt/ACME volume found"
fi

# ---------------------------------------------------------------------------
# Test 5: Hubs compose service volumes exist
# ---------------------------------------------------------------------------
echo -n "Test 5: Hubs compose service volumes exist... "
hubs_vols=$(docker volume ls --format '{{.Name}}' 2>/dev/null | grep -c '^hubs-')
if [[ "$hubs_vols" -ge 3 ]]; then
  pass "Found $hubs_vols hubs-* volumes"
else
  fail "Only found $hubs_vols hubs-* volumes (expected >= 3)"
fi

# ---------------------------------------------------------------------------
# Test 6: Volume data is accessible via docker exec
# ---------------------------------------------------------------------------
echo -n "Test 6: Volume data is accessible... "
# Docker volume mountpoints are owned by root and may not be accessible from
# the host. Instead, check data via docker exec into the container that mounts it.
pg_data=$(docker exec hubs-db ls /var/lib/postgresql/data/ 2>/dev/null | head -3)
if [[ -n "$pg_data" ]]; then
  pass "PostgreSQL volume data accessible (files: $(echo "$pg_data" | tr '\n' ' '))"
else
  # Fallback: check volume usage via docker system df
  vol_size=$(docker system df --format '{{.Name}} {{.Size}}' 2>/dev/null | grep 'compose_postgres_data' | awk '{print $2}')
  if [[ -n "$vol_size" ]]; then
    pass "PostgreSQL volume has data ($vol_size)"
  else
    fail "No volume data accessible"
  fi
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
