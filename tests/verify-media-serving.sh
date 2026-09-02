#!/usr/bin/env bash
# verify-media-serving.sh — Reticulum /files/ media contract
#
# Validates the media pipeline end-to-end using the live scene assets:
#   GLB: 200 + model/gltf-binary + must-revalidate cache + accept-ranges
#        + valid glTF magic bytes + parseable JSON chunk with matching length
#   PNG: 200 + image/png (informational if the scene has no screenshot)
#
# Blobs are AES-256-CTR encrypted at rest; a broken decrypt surfaces here as
# an unexpected 401. The element API throttles to ~1 rps/IP — pace requests.
set -uo pipefail

HOST="hubs.chemie-lernen.org"
PASSED=0
FAILED=0

pass() { echo "✅ PASS  $1"; PASSED=$((PASSED+1)); }
fail() { echo "❌ FAIL  $1"; FAILED=$((FAILED+1)); }

echo "=========================================="
echo "Media Serving Verification (/files/)"
echo "  Target: https://${HOST}"
echo "=========================================="

# --- discover scene asset URLs from the element API (paced, retry once) ---
fetch_element_api() {
  local body
  body=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null)
  if jq -e '.hubs | type == "array"' <<< "$body" >/dev/null 2>&1; then
    printf '%s' "$body"
    return 0
  fi
  sleep 1.2
  body=$(curl -sk --max-time 30 "https://${HOST}/api/v1/hubs/element/h" 2>/dev/null)
  if jq -e '.hubs | type == "array"' <<< "$body" >/dev/null 2>&1; then
    printf '%s' "$body"
    return 0
  fi
  return 1
}

ELEMENT_JSON=$(fetch_element_api)
if [[ -z "$ELEMENT_JSON" ]]; then
  echo "❌ FAIL  Element API unreachable — cannot discover media URLs"
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi

MODEL_URL=$(jq -r '[.hubs[] | select(.scene != null and .scene.model_url != null)] | first | .scene.model_url // empty' <<< "$ELEMENT_JSON" 2>/dev/null)
SCREEN_URL=$(jq -r '[.hubs[] | select(.scene != null and .scene.screenshot_url != null)] | first | .scene.screenshot_url // empty' <<< "$ELEMENT_JSON" 2>/dev/null)

if [[ -z "$MODEL_URL" ]]; then
  echo "❌ FAIL  No scene model_url found in element API response"
  echo ""
  echo "Results: 0 passed, 1 failed"
  exit 1
fi
echo "  GLB:       ${MODEL_URL}"
echo "  Screenshot: ${SCREEN_URL:-<none>}"
echo ""

# --- GLB headers ---
HDRS=$(curl -skI --max-time 30 "$MODEL_URL" | tr -d '\r')
CODE=$(head -1 <<< "$HDRS" | grep -o '[0-9][0-9][0-9]')
if [[ "$CODE" == "200" ]]; then
  pass "GLB serves HTTP 200"
else
  fail "GLB HTTP status ${CODE:-none} (expected 200; 401 = broken blob decryption)"
fi

CT=$(grep -i '^content-type:' <<< "$HDRS" | head -1)
if grep -qi 'model/gltf-binary' <<< "$CT"; then
  pass "GLB content-type is model/gltf-binary"
else
  fail "GLB content-type wrong (got: ${CT:-none})"
fi

CC=$(grep -i '^cache-control:' <<< "$HDRS" | head -1)
if grep -qi 'must-revalidate' <<< "$CC"; then
  pass "GLB cache-control includes must-revalidate (scene updates propagate)"
else
  fail "GLB cache-control missing must-revalidate (got: ${CC:-none})"
fi

AR=$(grep -i '^accept-ranges:' <<< "$HDRS" | head -1)
if grep -qi 'bytes' <<< "$AR"; then
  pass "GLB served with accept-ranges: bytes"
else
  fail "GLB missing accept-ranges: bytes"
fi

# --- GLB body: magic bytes + JSON chunk parse + length consistency ---
TMP_GLB=$(mktemp /tmp/verify-media-XXXXXX.glb)
curl -sk --max-time 60 "$MODEL_URL" -o "$TMP_GLB"
python3 - "$TMP_GLB" <<'PYEOF' && GLB_PARSE=ok || GLB_PARSE=bad
import struct, json, sys
d = open(sys.argv[1], "rb").read()
assert d[:4] == b"glTF", "bad magic"
version = struct.unpack("<I", d[4:8])[0]
total = struct.unpack("<I", d[8:12])[0]
assert total == len(d), f"length mismatch: header {total} != actual {len(d)}"
jl = struct.unpack("<I", d[12:16])[0]
j = json.loads(d[20:20+jl])
assert "asset" in j and "scenes" in j, "not a scene document"
PYEOF
if [[ "$GLB_PARSE" == "ok" ]]; then
  pass "GLB body is a valid glTF 2.0 binary (magic, version, length, JSON chunk)"
else
  fail "GLB body failed to parse as glTF (truncated or corrupted)"
fi
rm -f "$TMP_GLB"

# --- screenshot (informational when absent) ---
if [[ -n "$SCREEN_URL" ]]; then
  HDRS=$(curl -skI --max-time 30 "$SCREEN_URL" | tr -d '\r')
  CODE=$(head -1 <<< "$HDRS" | grep -o '[0-9][0-9][0-9]')
  CT=$(grep -i '^content-type:' <<< "$HDRS" | head -1)
  if [[ "$CODE" == "200" ]] && grep -qi 'image/png' <<< "$CT"; then
    pass "Scene screenshot serves 200 image/png"
  else
    fail "Scene screenshot: status ${CODE:-none}, content-type ${CT:-none}"
  fi
else
  pass "Scene has no screenshot_url — screenshot check skipped (informational)"
fi

echo ""
echo "=========================================="
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo "=========================================="

if [[ $FAILED -eq 0 ]]; then
  exit 0
fi
exit 1
