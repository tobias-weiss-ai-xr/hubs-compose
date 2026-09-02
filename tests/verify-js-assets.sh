#!/bin/bash
set -uo pipefail

# --- Configuration ---
TARGET_URL="https://hubs.chemie-lernen.org"
MIN_SIZE_KB=10
CURL_OPTS="-sk --max-time 20"

PASSED=0
FAILED=0

echo "Verifying JS bundle assets on $TARGET_URL..."

# 1. Extract bundle paths from homepage
HOMEPAGE=$(curl $CURL_OPTS "$TARGET_URL")

# Patterns for bundles: frontend-*.js, store-*.js, support-*.js, index-*.js
# We extract the src attributes: /assets/js/...
BUNDLES=$(grep -oE '/assets/js/(frontend|store|support|index)-[a-z0-9]+\.js' <<< "$HOMEPAGE" | sort -u)

if [[ -z "$BUNDLES" ]]; then
    echo "❌ FAIL  No JS bundles found on homepage"
    FAILED=$((FAILED+1))
    exit 1
fi

for BUNDLE_PATH in $BUNDLES; do
    FULL_URL="${TARGET_URL}${BUNDLE_PATH}"
    
    # Check Bundle HTTP 200 and Size
    # -w "%{http_code} %{size_download}"
    RESPONSE=$(curl $CURL_OPTS -w "%{http_code} %{size_download}" -o /tmp/bundle_check.tmp "$FULL_URL")
    HTTP_CODE=$(echo "$RESPONSE" | cut -d' ' -f1)
    SIZE_BYTES=$(echo "$RESPONSE" | cut -d' ' -f2)
    SIZE_KB=$((SIZE_BYTES / 1024))

    if [[ "$HTTP_CODE" == "200" ]] && [[ "$SIZE_KB" -gt "$MIN_SIZE_KB" ]]; then
        echo "✅ PASS  Bundle $BUNDLE_PATH (HTTP 200, ${SIZE_KB}KB)"
        PASSED=$((PASSED+1))
    else
        echo "❌ FAIL  Bundle $BUNDLE_PATH (HTTP $HTTP_CODE, ${SIZE_KB}KB)"
        FAILED=$((FAILED+1))
    fi

    # Check .map file
    MAP_PATH="${BUNDLE_PATH}.map"
    MAP_URL="${TARGET_URL}${MAP_PATH}"
    MAP_CODE=$(curl $CURL_OPTS -w "%{http_code}" -o /dev/null "$MAP_URL")

    if [[ "$MAP_CODE" == "200" ]]; then
        echo "✅ PASS  Map $MAP_PATH (HTTP 200)"
        PASSED=$((PASSED+1))
    else
        echo "❌ FAIL  Map $MAP_PATH (HTTP $MAP_CODE)"
        FAILED=$((FAILED+1))
    fi
done

echo "--------------------------------------------------"
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
    exit 1
else
    exit 0
fi
