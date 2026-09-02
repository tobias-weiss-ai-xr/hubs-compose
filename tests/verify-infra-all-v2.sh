#!/bin/bash
# verify-infra-all-v2.sh — aggregate runner executing all 13 infrastructure test
# scripts (7 from Batch 2 + 6 from Batch 3), reporting a combined summary.
#
# Executes:
#   Batch 2 (7 infrastructure tests):
#     1. verify-docker-health.sh             all hubs-stack containers running/healthy
#     2. verify-traefik-routing.sh           4 Traefik routers → correct backends
#     3. verify-reticulum-api.sh             /api/v1/meta 200 + expected fields
#     4. verify-tls-certificate.sh           HTTPS CN/SAN/issuer/notAfter
#     5. verify-spoke-admin.sh              /spoke/ + /admin/ serve HTML
#     6. verify-turn-service.sh             coturn Up, port 3478, config valid
#     7. verify-client-bundles.sh           JS bundles >100KB + .map HTTP 200
#   Batch 3 (6 new tests — IT-9 through IT-14):
#     8. verify-css-assets.sh               CSS stylesheets HTTP 200 + text/css
#     9. verify-js-assets.sh                all JS bundles HTTP 200 + .map 200
#    10. verify-dialog-service.sh           hubs-dialog healthy + /dialog/ 200
#    11. verify-postgrest.sh                container Up + responds on Docker net
#    12. verify-mailrelay.sh                hubs-mailrelay healthy + /mailrelay 200
#    13. verify-asset-content-types.sh      correct Content-Type for CSS/JS/PNG/JPG
#
# Each sub-script is a single pass/fail entry in the AGGREGATE summary; the
# runner exits non-zero if ANY sub-script failed. Full per-test output of
# every sub-script is streamed so a failure stays diagnosable.
#
# Run with: bash tests/verify-infra-all-v2.sh
#
# Conventions honored:
#   - NO `set -e`: a verification script must run ALL tests and report the
#     full matrix, not bail after the first failure. FAILED=$((FAILED+1)).
#   - set -uo pipefail
#   - Sub-scripts invoked by absolute path (resolved from this script's own
#     directory), works from any CWD.
#   - All sub-scripts run even if one fails.

set -uo pipefail

# Resolve this script's directory so the sub-scripts are found regardless of
# the caller's CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The 13 verification scripts, in execution order (Batch 2 first, then Batch 3).
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
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Infrastructure Verification — Aggregate Runner v2"
echo "  13 sub-scripts: 7 from Batch 2 + 6 from Batch 3"
echo "  (docker health, traefik, reticulum, TLS, spoke+admin,"
echo "   TURN, bundles, CSS, JS, dialog, postgrest, mailrelay,"
echo "   content-types)"
echo "=========================================="

# ---------------------------------------------------------------------------
# run_subscript
#
# Runs one sub-script, streams its full output, and records a single aggregate
# pass/fail entry from its exit code. Returns the sub-script's exit code.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Run all 13 sub-scripts. Each runs to completion; failures are collected and
# reported in the aggregate summary. No short-circuiting.
# ---------------------------------------------------------------------------
ALL_OK=0
for script in "${SCRIPTS[@]}"; do
  run_subscript "$script"
  run_rc=$?
  if [[ "$run_rc" -ne 0 ]]; then
    ALL_OK=1
  fi
done

# ---------------------------------------------------------------------------
# Aggregate summary
# ---------------------------------------------------------------------------
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
