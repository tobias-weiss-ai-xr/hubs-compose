#!/bin/bash
# verify-branding-all.sh — aggregate runner for all 5 branding verification
# scripts.
#
# Executes, in dependency order:
#   1. verify-bundle-patch.sh            offline: 8 fallbackImages keys present
#                                        in both patched client bundles
#   2. verify-bind-mounts.sh             offline: patched bundles bind-mounted
#                                        into hubs-client in the compose file
#   3. verify-asset-urls.sh              live:    fallback image + cubemap URLs
#                                        return HTTP 200
#   4. verify-bundle-regression.sh       live+off: EMPTY fallbackImages pattern
#                                        regression guard on live + patched bundles
#   5. verify-static-server-routing.sh   live+off: static-server.py SPA rewrites
#                                        (home page, hub.html, room slugs, clean 404)
#
# Each sub-script is a single pass/fail entry in the AGGREGATE summary; the
# runner exits non-zero if ANY sub-script failed. The full per-test output of
# every sub-script is shown so a failure stays diagnosable.
#
# Run with: bash tests/verify-branding-all.sh
#
# Conventions honored (see docs):
#   - NO `set -e`: a verification script must run ALL tests and report the
#     full matrix, not bail after the first failure. FAILED=$((FAILED+1)).
#   - set -uo pipefail
#   - Sub-scripts are invoked by absolute path (resolved from this script's
#     own directory), so the runner works from any CWD.
#   - All 5 sub-scripts run even if one fails — a partial verdict is not a
#     full verdict.

set -uo pipefail

# Resolve this script's directory so the sub-scripts are found regardless of
# the caller's CWD (acceptance gate runs `bash tests/verify-branding-all.sh`
# from the worktree root, but the runner should never depend on CWD).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The 5 branding verification scripts, in execution order.
SCRIPTS=(
  "verify-bundle-patch.sh"
  "verify-bind-mounts.sh"
  "verify-asset-urls.sh"
  "verify-bundle-regression.sh"
  "verify-static-server-routing.sh"
)

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Branding Verification — Aggregate Runner"
echo "  5 sub-scripts: bundle patch, bind mounts,"
echo "  asset URLs, bundle regression, SPA routing"
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

  # Run with a fresh `bash` so a sub-script's options/environment never leak
  # into the runner. No `set -e` here either — a failing sub-script must be
  # reported (and the remaining sub-scripts must still run), not abort.
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
# Run all 5 sub-scripts. Each runs to completion; failures are collected and
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
  echo "❌ ${FAILED} of ${#SCRIPTS[@]} branding verification sub-script(s)"
  echo "   failed. Inspect the per-test output above."
  exit 1
else
  echo ""
  echo "✅ All ${PASSED} branding verification sub-scripts passed."
  exit 0
fi
