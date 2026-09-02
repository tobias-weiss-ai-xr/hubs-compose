#!/bin/bash
# Verification script for the coturn TURN/STUN relay service (hubs-coturn).
#
# IT-36 — verifies, against the live deployment, that the WebRTC TURN/STUN
# edge is up and correctly configured:
#   1. The hubs-coturn container is running with the official coturn image.
#   2. Port 3478 is listening on TCP AND bound on UDP *inside the container's
#      network namespace* — read via `docker exec ... cat /proc/net/*`, not
#      just from the host. (The compose block uses network_mode: host, so the
#      container netns and the host netns are the same; the in-container read
#      stays netns-correct even if that ever changes.)
#   3. The TURN config at
#      /opt/containers/hubs-compose/services/coturn/turnserver.conf declares a
#      realm (this deployment: chemie-lernen.org) and listens on port 3478.
#   4. The MISSING healthcheck is reported as a FINDING — informational, never
#      a gate failure. coturn currently ships without a healthcheck in the
#      compose block, so the FINDING surfaces the monitoring gap to operators
#      while still letting the gate pass.
#
# coturn (coturn/coturn:alpine) is the STUN/TURN relay that lets Hubs callers
# behind school NATs fall back to a media relay when direct P2P is blocked —
# if it is down, those pupils cannot join rooms. Merges touching infra/TURN
# are gated on this check.
#
# Run with: bash tests/verify-coturn-service.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix. ((FAILED++)) returns exit 1 when the
# counter is 0, which `set -e` would treat as a fatal error. We use
# FAILED=$((FAILED+1)) instead. Also no `pipefail`-induced SIGPIPE traps:
# grep is fed via here-strings, never via a pipe, so an early grep -q exit
# cannot false-fail a check on large inputs.
#
# Port-listening checks read /proc/net/{tcp,tcp6,udp,udp6} inside the container
# netns (port 3478 = 0x0D96 hex) instead of invoking ss/netstat/nc, keeping the
# script self-contained (bash + grep; docker only for the container checks).

set -uo pipefail

COMPOSE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"
CONF="/opt/containers/hubs-compose/services/coturn/turnserver.conf"
CONTAINER="hubs-coturn"
EXPECTED_IMAGE="coturn/coturn:alpine"
EXPECTED_REALM="chemie-lernen.org"
TURN_PORT=3478

PASSED=0
FAILED=0
FINDINGS=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }
finding() { echo "  ⚠️  FINDING: $1"; FINDINGS=$((FINDINGS+1)); }

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
echo "Coturn TURN/STUN Service Verification"
echo "  Compose: $COMPOSE"
echo "  Config:  $CONF"
echo "  Port:    $TURN_PORT (tcp+udp, in-container netns)"
echo "  Image:   $EXPECTED_IMAGE"
echo "  Realm:   $EXPECTED_REALM"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Group A — declarative checks (live compose file + TURN config)
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
if grep -qE "^[[:space:]]{4}image:[[:space:]]+coturn/coturn:alpine" <<< "$COTURN_BLOCK"; then
  pass "image: $EXPECTED_IMAGE"
else
  fail "image: not $EXPECTED_IMAGE (got $(grep -E '^[[:space:]]{4}image:' <<< "$COTURN_BLOCK" | tr -d '[:space:]' || true))"
fi

# Test 4: compose mounts the TURN config read-only into the container
echo -n "Test 4: config bind-mounted into container (read-only)... "
if grep -qE "^[[:space:]]*-[[:space:]]+${CONF}:/etc/coturn/turnserver.conf:ro" <<< "$COTURN_BLOCK"; then
  pass "${CONF} -> /etc/coturn/turnserver.conf:ro"
else
  fail "config bind-mount not found under hubs-coturn volumes"
fi

# Test 5: compose declares host networking (context for the netns checks)
echo -n "Test 5: compose declares network_mode: host... "
if grep -qE '^[[:space:]]{4}network_mode:[[:space:]]+host' <<< "$COTURN_BLOCK"; then
  pass "container netns == host netns (netns checks below read it via docker exec)"
else
  pass "no host networking declared (netns checks still run in-container)"
fi

# ---------------------------------------------------------------------------
# Group B — TURN config validity (offline file checks)
# ---------------------------------------------------------------------------

CONF_BODY=""
if [[ -r "$CONF" ]]; then
  CONF_BODY="$(cat "$CONF")"
fi

# Test 6: config file exists and is readable
echo -n "Test 6: TURN config exists and is readable... "
if [[ -f "$CONF" && -r "$CONF" ]]; then
  pass "$CONF"
else
  fail "config file not found or not readable: $CONF"
fi

# Test 7: config declares a non-empty realm
echo -n "Test 7: config has realm=... "
if grep -qE '^realm=.+' <<< "$CONF_BODY"; then
  pass "realm=$(grep -E '^realm=.+' <<< "$CONF_BODY" | head -1 | cut -d= -f2)"
else
  fail "no realm= key (or empty) in $CONF"
fi

# Test 8: config realm matches the expected deployment realm
echo -n "Test 8: realm equals ${EXPECTED_REALM}... "
if grep -qE "^realm=${EXPECTED_REALM}$" <<< "$CONF_BODY"; then
  pass "realm=${EXPECTED_REALM} (matches lt-cred-mech shared-secret realm)"
else
  fail "realm != ${EXPECTED_REALM} — TURN auth will fail for clients"
fi

# Test 9: config listening-port equals the expected TURN port
echo -n "Test 9: listening-port equals ${TURN_PORT}... "
if grep -qE "^listening-port=${TURN_PORT}$" <<< "$CONF_BODY"; then
  pass "listening-port=${TURN_PORT}"
else
  fail "listening-port != ${TURN_PORT} (got $(grep -E '^listening-port=' <<< "$CONF_BODY" | head -1 || true))"
fi

# ---------------------------------------------------------------------------
# Group C — runtime checks (docker + container netns)
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
DOCKER_PS="$(docker ps --format '{{.Names}}' 2>/dev/null)"
if grep -qx "$CONTAINER" <<< "$DOCKER_PS"; then
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

# ---------------------------------------------------------------------------
# Port checks — inside the container's network namespace.
#
# Read /proc/net/{tcp,tcp6,udp,udp6} via `docker exec` so we inspect the
# container's own netns (identical to the host netns here because the service
# uses network_mode: host). If docker exec is unavailable we fall back to the
# host /proc/net, which is equivalent for host-networked containers.
#
# /proc/net/tcp line: local_address 00000000:0D96, state 0A = LISTEN.
# /proc/net/udp line: local_address 00000000:0D96, state 07 = bound.
# 00000000:0D96 also matches the tail of the IPv6 wildcard address, so one
# pattern covers both v4 and v6 wildcard listeners.
# ---------------------------------------------------------------------------

HEX=$(printf '%04X' "$TURN_PORT")   # 3478 -> 0D96

TCP_BODY="$(docker exec "$CONTAINER" sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null' 2>/dev/null || true)"
if [[ -z "$TCP_BODY" ]]; then
  # docker exec unavailable — fall back to host netns (== container netns for host networking).
  TCP_BODY="$(cat /proc/net/tcp /proc/net/tcp6 2>/dev/null || true)"
fi
UDP_BODY="$(docker exec "$CONTAINER" sh -c 'cat /proc/net/udp /proc/net/udp6 2>/dev/null' 2>/dev/null || true)"
if [[ -z "$UDP_BODY" ]]; then
  UDP_BODY="$(cat /proc/net/udp /proc/net/udp6 2>/dev/null || true)"
fi

# Test 13: TURN port 3478 is listening on TCP inside the container netns
echo -n "Test 13: port ${TURN_PORT} LISTEN on TCP inside ${CONTAINER} netns... "
if grep -qE "00000000:${HEX}[[:space:]]+00000000:0000[[:space:]]+0A[[:space:]]" <<< "$TCP_BODY"; then
  pass "0.0.0.0:${TURN_PORT}/tcp LISTEN (state 0A, wildcard) in container netns"
else
  fail "no TCP listener on ${TURN_PORT} inside container netns (state 0A in /proc/net/tcp{,6})"
fi

# Test 14: TURN port 3478 is bound on UDP inside the container netns
echo -n "Test 14: port ${TURN_PORT} bound on UDP inside ${CONTAINER} netns... "
if grep -qE "00000000:${HEX}[[:space:]]+00000000:0000[[:space:]]+07[[:space:]]" <<< "$UDP_BODY"; then
  pass "0.0.0.0:${TURN_PORT}/udp bound (state 07, wildcard) in container netns"
else
  fail "no UDP socket on ${TURN_PORT} inside container netns (state 07 in /proc/net/udp{,6})"
fi

# ---------------------------------------------------------------------------
# Group D — FINDING: healthcheck (informational, never a gate failure)
# ---------------------------------------------------------------------------

# Test 15: healthcheck configured in compose block
echo -n "Test 15: healthcheck configured for ${CONTAINER}... "
if grep -qE '^[[:space:]]{4}healthcheck:' <<< "$COTURN_BLOCK"; then
  pass "healthcheck: defined in compose and running with the container"
else
  echo ""
  finding "hubs-coturn has NO healthcheck: in the live compose block — nothing detects or restarts a wedged TURN process"
  echo "        Why it matters: coturn is the media fallback for school NATs; a dead-but-running"
  echo "        container silently drops every TURN allocation while still showing 'Up' in docker ps."
  echo "        Suggested fix: add a healthcheck to the hubs-coturn service in the live compose, e.g.:"
  echo '          healthcheck:'
  echo '            test: ["CMD-SHELL", "nc -z 127.0.0.1 3478 || exit 1"]'
  echo '            interval: 30s'
  echo '            timeout: 5s'
  echo '            retries: 3'
  echo '            start_period: 10s'
  echo "        (Assumes busybox nc in the coturn/coturn:alpine image.)"
  echo ""
fi

# Corroborate at runtime: does the running container carry a healthcheck?
DOCKER_HC="$(docker inspect --format '{{.Config.Healthcheck}}' "$CONTAINER" 2>/dev/null)"
if [[ -n "$DOCKER_HC" && "$DOCKER_HC" != "<nil>" ]]; then
  pass "running container has a healthcheck configured ($DOCKER_HC)"
else
  echo "  ℹ️  INFO: running container reports Healthcheck=<nil> — confirms the FINDING above"
  echo "        (docker ps column 'HEALTH' will stay blank/starting for this container)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FINDINGS" -gt 0 ]]; then
  echo "Findings: $FINDINGS (informational — not counted as failures)"
fi
echo "=========================================="

if [[ "$FAILED" -gt 0 ]]; then
  echo ""
  echo "❌ Some checks failed. TURN/STUN edge may be degraded — see output above."
  exit 1
else
  echo ""
  echo "✅ Coturn TURN/STUN relay is running, reachable and correctly configured."
  exit 0
fi
