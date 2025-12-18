#!/bin/bash
# Test suite for Hugo multi-site configuration
# Tests SSL certificates, routing, and page rendering

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

test_url() {
    local url="$1"
    local expected_status="${2:-200}"
    local description="$3"
    local min_size="${4:-100}"

    echo -n "Testing: $description... "

    response=$(curl -s -w "\n%{http_code}\n%{size_download}" "$url" 2>&1 || true)
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

    if echo | timeout 5 openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | grep -q "Verify return code: 0"; then
        echo -e "${GREEN}PASS${NC} (Valid certificate)"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (Invalid or missing certificate)"
        ((FAILED++))
    fi
}

test_content() {
    local url="$1"
    local search_string="$2"
    local description="$3"

    echo -n "Testing content: $description... "

    if curl -s "$url" | grep -q "$search_string"; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (String '$search_string' not found)"
        ((FAILED++))
    fi
}

test_redirect() {
    local url="$1"
    local expected_location="$2"
    local description="$3"

    echo -n "Testing redirect: $description... "

    location=$(curl -s -I "$url" | grep -i "^location:" | awk '{print $2}' | tr -d '\r')

    if [ "$location" = "$expected_location" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAIL${NC} (Got: $location, Expected: $expected_location)"
        ((FAILED++))
    fi
}

echo "========================================"
echo "Hugo Multi-Site Test Suite"
echo "========================================"
echo ""

echo "=== SSL Certificate Tests ==="
test_ssl_cert "chemie-lernen.org" "chemie-lernen.org SSL"
test_ssl_cert "graphwiz.ai" "graphwiz.ai SSL"
test_ssl_cert "next.tobias-weiss.org" "next.tobias-weiss.org SSL"
echo ""

echo "=== HTTP to HTTPS Redirect Tests ==="
test_redirect "http://chemie-lernen.org/" "https://chemie-lernen.org/" "chemie-lernen.org redirect"
test_redirect "http://graphwiz.ai/" "https://graphwiz.ai/" "graphwiz.ai redirect"
test_redirect "http://next.tobias-weiss.org/" "https://next.tobias-weiss.org/" "next.tobias-weiss.org redirect"
echo ""

echo "=== Homepage Tests ==="
test_url "https://chemie-lernen.org/" 200 "chemie-lernen.org homepage" 1000
test_url "https://graphwiz.ai/" 200 "graphwiz.ai homepage" 1000
test_url "https://next.tobias-weiss.org/" 200 "next.tobias-weiss.org homepage" 1000
echo ""

echo "=== Chemie Lernen Content Tests ==="
test_url "https://chemie-lernen.org/periodensystem/" 200 "Periodic table page" 5000
test_content "https://chemie-lernen.org/" "Chemie Lernen" "German title"
test_content "https://chemie-lernen.org/periodensystem/" "TABELLE" "German periodic table buttons"
echo ""

echo "=== GraphWiz AI Content Tests ==="
test_url "https://graphwiz.ai/ai/" 200 "AI page" 500
test_url "https://graphwiz.ai/xr/" 200 "XR page" 500
test_url "https://graphwiz.ai/ops/" 200 "Ops page" 500
test_url "https://graphwiz.ai/workshops/" 200 "Workshops page" 500
test_content "https://graphwiz.ai/" "AI / Enthusiam / DevOps / Digital Sovereignty / XR" "GraphWiz headline"
test_content "https://graphwiz.ai/ai/" "Artificial Intelligence" "AI page title"
echo ""

echo "=== Tobias Weiss Content Tests ==="
test_url "https://next.tobias-weiss.org/gallery/" 200 "Gallery page" 2000
test_url "https://next.tobias-weiss.org/pgp/" 200 "PGP page" 2000
test_content "https://next.tobias-weiss.org/gallery/" "Tallinn" "Gallery images"
test_content "https://next.tobias-weiss.org/pgp/" "PGP PUBLIC KEY" "PGP key"
echo ""

echo "=== Three.js CDN Test ==="
test_content "https://chemie-lernen.org/periodensystem/" "cdn.jsdelivr.net" "Three.js CDN"
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
