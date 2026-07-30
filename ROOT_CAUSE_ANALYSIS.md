# Root Cause Analysis: Hubs-Compose Asset Loading Issues

## Executive Summary
The primary issue preventing asset loading (`/assets/...` returning HTTP 500) was **DNS resolution**. All testing was being performed against the **public production server** (178.254.2.90) instead of the local development server (192.168.0.42) because `hubs.chemie-lernen.org` DNS resolves to the public IP.

Once this was identified, additional configuration issues were found and fixed in the Caddy reverse proxy and Docker Compose setup.

---

## Primary Root Cause: DNS Resolution

### Symptom
- `https://hubs.chemie-lernen.org/assets/...` consistently returned HTTP 500
- Direct access to `http://172.27.0.1:4002/assets/...` returned HTTP 200
- Caddy configuration appeared correct

### Diagnosis
```bash
# DNS lookup shows public IP
host hubs.chemie-lernen.org
# Output: hubs.chemie-lernen.org has address 178.254.2.90

# Caddy on public server serves wrong certificate
openssl s_client -connect hubs.chemie-lernen.org:443 -servername hubs.chemie-lernen.org
# Output: subject=CN=cloud.chemie-lernen.org (WRONG!)
```

### Root Cause
The domain `hubs.chemie-lernen.org` is configured in public DNS to point to `178.254.2.90` (production server). All development testing was being done against this public server, which:
1. Had a different Caddy configuration
2. Used a different certificate (cloud.chemie-lernen.org)
3. Was not configured to proxy to the local reticulum instance

### Solution
For **local development**, add to `/etc/hosts`:
```
192.168.0.42 hubs.chemie-lernen.org
```

For **production**, deploy the correct Caddy configuration to the server at 178.254.2.90.

---

## Secondary Issues Found and Fixed

### Issue 1: Caddy Certificate Configuration
**Problem:** Caddy was trying to obtain Let's Encrypt certificates but failing ACME challenges.
**Fix:** Use manual certificate loading with self-signed certificates for development.
```caddyfile
hubs.chemie-lernen.org {
    tls /etc/ssl/certs/hubs-chemie-lernen-org.crt /etc/ssl/certs/hubs-chemie-lernen-org.key
    reverse_proxy 172.27.0.1:4002
}
```

### Issue 2: Docker Network Isolation
**Problem:** Caddy container on `opencloud-compose_opencloud-net` couldn't reach host-network containers via `127.0.0.1`.
**Fix:** Use Docker gateway IP `172.27.0.1` for host-network containers.

### Issue 3: Webpack HTTPS/HTTP Mismatch
**Problem:** Webpack dev servers were configured for HTTPS but reticulum was using HTTP.
**Fix:** Standardize all to HTTP:
- Changed `server.type` from `"https"` to `"http"`
- Changed `allowedHosts` to `"all"`
- Removed `createHTTPSConfig()` calls

### Issue 4: Missing Healthchecks
**Problem:** postgrest and spoke services had no healthchecks.
**Fix:** Added healthchecks:
```yaml
# postgrest
healthcheck:
  test: wget --no-verbose --tries=1 --spider http://localhost:3000/
  interval: 30s
  start_period: 15s

# spoke  
healthcheck:
  test: curl -f http://localhost:9090
  interval: 30s
  start_period: 30s
```

### Issue 5: Missing Service Dependencies
**Problem:** Services started before their dependencies were ready.
**Fix:** Added `depends_on`:
- postgrest → db (service_healthy)
- hubs-admin, hubs-client, spoke → reticulum (service_started)

---

## Verification Checklist

### Local Development (with /etc/hosts modification)
```bash
# Add DNS entry
echo "192.168.0.42 hubs.chemie-lernen.org" | sudo tee -a /etc/hosts

# Test endpoints
curl -sk "https://hubs.chemie-lernen.org/"                          # Expected: 200
curl -sk "https://hubs.chemie-lernen.org/assets/..."                # Expected: 200
curl -sk "https://hubs.chemie-lernen.org/api/v1/hubs"               # Expected: 200

# Verify certificate
openssl s_client -connect hubs.chemie-lernen.org:443 -servername hubs.chemie-lernen.org | \
  openssl x509 -noout -subject
# Expected: subject=CN=hubs.chemie-lernen.org

# Cleanup
sudo sed -i '/192.168.0.42 hubs.chemie-lernen.org/d' /etc/hosts
```

### Production Deployment
```bash
# On server 178.254.2.90:
# 1. Copy Caddyfile to /etc/caddy/Caddyfile
# 2. Obtain valid SSL certificate (Let's Encrypt or commercial)
# 3. Update Caddyfile to use the certificate
# 4. Ensure DNS points to this server
# 5. Restart Caddy: docker restart opencloud-compose-caddy
```

---

## Files Modified

### hubs-compose Repository
- `docker-compose.yml` - Healthchecks, dependencies, environment variables
- `Caddyfile` - Reverse proxy configuration with TLS
- `certs/hubs-chemie-lernen-org.crt` - Self-signed certificate
- `certs/hubs-chemie-lernen-org.key` - Self-signed key
- `FIXES_SUMMARY.md` - Complete documentation of all fixes
- ` tests/verify-local-setup.sh` - Verification script

### hubs Service Repository  
- `webpack.config.js` - Changed to HTTP, allowedHosts: 'all'
- `admin/webpack.config.js` - Changed to HTTP
- `src/utils/bit-utils.ts` - Added missing functions

### reticulum Service Repository
- `config/prod.exs` - secure?: false, proper URLs
- `config/runtime.exs` - HTTP page origins
- `lib/ret_web/controllers/page_controller.ex` - Fixed fallback URLs

---

## Lessons Learned

1. **DNS Resolution Matters:** Always verify you're testing against the correct server
2. **Container Networking:** In host network mode, containers share the host IP; from other networks, use Docker gateway IP
3. **Caddy v2 TLS:** The `tls` directive in a site block loads certificates for that specific domain
4. **Healthchecks:** Critical for service monitoring and dependency management
5. **Protocol Consistency:** All services must agree on HTTPS/HTTP; mixing causes failures

