#!/bin/bash
# verify-spoke-admin.sh — verify the Spoke editor and Admin panel serve HTML.
#
# The hubs deployment exposes two web editors behind Traefik on
# hubs.chemie-lernen.org:
#
#   /spoke/          -> hubs-spoke  container (Spoke scene editor)
#                      /spoke rewrites via 302 to /spoke/ (hubs-spoke-redirect)
#   /admin/admin.html -> hubs-admin container (Admin panel)
#                      /admin and /admin/ rewrite via 302 to /admin/admin.html
#
# This script asserts the two editor UIs actually serve their HTML documents:
#   * /spoke/ returns HTTP 200 with the "Scene Editor" document title
#   * /admin/admin.html returns HTTP 200 with an HTML document root
#
# It also verifies the canonical redirects (/spoke -> /spoke/, and
# /admin[/] -> /admin/admin.html) stay wired up in Traefik, cheaply, by
# checking the redirect target of the non-canonical URLs.
#
# Run with: bash tests/verify-spoke-admin.sh
# (No sudo needed — hits the live public URL.)
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.

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

# Redirect target (Location header) for a given URL, empty if none.
redirect_url() {
  curl -sk -o /dev/null -w "%{redirect_url}" --max-time 20 "$1"
}

echo "=========================================="
echo "Spoke Editor & Admin Panel HTML Verification"
echo "  Target: $BASE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: Spoke editor page  /spoke/
# ---------------------------------------------------------------------------
echo -n "Test 1: /spoke/ returns HTTP 200... "
CODE=$(http_code "${BASE}/spoke/")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 2: Spoke editor serves the Scene Editor document
# ---------------------------------------------------------------------------
echo -n "Test 2: /spoke/ body contains 'Scene Editor'... "
SPOKE_BODY=$(curl -sk --max-time 20 "${BASE}/spoke/")
if grep -q 'Scene Editor' <<< "$SPOKE_BODY"; then
  pass "Scene Editor document title present"
else
  fail "'Scene Editor' marker missing from /spoke/ HTML"
fi

# ---------------------------------------------------------------------------
# Test 3: Spoke root  /spoke  redirects to  /spoke/
# ---------------------------------------------------------------------------
echo -n "Test 3: /spoke redirects to /spoke/... "
LOC=$(redirect_url "${BASE}/spoke")
if [[ "$LOC" == "${BASE}/spoke/" ]]; then
  pass "302 -> ${LOC}"
else
  fail "redirect target '${LOC}' (expected ${BASE}/spoke/)"
fi

# ---------------------------------------------------------------------------
# Test 4: Admin panel page  /admin/admin.html
# ---------------------------------------------------------------------------
echo -n "Test 4: /admin/admin.html returns HTTP 200... "
CODE=$(http_code "${BASE}/admin/admin.html")
if [[ "$CODE" == "200" ]]; then
  pass "HTTP 200"
else
  fail "HTTP ${CODE}"
fi

# ---------------------------------------------------------------------------
# Test 5: Admin panel serves an HTML document
# ---------------------------------------------------------------------------
echo -n "Test 5: /admin/admin.html body starts with <html... "
ADMIN_BODY=$(curl -sk --max-time 20 "${BASE}/admin/admin.html")
if grep -q '<html' <<< "$ADMIN_BODY"; then
  pass "<html document served"
else
  fail "'<html' marker missing from /admin/admin.html"
fi

# ---------------------------------------------------------------------------
# Test 6: Admin root  /admin/  redirects to  /admin/admin.html
# ---------------------------------------------------------------------------
echo -n "Test 6: /admin/ redirects to /admin/admin.html... "
LOC=$(redirect_url "${BASE}/admin/")
if [[ "$LOC" == "${BASE}/admin/admin.html" ]]; then
  pass "302 -> ${LOC}"
else
  fail "redirect target '${LOC}' (expected ${BASE}/admin/admin.html)"
fi

# ---------------------------------------------------------------------------
# Test 7: Admin root  /admin  redirects to  /admin/admin.html
# ---------------------------------------------------------------------------
echo -n "Test 7: /admin redirects to /admin/admin.html... "
LOC=$(redirect_url "${BASE}/admin")
if [[ "$LOC" == "${BASE}/admin/admin.html" ]]; then
  pass "302 -> ${LOC}"
else
  fail "redirect target '${LOC}' (expected ${BASE}/admin/admin.html)"
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
