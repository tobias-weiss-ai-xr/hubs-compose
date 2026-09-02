#!/usr/bin/env bash
# verify-infra-all-v5.sh — aggregate runner for the full infrastructure suite
#
# Executes every infrastructure verification sub-script in sequence and
# reports an aggregate summary. Suite composition:
#
# Batch 5 + 6 additions (this file extends verify-infra-all-v4.sh):
#   21. verify-bind-mounts.sh             Live compose bind-mounts client assets
#   22. verify-legacy-redirect-variants.sh  legacy /hub/<id>[/<slug>] 301s
#   23. verify-cache-cors-headers.sh      Cache-Control + CORS on hubs-client
#   24. verify-media-serving.sh           Reticulum /files/ media contract
#   25. verify-element-api-contract.sh    element API contract + ~1rps throttle
#   26. verify-traefik-middleware-config.sh hubs-security-headers wiring
#   27. verify-tls-certificate.sh         chain, expiry, SAN (Batch 6)
#   28. verify-reticulum-meta.sh          /api/v1/meta contract (Batch 6)
#   29. verify-websocket-endpoint.sh      /socket/websocket routes (426) (Batch 6)
#   30. verify-landing-assets.sh          landing page bundles + favicon (Batch 6)
#   31. verify-healthchecks-defined.sh    Docker healthchecks defined (Batch 6)
#   32. verify-coturn-service.sh          TURN/STUN service (Batch 6)
#
# Each sub-script contributes a single pass/fail entry in the AGGREGATE summary.
# The runner exits non-zero if ANY sub-script failed. Full per-test output of
# every sub-script is streamed so failures stay diagnosable.
#
# NOTE: run only when the stack is quiet — sub-scripts assert steady-state
# health and will transiently fail during container (re)starts.
#
# Run with: bash tests/verify-infra-all-v5.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SCRIPTS=(
  "verify-docker-health.sh"
  "verify-traefik-routing.sh"
  "verify-reticulum-api.sh"
  "verify-tls-certificate.sh"
  "verify-spoke-admin.sh"
  "verify-turn-service.sh"
  "verify-client-bundles.sh"
  "verify-css-assets.sh"
  "verify-js-assets.sh"
  "verify-dialog-service.sh"
  "verify-postgrest.sh"
  "verify-mailrelay.sh"
  "verify-asset-content-types.sh"
  "verify-security-headers.sh"
  "verify-http-redirect.sh"
  "verify-dns-resolution.sh"
  "verify-postgres-health.sh"
  "verify-docker-volumes.sh"
  "verify-restart-policies.sh"
  "verify-spa-routes.sh"
  "verify-bind-mounts.sh"
  "verify-legacy-redirect-variants.sh"
  "verify-cache-cors-headers.sh"
  "verify-media-serving.sh"
  "verify-element-api-contract.sh"
  "verify-traefik-middleware-config.sh"
  "verify-reticulum-meta.sh"
  "verify-websocket-endpoint.sh"
  "verify-landing-assets.sh"
  "verify-healthchecks-defined.sh"
  "verify-coturn-service.sh"
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Infrastructure Verification — Aggregate Runner v5"
echo "  ${#SCRIPTS[@]} sub-scripts: 7 Batch 2 + 6 Batch 3 + 6 Batch 4 + 7 IT-23..IT-29 + 6 IT-31..IT-36"
echo "=========================================="

run_subscript() {
  local name="$1"
  local path="${SCRIPT_DIR}/${name}"
  local rc

  echo ""
  echo "--------------------------------------------------------------"
  echo "▶ ${name}"
  echo "--------------------------------------------------------------"

  if [[ ! -f "$path" ]]; then
    fail "${name} — script file missing: ${path}"
    return 1
  fi

  bash "$path"
  rc=$?

  if [[ "$rc" -eq 0 ]]; then
    pass "${name}"
  else
    fail "${name} (exit ${rc})"
  fi
  return "$rc"
}

ALL_OK=0
for script in "${SCRIPTS[@]}"; do
  run_subscript "$script"
  run_rc=$?
  if [[ "$run_rc" -ne 0 ]]; then
    ALL_OK=1
  fi
done

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

if [[ "$ALL_OK" -ne 0 || "$FAILED" -gt 0 ]]; then
  echo ""
  echo "❌ ${FAILED} of ${#SCRIPTS[@]} infrastructure verification sub-script(s)"
  echo "   failed. Inspect the per-test output above."
  exit 1
fi

echo ""
echo "✅ All ${#SCRIPTS[@]} infrastructure verification sub-scripts passed."
exit 0
