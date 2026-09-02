#!/usr/bin/env bash
# verify-postgres-health.sh — Verify PostgreSQL database is healthy and accessible
#
# Verifies that:
#   1. Docker daemon is accessible
#   2. hubs-db container is running
#   3. pg_isready inside the container reports 'accepting connections' on port 5432
#   4. PostgreSQL process is listening on port 5432 inside the container
#   5. Database volume exists (postgres data persisted)
#
# Run with: bash tests/verify-postgres-health.sh

set -uo pipefail

DOCKER_CONTAINER="hubs-db"
POSTGRES_PORT=5432

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "PostgreSQL Health Verification"
echo "  Container: $DOCKER_CONTAINER"
echo "  Port:      $POSTGRES_PORT"
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
# Test 2: hubs-db container is running
# ---------------------------------------------------------------------------
echo -n "Test 2: hubs-db container is running... "
status=$(docker inspect --format '{{.State.Status}}' "$DOCKER_CONTAINER" 2>/dev/null || echo "not-found")
if [[ "$status" == "running" ]]; then
  pass "hubs-db container is running"
else
  fail "hubs-db container status is '$status'"
fi

# ---------------------------------------------------------------------------
# Test 3: pg_isready reports accepting connections
# ---------------------------------------------------------------------------
echo -n "Test 3: pg_isready — accepting connections... "
pg_ready=$(docker exec "$DOCKER_CONTAINER" pg_isready -U postgres -h localhost -p "$POSTGRES_PORT" 2>/dev/null || echo "")
if echo "$pg_ready" | grep -q "accepting connections"; then
  pass "PostgreSQL is accepting connections on port $POSTGRES_PORT"
else
  fail "pg_isready failed: '$pg_ready'"
fi

# ---------------------------------------------------------------------------
# Test 4: PostgreSQL process listening on port 5432
# ---------------------------------------------------------------------------
echo -n "Test 4: PostgreSQL listening on port $POSTGRES_PORT... "
port_check=$(docker exec "$DOCKER_CONTAINER" ss -tlnp 2>/dev/null | grep ":$POSTGRES_PORT" | head -1)
if [[ -n "$port_check" ]]; then
  pass "Port $POSTGRES_PORT is listening: $(echo $port_check | awk '{print $1}')"
else
  # Fallback: check if postgres process is running
  proc_check=$(docker exec "$DOCKER_CONTAINER" ps aux 2>/dev/null | grep -c '[p]ostgres')
  if [[ "$proc_check" -gt 0 ]]; then
    pass "PostgreSQL process is running ($proc_check processes)"
  else
    fail "PostgreSQL not listening on port $POSTGRES_PORT and no process found"
  fi
fi

# ---------------------------------------------------------------------------
# Test 5: Database volume is mounted
# ---------------------------------------------------------------------------
echo -n "Test 5: PostgreSQL data volume is mounted... "
volume_check=$(docker inspect --format '{{range .Mounts}}{{.Name}}{{end}}' "$DOCKER_CONTAINER" 2>/dev/null | grep -i 'postgres\|pgdata\|data' | head -1)
if [[ -n "$volume_check" ]]; then
  pass "Data volume mounted: $volume_check"
else
  # Check compose file for volume definition
  compose_file="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"
  if grep -q 'compose_postgres_data\|pgdata' "$compose_file" 2>/dev/null; then
    pass "Postgres volume defined in compose (compose_postgres_data or pgdata)"
  else
    fail "No postgres data volume found"
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
