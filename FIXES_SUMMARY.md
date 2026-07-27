# Hubs-Compose Fixes Summary

## Date: July 22, 2026

## Critical Issues Fixed

### 1. Reticulum Compile Errors
**Status:** Fixed
**Files:** `services/reticulum/lib`

- `GoogleClient` - Added missing `@behaviour ModuleConfig` implementation
- `HubRole` - Added missing `Bitwise` import and `use Bitwise`
- `HubRoleMembership` - Added missing `Ecto.Query` import, fixed pin syntax
- `RbacController` - Removed unused alias

### 2. 503 "Missing file index.html" + Asset Loading
**Status:** Fixed
**Root Cause:** HTTPS/HTTP protocol mismatch between webpack dev server and reticulum's HTTP client

**Changes:**
- `services/hubs/webpack.config.js` - Changed `type: "https"` → `type: "http"`
- `services/reticulum/config/runtime.exs` - Changed `:hubs_page_origin` from `"https://hubs-client:8080"` to `"http://hubs-client:8080"`
- `services/reticulum/config/runtime.exs` - Changed `:admin_page_origin`, `:spoke_page_origin` from `"https://"` to `"http://"`
- `docker-compose.yml` - Changed healthcheck from `https://localhost:8080` → `http://localhost:8080`
- `services/spoke/webpack.config.js` - Changed `https: createHTTPSConfig()` → `https: false`
- Remote Traefik (`178.254.2.90`) - Changed hubs-client backend from `https://192.168.42.42:8083` → `http://192.168.42.42:8083`

### 3. Database Migration Logic Bug
**Status:** Fixed
**File:** `services/reticulum/lib/ret/application.ex`

**Bug:** Migration check would skip ALL migrations on subsequent starts because pattern match `[_ | _]` returned `:ok` regardless of pending migrations.

**Fix:** Added check for `:down` (pending) migrations before skipping:
```elixir
migrations ->
  if Enum.any?(migrations, &match?({_, _, :down}, &1)) do
    Ecto.Migrator.run(Ret.SessionLockRepo, priv_path, :up, all: true, prefix: "ret0")
  end
```

### 4. Database Schema Migrations
**Status:** Fixed
**Action:** Applied 3 pending migrations manually via SQL

1. `20260720130000_create_hub_templates` - Creates `hub_templates` table
2. `20260720140000_add_google_to_oauth_provider_source` - Adds 'google' to enum
3. `20260720150000_add_role_to_hub_role_memberships` - **CRITICAL** Adds `role` column to `hub_role_memberships` table (was causing `join crashed`)

### 5. Network Isolation - PostgREST & Coturn
**Status:** Fixed
**Issue:** Both services were on `mozilla-hubs` Docker network, couldn't resolve `db` hostname in `hubs-compose` network

**Fix:**
```bash
# On remote server (178.254.2.90)
docker network connect hubs-compose hubs-compose-postgrest-1
docker network connect hubs-compose hubs-compose-coturn-1
docker compose up -d --force-recreate postgrest coturn
```

### 6. Spoke ClassroomPage.js Compilation Error
**Status:** Fixed
**File:** `services/spoke/src/.babelrc`

**Issue:** `optionalChaining` syntax not enabled in Babel config

**Fix:** Added `@babel/plugin-proposal-optional-chaining` to plugins list

### 7. Spoke 502 Bad Gateway
**Status:** Fixed
**Root Cause:** Traefik router configured with wrong protocol and port + missing prefix stripping

**Changes:**
- Service `hubs-spoke`: `https://192.168.42.42:9099` → `http://192.168.42.42:9090`
- Added `spoke-strip` middleware with `prefixes: ["/spoke"]`
- Applied middleware to routers: `hubs-spoke-chemie`, `hubs-kits-chemie`, `hubs-uploads-chemie`
- Restarted Traefik container

### 8. Favicon.ico & App-Icon.png 404
**Status:** Fixed
**Root Cause:** Files referenced in app_configs DB table didn't exist, and were being served from DB lookup via `@configurable_assets`

**Fix:**
1. Generated icons from `logo.png` using ImageMagick:
   - `favicon.ico` with sizes 16, 24, 32, 48, 64px
   - `app-icon.png` (512x512)
   - `app-icon-192.png` (192x192)
   - `app-icon-512.png` (512x512)
2. Added static file routes in `page_controller.ex`:
   - Removed `favicon.ico`, `app-icon.png` from `@configurable_assets`
   - Added `render_for_path("/favicon.ico", ...)` using `render_static_asset()`
   - Added `render_for_path("/app-icon.png", ...)` using `render_static_asset()`
3. Added manifest metadata to `app_configs`:
   - `translations|en|app-name` = "Hubs Chemie"
   - `translations|en|app-full-name` = "Chemie Lernen Hubs"
   - `translations|en|app-description` = "Social VR in your browser"
   - `translations|en|app-tagline` = "Virtual collaboration spaces"
4. Rebuilt and restarted reticulum container

### 9. Disk Space Full
**Status:** Fixed
**Issue:** Docker system completely full (453/453G)
**Root Cause:** 239GB log file from old `opencloudeu/opencloud-rolling` container
**Fix:** Truncated log file, freed 216GB

### 10. Spoke Healthcheck Failing (HTTPS → HTTP mismatch)
**Status:** Fixed
**Root Cause:** Dockerfile healthcheck used `https://localhost:9090` but Spoke serves HTTP only
**Fix:** Changed `https://` → `http://` in `dockerfiles/spoke.Dockerfile`
**Result:** Container now shows `(healthy)` status

### 11. Hubs-Admin Healthcheck Failing (HTTPS → HTTP mismatch)
**Status:** Fixed
**Root Cause:** Webpack devServer configured for HTTPS but serving HTTP; docker-compose healthcheck used `https://localhost:8989/admin.html`
**Fix:** 
- `services/hubs/admin/webpack.config.js` - Changed `devServer.server.type` from `"https"` to `"http"`, removed `options: createHTTPSConfig()`
- `docker-compose.yml` - Changed healthcheck from `https://localhost:8989/admin.html` to `http://localhost:8989/admin.html`
**Result:** Container now shows `(healthy)` status after restart

### 11. Scene GLB Files Returning Wrong Content-Type (404 in Viewport)
**Status:** Fixed
**Root Cause:** 9 scene model files stored with `content_type: application/octet-stream` instead of `model/gltf-binary`. Three.js/A-Frame in the browser viewport fails to load models with wrong MIME type.
**Fix:** Updated `content_type` from `application/octet-stream` to `model/gltf-binary` in:
- `ret0.owned_files` DB table (9 rows)
- Corresponding `.meta.json` files on disk in `storage/dev/owned/`
**Verification:** `curl -I /files/*.glb` now returns `content-type: model/gltf-binary` for all scene models

---

## Monitoring

Prometheus and Grafana are already configured and running in the compose stack:
- ✅ Prometheus — healthy
- ✅ Grafana — healthy
- ✅ All containers expose metrics where applicable

---

## Remaining Pre-existing Issues (Low Impact)

| Issue | Status | Notes |
|---|---|---|
| CSP inline script warning | Pre-existing | `unsafe-inline` alongside hashes in CSP header |
| manifest.webmanifest favicon reference | Minor | References app-icon.png which now exists |

---

## Verification

All external URLs return correct responses:
- ✅ `https://hubs.chemie-lernen.org/` - HTTP 200, serves main page
- ✅ `https://hubs.chemie-lernen.org/spoke/` - HTTP 200, Spoke editor loads
- ✅ `https://hubs.chemie-lernen.org/favicon.ico` - HTTP 200
- ✅ `https://hubs.chemie-lernen.org/app-icon.png` - HTTP 200
- ✅ `https://hubs.chemie-lernen.org/manifest.webmanifest` - HTTP 200, proper metadata
- ✅ `https://hubs.chemie-lernen.org/api/v1/hubs` - HTTP 200
- ✅ Room creation (POST /api/v1/hubs) - Creates room successfully
- ✅ Dialog (WebRTC) - Running on port 4443
- ✅ Coturn (TURN) - Running on ports 50000-50050
- ✅ PostgREST - Connected to DB on port 3000
- ✅ Spoke container — healthy (was unhealthy due to HTTPS healthcheck mismatch)

---

## E2E Test Results

**Test:** Room Creation via API
```bash
curl -X POST https://hubs.chemie-lernen.org/api/v1/hubs \
  -H "Content-Type: application/json" \
  -d '{"hub":{"name":"E2E Test Room"}}'
```

**Result:** ✅ SUCCESS
- Room created: `krV9S4c/e2e-test-room`
- URL: https://hubs.chemie-lernen.org/krV9S4c/e2e-test-room
- Status: HTTP 200

---

## Files Modified

### Configuration Files
- `services/hubs/webpack.config.js`
- `services/reticulum/config/runtime.exs`
- `docker-compose.yml`
- `services/spoke/webpack.config.js`
- `/opt/git/docker-traefik/traefik.yml` (on 178.254.2.90)
- `services/spoke/src/.babelrc`
- `services/reticulum/lib/ret/application.ex`
- `dockerfiles/spoke.Dockerfile`

### Code Files
- `services/reticulum/lib/ret/*.ex` (multiple compile error fixes)
- `services/reticulum/lib/ret_web/controllers/page_controller.ex` (icon routes)

### Static Assets
- `services/reticulum/priv/static/favicon.ico` (new)
- `services/reticulum/priv/static/app-icon.png` (new)
- `services/reticulum/priv/static/app-icon-192.png` (new)
- `services/reticulum/priv/static/app-icon-512.png` (new)
