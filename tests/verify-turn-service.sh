#!/bin/bash
# Verification script for the coturn TURN relay service.
#
# Verifies (against the live host) that the WebRTC TURN edge is up and
# correctly configured:
#   1. The live compose file defines the hubs-coturn service with the
#      official coturn/coturn:alpine image and mounts the TURN config.
#   2. The hubs-coturn container is actually running with that image.
#   3. TURN listening port 3478 is bound on BOTH TCP and UDP.
#   4. The TURN config at
#      /opt/containers/hubs-compose/services/coturn/turnserver.conf is valid:
#      it contains realm=..., user=..., and listening-port=3478.
#
# coturn is the STUN/TURN relay that lets Hubs callers on school NATs fall
# back to a media relay when direct P2P is blocked — if it is down, those
# pupils cannot join rooms. Merges touching infra/TURN are gated on this check.
#
# Run with: bash tests/verify-turn-service.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
#
# Port-listening checks read /proc/net/{tcp,udp} directly (port 3478 = 0x0D96)
# instead of invoking ss/netstat/nc, keeping the script self-contained
# (bash + grep only; docker only for the container checks).

set -uo pipefail

COMPOSE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"
CONF="/opt/containers/hubs-compose/services/coturn/turnserver.conf"
CONTAINER="hubs-coturn"
EXPECTED_IMAGE="coturn/coturn:alpine"
TURN_PORT=3478

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# ---------------------------------------------------------------------------
# extract_coturn_block
#
# Prints the hubs-coturn service block from the live compose file: every line
# from `  hubs-coturn:` (2-space indent) up to — but not including — the next
# 2-space-indented service or any 0-indent top-level key (networks:/volumes:).
# Pure bash — only depends on bash per conventions.
# ---------------------------------------------------------------------------
extract_coturn_block() {
  local line in_block=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^[[:space:]]{2}hubs-coturn:[[:space:]]*$ ]]; then
      in_block=1
      continue
    fi
    if [[ "$in_block" -eq 1 ]]; then
      # Next service: exactly 2-space indent followed by a letter.
      if [[ "$line" =~ ^[[:space:]]{2}[A-Za-z] ]]; then
        break
      fi
      # Top-level key (0 indent) such as networks: or volumes:.
      if [[ "$line" =~ ^[A-Za-z] ]]; then
        break
      fi
      printf '%s\n' "$line"
    fi
  done < "$COMPOSE"
}

echo "=========================================="
echo "Coturn TURN Service Verification"
echo "  Compose: $COMPOSE"
echo "  Config:  $CONF"
echo "  Port:    $TURN_PORT (tcp+udp)"
echo "  Image:   $EXPECTED_IMAGE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Group A — declarative checks (live compose file)
# ---------------------------------------------------------------------------

# Test 1: live compose file exists and is readable
echo -n "Test 1: live compose file exists... "
if [[ -f "$COMPOSE" && -r "$COMPOSE" ]]; then
  pass "$COMPOSE"
else
  fail "compose file not found or not readable: $COMPOSE"
fi

# Extract the hubs-coturn block once (empty if compose missing).
COTURN_BLOCK=""
if [[ -r "$COMPOSE" ]]; then
  COTURN_BLOCK="$(extract_coturn_block)"
fi

# Test 2: hubs-coturn service is defined in the live compose
echo -n "Test 2: hubs-coturn service defined in compose... "
if [[ -n "$COTURN_BLOCK" ]]; then
  pass "hubs-coturn service block found"
else
  fail "hubs-coturn service not found in compose"
fi

# Test 3: compose uses the official coturn image
echo -n "Test 3: compose image is ${EXPECTED_IMAGE}... "
if grep -qE '^[[:space:]]{4}image:[[:space:]]+coturn/coturn:alpine' <<< "$COTURN_BLOCK"; then
  pass "image: $EXPECTED_IMAGE"
else
  fail "image: not $EXPECTED_IMAGE (got $(grep -E '^[[:space:]]{4}image:' <<< "$COTURN_BLOCK" | tr -d '[:space:]' || true))"
fi

# Test 4: compose mounts the TURN config read-only into the container
echo -n "Test 4: config bind-mounted into container... "
if grep -qE "^[[:space:]]*-[[:space:]]+${CONF}:/etc/coturn/turnserver.conf:ro" <<< "$COTURN_BLOCK"; then
  pass "${CONF} -> /etc/coturn/turnserver.conf:ro"
else
  fail "config bind-mount not found under hubs-coturn volumes"
fi

# ---------------------------------------------------------------------------
# Group B — TURN config validity (offline file checks)
# ---------------------------------------------------------------------------

CONF_BODY=""
if [[ -r "$CONF" ]]; then
  CONF_BODY="$(cat "$CONF")"
fi

# Test 5: config file exists and is readable
echo -n "Test 5: TURN config exists and is readable... "
if [[ -f "$CONF" && -r "$CONF" ]]; then
  pass "$CONF"
else
  fail "config file not found or not readable: $CONF"
fi

# Test 6: config declares realm
echo -n "Test 6: config has realm=... "
if grep -qE '^realm=.+' <<< "$CONF_BODY"; then
  pass "realm=$(grep -E '^realm=.+' <<< "$CONF_BODY" | head -1 | cut -d= -f2)"
else
  fail "no realm= key (or empty) in $CONF"
fi

# Test 7: config declares a TURN user
echo -n "Test 7: config has user=... "
if grep -qE '^user=.+' <<< "$CONF_BODY"; then
  pass "user=$(grep -E '^user=.+' <<< "$CONF_BODY" | head -1 | cut -d= -f2 | cut -d: -f1):***"
else
  fail "no user= key (or empty) in $CONF"
fi

# Test 8: config declares a numeric listening-port
echo -n "Test 8: config has listening-port=<numeric>... "
if grep -qE '^listening-port=[0-9]+' <<< "$CONF_BODY"; then
  pass "listening-port=$(grep -E '^listening-port=[0-9]+' <<< "$CONF_BODY" | head -1 | cut -d= -f2)"
else
  fail "no listening-port=<port> key in $CONF"
fi

# Test 9: config listening-port equals the expected TURN port
echo -n "Test 9: listening-port equals ${TURN_PORT}... "
if grep -qE "^listening-port=${TURN_PORT}$" <<< "$CONF_BODY"; then
  pass "listening-port=${TURN_PORT}"
else
  fail "listening-port != ${TURN_PORT}"
fi

# ---------------------------------------------------------------------------
# Group C — runtime checks (docker + procfs)
# ---------------------------------------------------------------------------

# Test 10: Docker daemon is accessible
echo -n "Test 10: Docker daemon accessible... "
if command -v docker >/dev/null 2>&1 && docker info &>/dev/null; then
  pass "docker daemon reachable"
else
  fail "docker daemon not accessible (or docker missing)"
fi

# Test 11: coturn container is running
echo -n "Test 11: ${CONTAINER} container is running... "
if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$CONTAINER"; then
  pass "${CONTAINER} is up"
else
  fail "${CONTAINER} is not running"
fi

# Test 12: running container uses the expected coturn image
echo -n "Test 12: ${CONTAINER} image is ${EXPECTED_IMAGE}... "
if [[ "$(docker inspect --format '{{.Config.Image}}' "$CONTAINER" 2>/dev/null)" == "$EXPECTED_IMAGE" ]]; then
  pass "$EXPECTED_IMAGE"
else
  fail "image mismatch (got $(docker inspect --format '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || echo 'unknown'))"
fi

# Test 13: TURN port 3478 is listening on TCP
#   /proc/net/tcp line: local_address 00000000:0D96, state 0A = LISTEN.
echo -n "Test 13: port ${TURN_PORT} listening on TCP... "
TCP_BODY="$(cat /proc/net/tcp 2>/dev/null || true)"
HEX=$(printf '%04X' "$TURN_PORT")   # 3478 -> 0D96
if grep -qE "[[:space:]]00000000:${HEX}[[:space:]]+00000000:0000[[:space:]]+0A[[:space:]]" <<< "$TCP_BODY"; then
  pass "0.0.0.0:${TURN_PORT}/tcp LISTEN"
else
  fail "no TCP listener on ${TURN_PORT} (state 0A in /proc/net/tcp)"
fi

# Test 14: TURN port 3478 is bound on UDP
#   /proc/net/udp line: local_address 00000000:0D96, state 07 = bound.
echo -n "Test 14: port ${TURN_PORT} bound on UDP... "
UDP_BODY="$(cat /proc/net/udp 2>/dev/null || true)"
if grep -qE "[[:space:]]00000000:${HEX}[[:space:]]+00000000:0000[[:space:]]+07[[:space:]]" <<< "$UDP_BODY"; then
  pass "0.0.0.0:${TURN_PORT}/udp bound"
else
  fail "no UDP socket on ${TURN_PORT} (state 07 in /proc/net/udp)"
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
  echo "❌ Some checks failed. TURN relay may be degraded — see output above."
  exit 1
else
  echo ""
  echo "✅ Coturn TURN relay is running and correctly configured."
  exit 0
fi
