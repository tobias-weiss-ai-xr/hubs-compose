# Testing Hugo Multi-Site Configuration

This repository includes two test suites for validating the Hugo multi-site configuration.

## Test Suite Options

### 1. Bash Test Script (Primary)

The bash test script is the primary test tool and works on any system with bash and curl.

**Location**: `test-hugo-sites.sh`

**Usage**:
```bash
chmod +x test-hugo-sites.sh
./test-hugo-sites.sh
```

**Features**:
- SSL certificate validation
- HTTP to HTTPS redirect tests
- Homepage accessibility tests
- Content validation for all sites
- Three.js CDN verification
- HSTS header checks

**Requirements**:
- bash
- curl
- openssl (for SSL tests)

### 2. Pytest Test Suite (Optional)

A Python-based pytest test suite is also available for more structured testing.

**Location**: `test_hugo_sites.py`

**Usage**:
```bash
# Install dependencies (requires Python 3.7+)
pip install -r requirements.txt

# Run all tests
pytest test_hugo_sites.py -v

# Run specific test class
pytest test_hugo_sites.py::TestHomepages -v

# Run with HTML report
pytest test_hugo_sites.py --html=test-report.html --self-contained-html
```

**Features**:
- Parameterized tests for multiple domains
- Structured test organization by class
- Detailed test reporting
- Skip/conditional test execution
- Timeout handling
- HTML test reports

**Requirements**:
- Python 3.7+
- pytest >= 7.4.0
- requests >= 2.31.0
- pytest-timeout >= 2.1.0
- pytest-html >= 3.2.0 (optional, for HTML reports)

## Test Coverage

Both test suites cover:

### SSL/TLS Tests
- Valid SSL certificates for all domains
- Certificate expiration
- Trusted certificate chain

### HTTP Redirect Tests
- HTTP to HTTPS 301 redirects
- Correct redirect URLs
- HSTS header presence

### Content Tests
- Homepage accessibility (200 OK)
- Minimum content size validation
- Site-specific content presence

### Site-Specific Tests

**Chemie Lernen (chemie-lernen.org)**:
- German language interface
- Periodic table page with Three.js
- German button labels (TABELLE, KUGEL, HELIX, GITTER)
- Three.js loaded from CDN

**GraphWiz AI (graphwiz.ai)**:
- Headline: "AI / Enthusiam / DevOps / Digital Sovereignty / XR"
- AI, XR, Ops, Workshops section pages
- Content accessibility

**Tobias Weiss (tobias-weiss.org, www.tobias-weiss.org, next.tobias-weiss.org)**:
- Gallery page with Tallinn images
- PGP page with public key
- Multiple domain access (tobias-weiss.org, www.tobias-weiss.org, next.tobias-weiss.org)

### HAProxy Tests
- Domain routing to correct backends
- HSTS headers on all responses
- SSL termination working correctly

## Continuous Integration

The bash test script can be integrated into CI/CD pipelines:

```bash
# Example GitHub Actions workflow
- name: Test Hugo Sites
  run: |
    chmod +x test-hugo-sites.sh
    ./test-hugo-sites.sh
```

## Troubleshooting Tests

### SSL Certificate Failures
- Check if certificates are renewed: `docker logs haproxy`
- Verify domain DNS points to correct IP
- Check Let's Encrypt rate limits

### Content Test Failures
- Verify Hugo containers are running: `docker ps | grep hugo`
- Check Hugo logs: `docker logs hubs-compose_hugo-X_1`
- Test backend directly: `curl http://localhost:131X`

### Timeout Failures
- Increase timeout in pytest: Edit `pytest.ini` timeout value
- Check network connectivity
- Verify services are responding: `curl -I https://domain.com/`

## Test Development

To add new tests:

### Bash Script
Edit `test-hugo-sites.sh` and add test functions following the pattern:
```bash
test_url "https://example.com/page" 200 "Description" 1000
test_content "https://example.com/" "Expected String" "Description"
```

### Pytest
Add test methods to existing classes or create new test classes in `test_hugo_sites.py`:
```python
class TestNewFeature:
    def test_something(self):
        response = requests.get("https://example.com/")
        assert "expected" in response.text
```

## Manual Testing

For quick manual verification:

```bash
# Test SSL certificates
openssl s_client -connect chemie-lernen.org:443 -servername chemie-lernen.org

# Test HTTP redirect
curl -I http://graphwiz.ai/

# Test content
curl -s https://next.tobias-weiss.org/gallery/ | grep Tallinn

# Test HAProxy routing
curl -H "Host: tobias-weiss.org" https://178.254.2.90/gallery/
```
