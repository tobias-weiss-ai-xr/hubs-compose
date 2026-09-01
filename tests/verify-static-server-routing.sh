#!/bin/bash
# verify-static-server-routing.sh — verify the static-server.py SPA rewrites.
#
# The hubs-client container runs /code/static-server.py (bind-mounted from
# /opt/git/hubs-client-assets) which serves the production dist/ with the
# same historyApiFallback rewrites Hubs' dev server used. This script verifies
# the four required routes all return HTTP 200:
#
#   /                   -> /index.html   (home page)
#   /hub.html           -> /hub.html     (room page)
#   /assets/js/index-*  -> bundle file   (home bundle, name resolved from HTML)
#   /<7-char-slug>      -> /hub.html     (room page, e.g. /raJ6mj3)
#
# Beyond the status code it asserts the REWRITES resolve to the *correct*
# document (home pages carry the index- bundle, room pages carry the hub-
# bundle), that slug variants with a path suffix / trailing slash still hit
# hub.html, and that extension routes are NOT rewritten (clean 404, which is
# the static-server.py intent — never serve hub.html for foo.gltf).
#
# Finally it checks offline that the deployed artifacts are consistent:
# the bind-mounted static-server.py actually contains the room-slug rewrite,
# and docker-compose.hubs.yml mounts it + the index bundle into hubs-client.
#
# Run with: bash tests/verify-static-server-routing.sh
# (No sudo needed — hits the live public URL + reads absolute asset paths.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

set -uo pipefail

BASE="https://hubs.chemie-lernen.org"
STATIC_SERVER="/opt/git/hubs-client-assets/static-server.py"
COMPOSE_FILE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"
ASSETS_DIR="/opt/git/hubs-client-assets"

PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# HTTP status code only (no body) for a given URL.
http_code() {
  curl -sk -o /dev/null -w "%{http_code}" --max-time 20 "$1"
}

echo "=========================================="
echo "Static Server SPA Routing Verification"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Home page  /
# ---------------------------------------------------------------------------
echo -n "Test 1: Home page (/) returns HTTP 200... "
CODE=$(http_code "${BASE}/")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 2: Room page  /hub.html
# ---------------------------------------------------------------------------
echo -n "Test 2: Room page (/hub.html) returns HTTP 200... "
CODE=$(http_code "${BASE}/hub.html")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 3: Home bundle  /assets/js/index-*.js
# ---------------------------------------------------------------------------
# Resolve the concrete index bundle name from the served home page so this
# stays correct if the bundle is ever rebuilt/renamed.
echo -n "Test 3: index bundle (/assets/js/index-*.js) returns HTTP 200... "
HOME_BODY=$(curl -sk --max-time 20 "${BASE}/" || true)
INDEX_BUNDLE=$(grep -oE 'assets/js/index-[A-Za-z0-9_.-]+\.js' <<< "$HOME_BODY" | head -n 1)
if [[ -z "$INDEX_BUNDLE" ]]; then
  fail "could not resolve /assets/js/index-*.js from home page HTML"
elif [[ "$(http_code "${BASE}/${INDEX_BUNDLE}")" == "200" ]]; then
  pass "HTTP 200 (${INDEX_BUNDLE})"
else
  fail "HTTP $(http_code "${BASE}/${INDEX_BUNDLE}") (${INDEX_BUNDLE})"
fi

# ---------------------------------------------------------------------------
# Test 4: 7-char room slug  /raJ6mj3
# ---------------------------------------------------------------------------
SLUG="/raJ6mj3"
echo -n "Test 4: 7-char room slug (${SLUG}) returns HTTP 200... "
CODE=$(http_code "${BASE}${SLUG}")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 5: Rewrite targets the CORRECT document (room vs home)
# ---------------------------------------------------------------------------
echo -n "Test 5: / serves the home page (index bundle, no hub bundle)... "
HUB_BODY=$(curl -sk --max-time 20 "${BASE}/hub.html" || true)
SLUG_BODY=$(curl -sk --max-time 20 "${BASE}${SLUG}" || true)
if grep -q 'assets/js/index-' <<< "$HOME_BODY" && ! grep -q 'assets/js/hub-' <<< "$HOME_BODY"; then
  pass "home page served for /"
else
  fail "home page content marker (index- bundle) missing/wrong for /"
fi

echo -n "Test 6: /hub.html serves the room page (hub bundle, no index bundle)... "
if grep -q 'assets/js/hub-' <<< "$HUB_BODY" && ! grep -q 'assets/js/index-' <<< "$HUB_BODY"; then
  pass "room page served for /hub.html"
else
  fail "room page content marker (hub- bundle) missing/wrong for /hub.html"
fi

echo -n "Test 7: ${SLUG} rewrites to the room page, NOT the home page... "
if grep -q 'assets/js/hub-' <<< "$SLUG_BODY" && ! grep -q 'assets/js/index-' <<< "$SLUG_BODY"; then
  pass "room page served for ${SLUG}"
else
  fail "slug served the home page instead of hub.html"
fi

# ---------------------------------------------------------------------------
# Test 8: Slug variants (suffix path / trailing slash) still hit hub.html
# ---------------------------------------------------------------------------
echo -n "Test 8: slug with path suffix (${SLUG}/test-room) returns HTTP 200... "
CODE=$(http_code "${BASE}${SLUG}/test-room")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

echo -n "Test 9: slug with trailing slash (${SLUG}/) returns HTTP 200... "
CODE=$(http_code "${BASE}${SLUG}/")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 10: Extension routes are NOT rewritten (clean 404)
# ---------------------------------------------------------------------------
# static-server.py restricts the room-slug pattern to [A-Za-z0-9_-] so file
# paths like /<hubId>/objects.gltf do NOT match and get a clean 404 instead
# of hub.html (which would break the glTF loader with HTML-as-JSON).
echo -n "Test 10: file route in slug dir (${SLUG}/objects.gltf) is a clean 404... "
CODE=$(http_code "${BASE}${SLUG}/objects.gltf")
if [[ "$CODE" == "404" ]]; then
  pass "HTTP 404 (not rewritten to hub.html)"
else
  fail "HTTP ${CODE} (expected 404 — slug dir file must not serve hub.html)"
fi

echo -n "Test 11: unknown JS asset is a clean 404... "
CODE=$(http_code "${BASE}/assets/js/nonexistent-123.js")
if [[ "$CODE" == "404" ]]; then
  pass "HTTP 404"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 12: Index bundle integrity (non-trivial size, JS marker)
# ---------------------------------------------------------------------------
echo -n "Test 12: index bundle is non-trivial and looks like JS... "
BUNDLE_BODY=$(curl -sk --max-time 20 "${BASE}/${INDEX_BUNDLE}" || true)
SIZE=$(wc -c <<< "$BUNDLE_BODY")
# The minified bundle ships the populated fallbackImages map as
# `var p={logo:"..."...}` — the same marker verify-client-branding.sh uses.
if (( SIZE > 450000 )) && grep -q 'var p={logo:' <<< "$BUNDLE_BODY"; then
  pass "${SIZE} bytes, populated fallbackImages map (var p={logo:...})"
else
  fail "${SIZE} bytes (expected >450000 with var p={logo:...} marker)"
fi

# ---------------------------------------------------------------------------
# Offline consistency checks (static-server.py + compose bind mounts)
# ---------------------------------------------------------------------------
echo ""
echo "Offline configuration consistency:"
echo -n "Test 13: static-server.py holds the 7-char room-slug rewrite... "
if [[ -f "$STATIC_SERVER" ]] && grep -qF '[A-Za-z0-9]{7}' "$STATIC_SERVER" && grep -qF '"/hub.html"' "$STATIC_SERVER"; then
  pass "room-slug -> /hub.html rewrite present"
else
  fail "static-server.py missing room-slug rewrite (${STATIC_SERVER})"
fi

echo -n "Test 14: compose file bind-mounts static-server.py + index bundle... "
if [[ -f "$COMPOSE_FILE" ]] && grep -qF 'static-server.py:/code/static-server.py:ro' "$COMPOSE_FILE" && grep -qF 'index-' "$COMPOSE_FILE"; then
  pass "hubs-client mounts verified"
else
  fail "compose bind mounts missing (${COMPOSE_FILE})"
fi

echo -n "Test 15: patched index bundle file present in hubs-client-assets... "
INDEX_BASENAME=$(basename "$INDEX_BUNDLE")
if [[ -f "${ASSETS_DIR}/${INDEX_BASENAME}" ]] && (( $(stat -c %s "${ASSETS_DIR}/${INDEX_BASENAME}") > 450000 )); then
  pass "${INDEX_BASENAME} present (non-trivial)"
else
  fail "${ASSETS_DIR}/${INDEX_BASENAME} missing or empty"
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
