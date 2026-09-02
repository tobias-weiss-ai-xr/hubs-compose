#!/bin/bash
set -uo pipefail

# Constants
BASE_URL="https://hubs.chemie-lernen.org"
PASSED=0
FAILED=0

# Assets to verify
# Format: "path|expected_content_type|description"
ASSETS=(
  "/assets/js/frontend-b15f0d3a8e669ae5e13d.js|application/javascript|frontend bundle"
  "/assets/js/support-47b5aeb561a531336030.js|application/javascript|support bundle"
  "/assets/js/store-61f0bec106280a0ef3a1.js|application/javascript|store bundle"
  "/assets/js/index-19b3ec05dc199afecec2.js|application/javascript|index bundle"
  "/favicon.ico|image/*|favicon.ico"
)

verify_asset() {
  local path="$1"
  local expected_type="$2"
  local desc="$3"
  local url="${BASE_URL}${path}"

  # Get HTTP status and Content-Type header
  # Use -I for HEAD request to be efficient
  local response
  response=$(curl -skI --max-time 20 "$url")

  local status
  status=$(grep 'HTTP/' <<< "$response" | tail -n 1 | awk '{print $2}')
  
  # Fallback for non-standard HTTP response lines (e.g. "SimpleHTTP/0.6 200 OK")
  if [[ "$status" == "SimpleHTTP/0.6" || -z "$status" ]]; then
     status=$(grep -E '^[^ ]+ [0-9]{3}' <<< "$response" | head -n 1 | awk '{print $2}')
  fi
  
  local content_type
  content_type=$(grep -i 'Content-Type:' <<< "$response" | awk '{print $2}' | tr -d '\r')

  if [[ "$status" != "200" ]]; then
    echo "❌ FAIL  $desc: Expected status 200, got $status ($url)"
    return 1
  fi

  # Handle wildcard for images (image/*)
  if [[ "$expected_type" == "image/*" ]]; then
    if [[ ! "$content_type" =~ ^image/ ]]; then
      echo "❌ FAIL  $desc: Expected content type image/*, got $content_type ($url)"
      return 1
    fi
  else
    if [[ "$content_type" != *"$expected_type"* ]]; then
      echo "❌ FAIL  $desc: Expected content type $expected_type, got $content_type ($url)"
      return 1
    fi
  fi

  echo "✅ PASS  $desc"
  return 0
}

echo "Verifying landing page assets at $BASE_URL..."

for asset_entry in "${ASSETS[@]}"; do
  IFS='|' read -r path expected_type desc <<< "$asset_entry"
  if verify_asset "$path" "$expected_type" "$desc"; then
    PASSED=$((PASSED + 1))
  else
    FAILED=$((FAILED + 1))
  fi
done

echo "--------------------------------------------------"
echo "Results: $PASSED passed, $FAILED failed"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
