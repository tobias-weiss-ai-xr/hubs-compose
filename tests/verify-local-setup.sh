#!/bin/bash
# Verification script for hubs-compose local setup
# Run with: sudo bash tests/verify-local-setup.sh (needs /etc/hosts modification)

set -e

echo "=========================================="
echo "Hubs-Compose Local Setup Verification"
echo "=========================================="
echo ""

# Check if we have /etc/hosts entry
if ! grep -q "192.168.0.42 hubs.chemie-lernen.org" /etc/hosts; then
    echo "⚠️  WARNING: /etc/hosts entry missing. Adding temporarily..."
    echo "192.168.0.42 hubs.chemie-lernen.org" | sudo tee -a /etc/hosts > /dev/null
    TEMP_HOSTS=1
fi

# Tests
FAILED=0
PASSED=0

echo "Running tests..."
echo ""

# Test 1: Main page
echo -n "Test 1: Main page (HTTPS)... "
if curl -sk -f "https://hubs.chemie-lernen.org/" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((PASSED++))
else
    echo "❌ FAIL"
    ((FAILED++))
fi

# Test 2: Assets
echo -n "Test 2: Asset serving (HTTPS)... "
if curl -sk -f "https://hubs.chemie-lernen.org/assets/stylesheets/support-ffab7c7771a1786b7345.css" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((PASSED++))
else
    echo "❌ FAIL"
    ((FAILED++))
fi

# Test 3: API
echo -n "Test 3: API endpoint (HTTPS)... "
if curl -sk -f "https://hubs.chemie-lernen.org/api/v1/hubs" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((PASSED++))
else
    echo "❌ FAIL"
    ((FAILED++))
fi

# Test 4: Certificate
echo -n "Test 4: Certificate subject... "
SUBJECT=$(openssl s_client -connect hubs.chemie-lernen.org:443 -servername hubs.chemie-lernen.org 2>/dev/null | openssl x509 -noout -subject | grep -o "CN=[^,]+")
if [[ "$SUBJECT" == "CN=hubs.chemie-lernen.org" ]]; then
    echo "✅ PASS (CN=$SUBJECT)"
    ((PASSED++))
else
    echo "❌ FAIL (CN=$SUBJECT)"
    ((FAILED++))
fi

# Test 5: Direct HTTP to reticulum
echo -n "Test 5: Direct HTTP to reticulum... "
if curl -s -f "http://172.27.0.1:4002/" > /dev/null 2>&1; then
    echo "✅ PASS"
    ((PASSED++))
else
    echo "❌ FAIL"
    ((FAILED++))
fi

# Test 6: Docker healthchecks
echo -n "Test 6: Docker service health... "
cd /home/weiss/git/hubs-compose
UNHEALTHY=$(docker compose ps --format "table {{.Name}}\t{{.Status}}" | grep -v -E "healthy|running|Up" | grep -v "^NAMES" | wc -l)
if [[ "$UNHEALTHY" -eq 0 ]]; then
    echo "✅ PASS (all services healthy or running)"
    ((PASSED++))
else
    echo "❌ FAIL ($UNHEALTHY unhealthy services)"
    ((FAILED++))
    docker compose ps
fi

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "=========================================="

# Cleanup
if [[ "$TEMP_HOSTS" -eq 1 ]]; then
    echo ""
    echo "⚠️  Cleaning up temporary /etc/hosts entry..."
    sudo sed -i '/192.168.0.42 hubs.chemie-lernen.org/d' /etc/hosts
fi

# Exit with error code if tests failed
if [[ "$FAILED" -gt 0 ]]; then
    echo ""
    echo "❌ Some tests failed. Check the output above."
    exit 1
else
    echo ""
    echo "✅ All tests passed!"
    exit 0
fi
