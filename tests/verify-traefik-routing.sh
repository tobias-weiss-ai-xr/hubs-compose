#!/bin/bash
# Verification script for Traefik router rules on hubs.chemie-lernen.org.
#
# Verifies that the four Traefik router rules route traffic correctly:
#   - /api, /reticulum, /files, /socket -> hubs-reticulum
#   - /admin -> hubs-admin
#   - /spoke -> hubs-spoke
#   - root / -> hubs-client
#
# Run with: bash tests/verify-traefik-routing.sh
# (No sudo needed — hits the live public URL.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so that SIGPIPE cannot turn
# a match into a false failure.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# HTTP status code only (no body) for a given URL.
http_code() {
  curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "$1"
}

# HTTP status code + body for checking content.
http_get() {
  curl -sk --max-time 20 "$1" || true
}

echo "=========================================="
echo "Traefik Router Rules Verification"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Router: hubs-api -> hubs-reticulum
# Rule: PathPrefix(`/api`) || PathPrefix(`/reticulum`) || PathPrefix(`/files`) || PathPrefix(`/socket`)
# Priority: 120
# ---------------------------------------------------------------------------

# Test 1: /api routes to hubs-reticulum (returns JSON API response)
echo -n "Test 1: /api routes to hubs-reticulum... "
CODE=$(http_code "${BASE}/api/v1/meta")
BODY=$(http_get "${BASE}/api/v1/meta")
# hubs-reticulum returns JSON with "version" field
if [[ "$CODE" == "200" ]] && grep -q '"version"' <<< "$BODY"; then
  pass "HTTP 200 with JSON response (version field found)"
else
  fail "HTTP ${CODE} or unexpected body (expected JSON with version field)"
fi

# Test 2: /reticulum routes to hubs-reticulum
echo -n "Test 2: /reticulum routes to hubs-reticulum... "
CODE=$(http_code "${BASE}/reticulum")
BODY=$(http_get "${BASE}/reticulum")
# hubs-reticulum returns "bad Room ID" for bare /reticulum, which confirms
# the router correctly forwarded to the reticulum service
if [[ "$CODE" == "404" ]] && grep -qF 'bad Room ID' <<< "$BODY"; then
  pass "HTTP 404 with 'bad Room ID' (routed to hubs-reticulum)"
elif [[ "$CODE" == "200" ]] && grep -q '"version"' <<< "$BODY"; then
  pass "HTTP 200 with JSON response (version field found)"
else
  fail "HTTP ${CODE} with unexpected body (expected hubs-reticulum response)"
fi

# Test 3: /files routes to hubs-reticulum
echo -n "Test 3: /files routes to hubs-reticulum... "
CODE=$(http_code "${BASE}/files")
# hubs-reticulum /files endpoint returns 200 or 404 depending on path
# We expect the router to forward to reticulum, which will return appropriate status
if [[ "$CODE" == "200" || "$CODE" == "404" || "$CODE" == "403" ]]; then
  pass "HTTP ${CODE} (routed to hubs-reticulum)"
else
  fail "HTTP ${CODE} (expected 200/404/403 from hubs-reticulum)"
fi

# Test 4: /socket routes to hubs-reticulum (websocket upgrade or HTTP response)
echo -n "Test 4: /socket routes to hubs-reticulum... "
CODE=$(http_code "${BASE}/socket")
BODY=$(http_get "${BASE}/socket")
# hubs-reticulum returns "bad Room ID" for bare /socket, which confirms
# the router correctly forwarded to the reticulum service
if [[ "$CODE" == "404" ]] && grep -qF 'bad Room ID' <<< "$BODY"; then
  pass "HTTP 404 with 'bad Room ID' (routed to hubs-reticulum)"
elif [[ "$CODE" == "405" || "$CODE" == "200" || "$CODE" == "101" ]]; then
  pass "HTTP ${CODE} (routed to hubs-reticulum)"
else
  fail "HTTP ${CODE} (expected 404/405/200/101 from hubs-reticulum)"
fi

# ---------------------------------------------------------------------------
# Router: hubs-admin -> hubs-admin
# Rule: PathPrefix(`/admin`)
# Priority: 110
# ---------------------------------------------------------------------------

# Test 5: /admin routes to hubs-admin (serves admin interface)
echo -n "Test 5: /admin routes to hubs-admin... "
CODE=$(http_code "${BASE}/admin")
# hubs-admin redirects /admin to /admin/admin.html
BODY=$(http_get "${BASE}/admin")
if [[ "$CODE" == "302" || "$CODE" == "301" || "$CODE" == "200" ]]; then
  # Check if it's the admin interface (contains admin-specific content)
  if grep -qE 'admin|Admin|admin.html' <<< "$BODY" || [[ "$CODE" == "302" || "$CODE" == "301" ]]; then
    pass "HTTP ${CODE} (routed to hubs-admin)"
  else
    fail "HTTP ${CODE} with unexpected content (not hubs-admin)"
  fi
else
  fail "HTTP ${CODE} (expected 302/301/200 from hubs-admin)"
fi

# Test 6: /admin/admin.html routes to hubs-admin
echo -n "Test 6: /admin/admin.html routes to hubs-admin... "
CODE=$(http_code "${BASE}/admin/admin.html")
BODY=$(http_get "${BASE}/admin/admin.html")
if [[ "$CODE" == "200" && -n "$BODY" ]]; then
  pass "HTTP 200 with content"
else
  fail "HTTP ${CODE} or empty body"
fi

# ---------------------------------------------------------------------------
# Router: hubs-spoke -> spoke
# Rule: PathPrefix(`/spoke`)
# Priority: 110
# ---------------------------------------------------------------------------

# Test 7: /spoke routes to spoke service
echo -n "Test 7: /spoke routes to spoke service... "
CODE=$(http_code "${BASE}/spoke")
# spoke redirects /spoke to /spoke/
BODY=$(http_get "${BASE}/spoke")
if [[ "$CODE" == "302" || "$CODE" == "301" || "$CODE" == "200" ]]; then
  pass "HTTP ${CODE} (routed to spoke)"
else
  fail "HTTP ${CODE} (expected 302/301/200 from spoke)"
fi

# Test 8: /spoke/ routes to spoke service
echo -n "Test 8: /spoke/ routes to spoke service... "
CODE=$(http_code "${BASE}/spoke/")
BODY=$(http_get "${BASE}/spoke/")
if [[ "$CODE" == "200" && -n "$BODY" ]]; then
  pass "HTTP 200 with content"
else
  fail "HTTP ${CODE} or empty body"
fi

# ---------------------------------------------------------------------------
# Router: hubs-root -> hubs-client (root catch-all, priority 100)
# Rule: Host(`hubs.chemie-lernen.org`)
# Priority: 100
# ---------------------------------------------------------------------------

# Test 9: / (root) routes to hubs-client (serves homepage)
echo -n "Test 9: / (root) routes to hubs-client... "
CODE=$(http_code "${BASE}/")
BODY=$(http_get "${BASE}/")
# hubs-client serves index.html which references the index bundle
if [[ "$CODE" == "200" ]] && grep -qE 'index-[A-Za-z0-9]+\.js|hub\.html' <<< "$BODY"; then
  pass "HTTP 200 with index page content"
else
  fail "HTTP ${CODE} or unexpected body (expected hubs-client homepage)"
fi

# Test 10: /hub.html routes to hubs-client (room page)
echo -n "Test 10: /hub.html routes to hubs-client... "
CODE=$(http_code "${BASE}/hub.html")
BODY=$(http_get "${BASE}/hub.html")
# hubs-client serves hub.html which references the hub bundle
if [[ "$CODE" == "200" ]] && grep -qE 'hub-[A-Za-z0-9]+\.js' <<< "$BODY"; then
  pass "HTTP 200 with hub page content"
else
  fail "HTTP ${CODE} or unexpected body (expected hubs-client hub.html)"
fi

# Test 11: /assets/js/index-*.js routes to hubs-client static server
echo -n "Test 11: /assets/js/index-*.js routes to hubs-client... "
INDEX_BUNDLE=$(grep -oE 'assets/js/index-[A-Za-z0-9_.-]+\.js' <<< "$BODY" | head -n 1)
if [[ -z "$INDEX_BUNDLE" ]]; then
  # Try a known bundle name as fallback
  INDEX_BUNDLE="assets/js/index-19b3ec05dc199afecec2.js"
fi
CODE=$(http_code "${BASE}/${INDEX_BUNDLE}")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200 (${INDEX_BUNDLE})"
else
  fail "HTTP ${CODE} (${INDEX_BUNDLE})"
fi

# Test 12: Non-matching path (e.g., /nonexistent) routes to hubs-client
echo -n "Test 12: /nonexistent routes to hubs-client (catch-all)... "
CODE=$(http_code "${BASE}/nonexistent")
# hubs-client static server returns 404 for non-existent paths, or 200 for SPA routes
if [[ "$CODE" == "404" || "$CODE" == "200" ]]; then
  pass "HTTP ${CODE} (routed to hubs-client catch-all)"
else
  fail "HTTP ${CODE} (expected 404/200 from hubs-client)"
fi

# ---------------------------------------------------------------------------
# Priority verification: /api should NOT be caught by /admin or /spoke
# ---------------------------------------------------------------------------

# Test 13: Verify /api is NOT handled by hubs-admin
echo -n "Test 13: /api is NOT routed to hubs-admin... "
CODE=$(http_code "${BASE}/api/v1/meta")
BODY=$(http_get "${BASE}/api/v1/meta")
# hubs-admin would return admin-related content, hubs-reticulum returns JSON
if [[ "$CODE" == "200" ]] && ! grep -qE 'admin|Admin|admin\.html' <<< "$BODY"; then
  if grep -q '"version"' <<< "$BODY"; then
    pass "Correctly routed to hubs-reticulum (not hubs-admin)"
  else
    fail "Unexpected content (not JSON from reticulum)"
  fi
else
  fail "HTTP ${CODE} - may not be routed correctly"
fi

# Test 14: Verify /api is NOT handled by hubs-client
echo -n "Test 14: /api is NOT routed to hubs-client... "
CODE=$(http_code "${BASE}/api/v1/meta")
BODY=$(http_get "${BASE}/api/v1/meta")
# hubs-client would return HTML (index.html) or the index bundle, reticulum returns JSON
if [[ "$CODE" == "200" ]] && grep -q '"version"' <<< "$BODY" && ! grep -qE '<!DOCTYPE|<html|<head' <<< "$BODY"; then
  pass "Correctly routed to hubs-reticulum (not hubs-client)"
else
  fail "May be routed to hubs-client (returned HTML instead of JSON)"
fi

# Test 15: Verify /admin is NOT routed to hubs-reticulum
echo -n "Test 15: /admin is NOT routed to hubs-reticulum... "
CODE=$(http_code "${BASE}/admin")
BODY=$(http_get "${BASE}/admin")
# reticulum returns JSON for /api/v1/meta but not for /admin
if [[ "$CODE" != "404" ]]; then
  # If we get a redirect or HTML, it's likely hubs-admin, not reticulum
  if ! grep -q '"version"' <<< "$BODY" || grep -qE '<!DOCTYPE|<html|admin' <<< "$BODY"; then
    pass "Correctly NOT routed to hubs-reticulum"
  else
    fail "May be routed to hubs-reticulum (returned JSON)"
  fi
else
  pass "Not routed to hubs-reticulum (404 from admin)"
fi

# Test 16: Verify /spoke is NOT routed to hubs-reticulum
echo -n "Test 16: /spoke is NOT routed to hubs-reticulum... "
CODE=$(http_code "${BASE}/spoke")
BODY=$(http_get "${BASE}/spoke")
HAS_VERSION=$(grep -q '"version"' <<< "$BODY"; echo $?)
if [[ "$CODE" != "200" ]] || [[ "$HAS_VERSION" != "0" ]]; then
  pass "Correctly NOT routed to hubs-reticulum"
else
  fail "May be routed to hubs-reticulum (returned JSON version response)"
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
