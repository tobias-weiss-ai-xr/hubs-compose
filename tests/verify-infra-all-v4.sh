#!/bin/bash
# verify-infra-all-v4.sh — aggregate runner for ALL infrastructure tests
# (Batch 2 + Batch 3 + Batch 4 + IT-23..IT-29).
#
# Executes all 26 sub-scripts in sequence:
#   Batch 2 (7 tests):
#     1. verify-docker-health.sh             containers running/healthy
#     2. verify-traefik-routing.sh            Traefik routers → backends
#     3. verify-reticulum-api.sh             /api/v1/meta + fields
#     4. verify-tls-certificate.sh           HTTPS CN/SAN/issuer/expiry
#     5. verify-spoke-admin.sh              Spoke + Admin HTML
#     6. verify-turn-service.sh             Coturn Up, port 3478
#     7. verify-client-bundles.sh           JS bundles + source maps
#   Batch 3 (6 tests):
#     8. verify-css-assets.sh               CSS HTTP 200 + text/css
#     9. verify-js-assets.sh                all JS bundles + maps
#    10. verify-dialog-service.sh           Dialog container + /dialog/
#    11. verify-postgrest.sh               PostgREST container + responds
#    12. verify-mailrelay.sh               Mailrelay container + /mailrelay
#    13. verify-asset-content-types.sh     Content-Type headers correct
#   Batch 4 (6 tests):
#    14. verify-security-headers.sh        HSTS/X-Frame/X-Content-Type findings
#    15. verify-http-redirect.sh           HTTP→HTTPS 308 redirect
#    16. verify-dns-resolution.sh          DNS + Traefik dashboard
#    17. verify-postgres-health.sh         DB running + pg_isready
#    18. verify-docker-volumes.sh           Volumes exist + data accessible
#    19. verify-restart-policies.sh       All containers have restart policy
#   IT-23..IT-29 (7 tests):
#    20. verify-spa-routes.sh              SPA routes serve their own HTML
#    21. verify-bind-mounts.sh             Live compose bind-mounts client assets
#    22. verify-legacy-redirect-variants.sh  legacy /hub/<id>[/<slug>] 301s
#    23. verify-cache-cors-headers.sh      Cache-Control + CORS on hubs-client
#    24. verify-media-serving.sh           Reticulum /files/ media contract
#    25. verify-element-api-contract.sh    element API contract + ~1rps throttle
#    26. verify-traefik-middleware-config.sh hubs-security-headers wiring
#
# Each sub-script contributes a single pass/fail entry in the AGGREGATE summary.
# The runner exits non-zero if ANY sub-script failed. Full per-test output of
# every sub-script is streamed so failures stay diagnosable.
#
# Run with: bash tests/verify-infra-all-v4.sh

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
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Infrastructure Verification — Aggregate Runner v4"
echo "  26 sub-scripts: 7 Batch 2 + 6 Batch 3 + 6 Batch 4 + 7 IT-23..IT-29"
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
else
  echo ""
  echo "✅ All ${PASSED} infrastructure verification sub-scripts passed."
  exit 0
fi
