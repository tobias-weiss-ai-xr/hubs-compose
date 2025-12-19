#!/bin/bash
# Comprehensive test suite for the entire system (Local Aware)
# Tests SSL certificates, routing, and page rendering for Hugo sites and Mailcow

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SERVER_IP="127.0.0.1"
PASSED=0
FAILED=0

test_url() {
    local domain="$1"
    local path="$2"
    local expected_status="${3:-200}"
    local description="$4"
    local min_size="${5:-100}"

    echo -n "Testing: $description... "

    url="https://$SERVER_IP$path"
    response=$(curl -s -k --max-time 10 -H "Host: $domain" -w "\n%{http_code}\n%{size_download}" "$url" 2>&1 || true)
    status=$(echo "$response" | tail -2 | head -1)
    size=$(echo "$response" | tail -1)

    if [ "$status" = "$expected_status" ] && [ "$size" -ge "$min_size" ]; then
        echo -e "${GREEN}PASS${NC} (HTTP $status, $size bytes)"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (HTTP $status, $size bytes, expected $expected_status with >=$min_size bytes)"
        ((FAILED++))
    fi
}

test_ssl_cert() {
    local domain="$1"
    local description="$2"

    echo -n "Testing SSL: $description... "

    if echo | timeout 5 openssl s_client -connect "$SERVER_IP:443" -servername "$domain" 2>/dev/null | grep -q "Verify return code: 0"; then
        echo -e "${GREEN}PASS${NC} (Valid certificate)"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (Invalid or missing certificate)"
        ((FAILED++))
    fi
}

test_content() {
    local domain="$1"
    local path="$2"
    local search_string="$3"
    local description="$4"

    echo -n "Testing content: $description... "

    url="https://$SERVER_IP$path"
    if curl -s -k --max-time 10 -H "Host: $domain" "$url" | grep -q "$search_string"; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (String '$search_string' not found)"
        ((FAILED++))
    fi
}

test_redirect() {
    local domain="$1"
    local path="$2"
    local expected_location="$3"
    local description="$4"

    echo -n "Testing redirect: $description... "

    url="http://$SERVER_IP$path"
    # Using curl to get the Location header
    location=$(curl -s -k --max-time 10 -I -H "Host: $domain" "$url" | grep -i "^location:" | sed 's/location: //i' | tr -d '\r' | xargs)

    if [ "$location" = "$expected_location" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (Got: '$location', Expected: '$expected_location')"
        ((FAILED++))
    fi
}

echo "========================================"
echo "System Comprehensive Test Suite (Local)"
echo "Date: $(date)"
echo "========================================"
echo ""

echo "=== SSL Certificate Tests ==="
for dom in chemie-lernen.org graphwiz.ai graphwiz.de next.tobias-weiss.org mail.graphwiz.ai mail.chemie-lernen.org mail.tobias-weiss.org mail.graphwiz.de; do
    test_ssl_cert "$dom" "$dom SSL"
done
echo ""

echo "=== HTTP to HTTPS Redirect Tests ==="
for dom in chemie-lernen.org graphwiz.ai graphwiz.de next.tobias-weiss.org mail.graphwiz.ai mail.chemie-lernen.org mail.tobias-weiss.org mail.graphwiz.de; do
    test_redirect "$dom" "/" "https://$dom/" "$dom redirect"
done
echo ""

echo "=== Homepage Accessibility Tests ==="
test_url "chemie-lernen.org" "/" 200 "chemie-lernen.org homepage" 1000
test_url "graphwiz.ai" "/" 200 "graphwiz.ai homepage" 1000
test_url "graphwiz.de" "/" 200 "graphwiz.de homepage" 1000
test_url "next.tobias-weiss.org" "/" 200 "next.tobias-weiss.org homepage" 1000
test_url "mail.graphwiz.ai" "/" 200 "Mailcow UI (graphwiz.ai)" 1000
echo ""

echo "=== GraphWiz AI Content Tests ==="
test_url "graphwiz.ai" "/security/" 200 "Security page" 500
test_content "graphwiz.ai" "/security/" "DevSecOps: Security as a Foundation" "Security page content"
test_content "graphwiz.ai" "/workshops/" "CoCreate – Wissen gemeinsam organisieren" "Workshops updated content"
echo ""

echo "=== Mailcow API Test ==="
# Test API via the local port directly
# Note: In this version of Mailcow, unauthorized API calls return 200 but with an empty body
response=$(curl -s -k --max-time 10 -w "\n%{http_code}\n%{size_download}" "https://127.0.0.1:8443/api/v1/get/domain/all")
status=$(echo "$response" | tail -2 | head -1)
size=$(echo "$response" | tail -1)

if [ "$status" = "200" ] && [ "$size" = "0" ]; then
    echo -e "Testing: Mailcow API (unauthorized check)... ${GREEN}PASS${NC} (HTTP 200, 0 bytes - Expected for unauthorized)"
    ((PASSED++))
else
    echo -e "Testing: Mailcow API (unauthorized check)... ${RED}FAIL${NC} (HTTP $status, $size bytes, expected 200 with 0 bytes)"
    ((FAILED++))
fi
echo ""

echo "========================================"
echo "Test Results Summary"
echo "========================================"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
