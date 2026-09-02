#!/usr/bin/env bash
# verify-traefik-middleware-config.sh — Static analysis of the Traefik
# middleware wiring in the live compose file.
#
# Verifies (OFFLINE — no network/curl) that the hubs-security-headers
# middleware is:
#   1. DEFINED with the expected security headers
#      (X-Frame-Options SAMEORIGIN, X-Content-Type-Options nosniff,
#      forced HSTS, Referrer-Policy strict-origin-when-cross-origin)
#   2. ATTACHED to all four Hubs routers:
#      hubs-api, hubs-root, hubs-admin, hubs-spoke
#   3. ORDERED BEFORE any redirect middleware chained on the same router
#      (hubs-admin-redirect on hubs-admin, hubs-spoke-redirect on hubs-spoke)
#      so the security headers are applied to every response, including the
#      redirects themselves.
#
# The middleware is deliberately self-contained and NOT the shared
# security-headers@file middleware: the shared one sets permissionsPolicy
# camera=()/microphone=() (breaks voice chat + avatar capture) and
# stsIncludeSubdomains/preload (nearspark.hubs.chemie-lernen.org must stay
# out of an HSTS rollout decision). X-Frame-Options is SAMEORIGIN (not DENY)
# so Hubs' own iframe uses (scene viewer, room embeds) keep working.
#
# Static analysis source:
#   /opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml  (live compose file)
#
# Run with: bash tests/verify-traefik-middleware-config.sh
#
# NOTE: deliberately does NOT use `set -e` — a verification script must run
# every test and report the full matrix, not bail on the first failure.
# Arithmetic like ((FAILED++)) returns exit 1 when the counter is 0, which
# `set -e` would treat as a fatal error. We use VAR=$((VAR+1)) instead.
# grep -q is fed via here-strings (never pipes) so SIGPIPE cannot turn a
# match into a false failure.

set -uo pipefail

COMPOSE="/opt/git/hugo-chemie-lernen-org/docker-compose.hubs.yml"

# The four Hubs routers that must attach the security-headers middleware.
ROUTERS=(hubs-api hubs-root hubs-admin hubs-spoke)
# Redirect middlewares that may share a router chain. On any router that
# chains one of these, hubs-security-headers must come FIRST.
REDIRECT_MW=("hubs-admin-redirect" "hubs-spoke-redirect")

PASSED=0
FAILED=0
TN=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

# begin_test <description>: prints the running test number + description
# without a trailing newline, so pass()/fail() complete the line.
begin_test() {
  TN=$((TN+1))
  echo -n "Test ${TN}: $1... "
}

# ---------------------------------------------------------------------------
# mk_label <label-suffix> — print the VALUE of the matching traefik label from
# the compose file (e.g. the value of
# "http.middlewares.hubs-security-headers.headers.stsseconds"), or empty if
# absent. Dots are escaped for the regex. The YAML cruft ('      - "traefik..'
# prefix and the trailing '"') is stripped so the result is a clean value
# (e.g. "31536000" or "hubs-security-headers@docker,hubs-admin-redirect").
# ---------------------------------------------------------------------------
mk_label() {
  local line val
  line=$(grep -E "traefik\.${1//./\\.}=" "$COMPOSE" | head -n 1)
  [[ -z "$line" ]] && return 0
  val="${line#*=}"          # drop the '      - "traefik.<key>=' prefix
  val="${val%\"}"           # drop the trailing YAML double quote
  val="${val//[[:space:]]/}" # drop any leftover whitespace / CR (CRLF hygiene)
  printf '%s' "$val"
}

# ---------------------------------------------------------------------------
# router_middlewares <router> — print the comma-separated middleware chain of
# the router's traefik.http.routers.<router>.middlewares= label, or empty if
# the label is missing.
# ---------------------------------------------------------------------------
router_middlewares() {
  mk_label "http.routers.${1}.middlewares"
}

echo "=========================================="
echo "Traefik Middleware Config Verification"
echo "  Compose: $COMPOSE"
echo "=========================================="
echo ""

# ---------------------------------------------------------------------------
# Test 1: compose file exists and is readable
# ---------------------------------------------------------------------------
begin_test "compose file exists and is readable"
if [[ -f "$COMPOSE" && -r "$COMPOSE" ]]; then
  pass "$COMPOSE"
else
  fail "compose file not found or not readable: $COMPOSE"
fi

ANALYZED=0
[[ -r "$COMPOSE" ]] && ANALYZED=1

# ---------------------------------------------------------------------------
# Middleware DEFINITION — the expected hubs-security-headers header labels
# (defined on the hubs-client service and referenced by all four routers).
# ---------------------------------------------------------------------------
echo ""
echo "--- hubs-security-headers middleware definition ---"

# Test 2: middleware is defined (its headers.* block exists)
begin_test "hubs-security-headers middleware defined"
if [[ "$ANALYZED" -eq 1 ]] && mk_label "http.middlewares.hubs-security-headers.headers.customframeoptionsvalue" > /dev/null; then
  pass "hubs-security-headers.headers.* labels found"
else
  fail "hubs-security-headers middleware definition not found"
fi

# Test 3: X-Frame-Options = SAMEORIGIN (keeps Hubs iframe uses working)
begin_test "X-Frame-Options SAMEORIGIN"
FW=$(mk_label "http.middlewares.hubs-security-headers.headers.customframeoptionsvalue")
if [[ -n "$FW" ]] && [[ "${FW#*=}" == "SAMEORIGIN" ]]; then
  pass "customframeoptionsvalue=SAMEORIGIN"
else
  fail "expected customframeoptionsvalue=SAMEORIGIN (got: ${FW:-<missing>})"
fi

# Test 4: X-Content-Type-Options = nosniff
begin_test "X-Content-Type-Options nosniff"
CT=$(mk_label "http.middlewares.hubs-security-headers.headers.contenttypenosniff")
if [[ -n "$CT" ]] && [[ "${CT#*=}" == "true" ]]; then
  pass "contenttypenosniff=true"
else
  fail "expected contenttypenosniff=true (got: ${CT:-<missing>})"
fi

# Test 5: force the HSTS header on
begin_test "force HSTS header (forcestsheader)"
FHS=$(mk_label "http.middlewares.hubs-security-headers.headers.forcestsheader")
if [[ -n "$FHS" ]] && [[ "${FHS#*=}" == "true" ]]; then
  pass "forcestsheader=true"
else
  fail "expected forcestsheader=true (got: ${FHS:-<missing>})"
fi

# Test 6: HSTS max-age >= 1 year (31536000s)
begin_test "HSTS max-age stsseconds >= 31536000"
STS=$(mk_label "http.middlewares.hubs-security-headers.headers.stsseconds")
STS_VAL="${STS#*=}"
if [[ -n "$STS" ]] && [[ "$STS_VAL" =~ ^[0-9]+$ ]] && [[ "$STS_VAL" -ge 31536000 ]]; then
  pass "stsseconds=${STS_VAL}"
else
  fail "expected stsseconds >= 31536000 (got: ${STS_VAL:-<missing>})"
fi

# Test 7: Referrer-Policy = strict-origin-when-cross-origin
begin_test "Referrer-Policy strict-origin-when-cross-origin"
RP=$(mk_label "http.middlewares.hubs-security-headers.headers.referrerpolicy")
if [[ -n "$RP" ]] && [[ "${RP#*=}" == "strict-origin-when-cross-origin" ]]; then
  pass "referrerpolicy=strict-origin-when-cross-origin"
else
  fail "expected referrerpolicy=strict-origin-when-cross-origin (got: ${RP:-<missing>})"
fi

# Test 8: guard — must NOT strip camera/microphone via permissionsPolicy (the
# shared security-headers@file middleware does exactly this, which breaks
# voice chat + avatar capture — the reason this middleware was defined).
begin_test "no permissionsPolicy stripping camera/microphone"
PP=$(mk_label "http.middlewares.hubs-security-headers.headers.permissionspolicy")
if [[ -z "$PP" ]]; then
  pass "no permissionspolicy override on hubs-security-headers"
else
  fail "permissionspolicy override found: ${PP} (would break camera/mic)"
fi

# Test 9: guard — must NOT force HSTS includeSubDomains/preload (the
# nearspark.hubs.chemie-lernen.org subdomain stays out of the HSTS rollout).
begin_test "no HSTS includeSubDomains/preload forced"
SUB=$(mk_label "http.middlewares.hubs-security-headers.headers.stsincludesubdomains")
PRE=$(mk_label "http.middlewares.hubs-security-headers.headers.stspreload")
if [[ -z "$SUB" && -z "$PRE" ]]; then
  pass "stsincludesubdomains/stspreload not set"
else
  fail "HSTS subdomain/preload forced (sub=${SUB:-<none>} pre=${PRE:-<none>})"
fi

# ---------------------------------------------------------------------------
# Router ATTACHMENT — all four routers must chain hubs-security-headers.
# (Reference may be bare "hubs-security-headers" — same-container/docker
# provider — or fully qualified "hubs-security-headers@docker".)
# ---------------------------------------------------------------------------
echo ""
echo "--- hubs-security-headers attached to all 4 routers ---"

for router in "${ROUTERS[@]}"; do
  begin_test "router ${router} attaches hubs-security-headers"
  MW=$(router_middlewares "$router")
  if [[ -n "$MW" ]] && grep -qE 'hubs-security-headers(@docker)?' <<< "$MW"; then
    pass "${router} -> ${MW}"
  else
    fail "${router} middlewares label missing or lacks hubs-security-headers (got: ${MW:-<missing>})"
  fi
done

# ---------------------------------------------------------------------------
# ORDERING — on any router that chains a redirect middleware, hubs-security-
# headers must come BEFORE it, so security headers are added to the response
# before the redirect decision is applied. Routers without a redirect
# middleware satisfy this trivially.
# ---------------------------------------------------------------------------
echo ""
echo "--- ordering: hubs-security-headers BEFORE redirect middlewares ---"

for router in "${ROUTERS[@]}"; do
  begin_test "${router} orders security-headers before redirects"
  MW=$(router_middlewares "$router")
  if [[ -z "$MW" ]]; then
    fail "${router}: no middlewares label to inspect"
    continue
  fi
  # Split the comma-separated chain and record positions.
  local_ifs=$IFS
  IFS=','
  sec_pos=-1
  red_pos=-1
  pos=0
  for mw in $MW; do
    if [[ "$mw" =~ ^hubs-security-headers(@docker)?$ ]]; then
      sec_pos=$pos
    fi
    for redir in "${REDIRECT_MW[@]}"; do
      if [[ "$mw" == "$redir" ]]; then
        red_pos=$pos
      fi
    done
    pos=$((pos+1))
  done
  IFS=$local_ifs

  if [[ "$sec_pos" -ge 0 ]]; then
    if [[ "$red_pos" -lt 0 || "$sec_pos" -lt "$red_pos" ]]; then
      pass "${MW}"
    else
      fail "${router}: hubs-security-headers comes AFTER redirect middleware (chain: ${MW})"
    fi
  else
    fail "${router}: hubs-security-headers not found in chain (${MW})"
  fi
done

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
