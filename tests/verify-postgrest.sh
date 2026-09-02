#!/usr/bin/env bash
# verify-postgrest.sh — Verify PostgREST service is accessible
#
# Verifies that:
#   1. Docker daemon is accessible
#   2. hubs-postgrest container is running
#   3. PostgREST responds with HTTP (via container IP or docker network)
#   4. PostgREST returns a non-empty JSON response body
#   5. PostgREST is referenced in docker-compose.hubs.yml
#
# NOTE: PostgREST is an internal service — it does NOT publish ports to the
# host. It is accessible only within the Docker network (container IP or
# container name on the hubs-net network).

set -uo pipefail

DOCKER_CONTAINER="hubs-postgrest"
POSTGREST_PORT=3000
COMPOSE_FILE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "PostgREST Service Verification"
echo "  Container: $DOCKER_CONTAINER"
echo "  Port:      $POSTGREST_PORT (internal Docker network)"
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
# Test 2: hubs-postgrest container is running
# ---------------------------------------------------------------------------
echo -n "Test 2: hubs-postgrest container is running... "
status=$(docker inspect --format '{{.State.Status}}' "$DOCKER_CONTAINER" 2>/dev/null || echo "not-found")
if [[ "$status" == "running" ]]; then
  pass "hubs-postgrest container is running"
else
  fail "hubs-postgrest container status is '$status'"
fi

# ---------------------------------------------------------------------------
# Test 3: PostgREST responds with HTTP (via container IP)
# ---------------------------------------------------------------------------
echo -n "Test 3: PostgREST responds on port $POSTGREST_PORT... "
# Get the container's IP address on the Docker network
container_ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$DOCKER_CONTAINER" 2>/dev/null || echo "")
http_code=""
body_text=""
if [[ -n "$container_ip" ]]; then
  body=$(curl -sk -o - -w "%{http_code}" --max-time 10 "http://${container_ip}:${POSTGREST_PORT}/" 2>/dev/null)
  http_code="${body: -3}"
  body_text="${body%???}"
fi
if [[ "$http_code" =~ ^[0-9]+$ && "$http_code" != "000" ]]; then
  pass "PostgREST responds via container IP ${container_ip}:$POSTGREST_PORT (HTTP $http_code)"
else
  fail "PostgREST not responding via container IP (http_code=$http_code)"
fi

# ---------------------------------------------------------------------------
# Test 4: PostgREST returns non-empty JSON response
# ---------------------------------------------------------------------------
echo -n "Test 4: PostgREST returns non-empty JSON body... "
if [[ -n "$body_text" && "${#body_text}" -gt 0 ]]; then
  pass "PostgREST returned non-empty body (${#body_text} bytes)"
else
  fail "PostgREST returned empty body"
fi

# ---------------------------------------------------------------------------
# Test 5: PostgREST is defined in the compose file
# ---------------------------------------------------------------------------
echo -n "Test 5: hubs-postgrest defined in docker-compose.hubs.yml... "
if grep -q 'hubs-postgrest' "$COMPOSE_FILE" 2>/dev/null; then
  pass "hubs-postgrest found in compose file"
else
  fail "hubs-postgrest not found in compose file"
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
