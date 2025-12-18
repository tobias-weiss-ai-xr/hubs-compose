# Hugo Multi-Site Configuration

This repository hosts multiple Hugo-based websites through a single HAProxy reverse proxy with SSL termination.

## Architecture

```
Internet (HTTPS)
    ↓
HAProxy (SSL Termination)
    ↓
Multiple Hugo Containers (HTTP internally)
```

## Hosted Sites

### 1. **Chemie Lernen** - https://chemie-lernen.org
- **Directory**: `hugo-chemie-lernen-org/`
- **Port**: 1313
- **Theme**: Ananke
- **Language**: German (de-de)
- **Content**: Chemistry education platform with interactive periodic table using Three.js
- **Features**:
  - 3D periodic table visualization (CDN-based Three.js v0.170.0)
  - Research articles on VR-based chemistry education
  - German language interface

### 2. **GraphWiz AI** - https://graphwiz.ai
- **Directory**: `hugo-graphwiz-ai/`
- **Port**: 1314
- **Theme**: tobi-goa
- **Language**: English (en-US)
- **Content**: AI & XR consulting platform
- **Sections**:
  - Artificial Intelligence
  - eXtended Reality (XR)
  - Operations
  - Workshops
- **Features**:
  - IT consulting services
  - AI/XR enthusiasm and projects
  - Social media integration (GitHub, LinkedIn)

### 3. **Tobias Weiss** - https://next.tobias-weiss.org
- **Directory**: `hugo-next-tobias-weiss-org/`
- **Port**: 1315
- **Theme**: tobi-goa
- **Language**: English (en-US)
- **Content**: Personal homepage
- **Sections**:
  - Photo Gallery
  - PGP/GPG Keys
- **Features**:
  - Minimal personal portfolio
  - Creative Commons BY 3.0 licensed
  - Contact information

## Configuration Files

### Docker Compose
**File**: `docker-compose.test.yml`

Each Hugo site runs in its own Docker container:

```yaml
hugo-chemie:
  build: ./hugo-chemie-lernen-org
  command: hugo server --bind 0.0.0.0 --baseURL https://chemie-lernen.org --appendPort=false
  ports:
    - "1313:1313"

hugo-graphwiz:
  build: ./hugo-graphwiz-ai
  command: hugo server --bind 0.0.0.0 --baseURL https://graphwiz.ai --appendPort=false
  ports:
    - "1314:1313"

hugo-tobias:
  build: ./hugo-next-tobias-weiss-org
  command: hugo server --bind 0.0.0.0 --baseURL https://next.tobias-weiss.org --appendPort=false
  ports:
    - "1315:1313"
```

### HAProxy Configuration
**File**: `haproxy/haproxy.cfg`

```
frontend https
    bind *:443 ssl crt /etc/haproxy/certs/

    # Domain routing
    acl is_chemie hdr(host) -i chemie-lernen.org
    acl is_graphwiz hdr(host) -i graphwiz.ai
    acl is_tobias hdr(host) -i next.tobias-weiss.org

    # Backend selection
    use_backend hugo-chemie if is_chemie
    use_backend hugo-graphwiz if is_graphwiz
    use_backend hugo-tobias if is_tobias

backend hugo-chemie
    server hugo-chemie hugo-chemie:1313

backend hugo-graphwiz
    server hugo-graphwiz hugo-graphwiz:1313

backend hugo-tobias
    server hugo-tobias hugo-tobias:1313
```

## SSL/TLS Configuration

- **Frontend**: HTTPS (port 443) with Let's Encrypt certificates
- **Backend**: Plain HTTP (internal Docker network)
- **HTTP to HTTPS**: Automatic 301 redirect on port 80
- **HSTS**: Enabled with max-age=16000000

### Certificates
Managed by `docker-haproxy-certbot`:
- chemie-lernen.org
- graphwiz.ai
- next.tobias-weiss.org

## Directory Structure

```
/opt/git/hubs-compose/
├── hugo-chemie-lernen-org/
│   └── myhugoapp/
│       ├── config.toml
│       ├── content/
│       ├── layouts/
│       ├── static/
│       └── themes/ananke/
├── hugo-graphwiz-ai/
│   └── myhugoapp/
│       ├── config.toml
│       ├── content/
│       │   ├── ai/
│       │   ├── xr/
│       │   ├── ops/
│       │   └── workshops/
│       ├── static/
│       └── themes/tobi-goa/
├── hugo-next-tobias-weiss-org/
│   └── myhugoapp/
│       ├── config.toml
│       ├── content/
│       │   ├── gallery/
│       │   └── pgp/
│       ├── static/
│       └── themes/tobi-goa/
├── docker-compose.test.yml
├── haproxy/
│   └── haproxy.cfg
└── HUGO_SITES.md (this file)
```

## Management Commands

### Restart All Services
```bash
sudo systemctl restart hubs-compose.service
```

### Restart Individual Hugo Container
```bash
docker restart hubs-compose_hugo-chemie_1
docker restart hubs-compose_hugo-graphwiz_1
docker restart hubs-compose_hugo-tobias_1
```

### View Logs
```bash
docker logs hubs-compose_hugo-chemie_1
docker logs hubs-compose_hugo-graphwiz_1
docker logs hubs-compose_hugo-tobias_1
```

### Check Container Status
```bash
docker ps | grep hugo
```

## Testing Endpoints

### Local Testing (from server)
```bash
curl -I -k -H "Host: chemie-lernen.org" https://178.254.2.90/
curl -I -k -H "Host: graphwiz.ai" https://178.254.2.90/
curl -I -k -H "Host: next.tobias-weiss.org" https://178.254.2.90/
```

### Public URLs
- https://chemie-lernen.org
- https://graphwiz.ai
- https://next.tobias-weiss.org

## Adding a New Hugo Site

1. **Create new directory**:
   ```bash
   cp -r hugo-graphwiz-ai hugo-new-site
   ```

2. **Update config.toml**:
   ```toml
   baseURL = "https://new-site.com/"
   title = "New Site"
   ```

3. **Add to docker-compose.test.yml**:
   ```yaml
   hugo-newsite:
     build: ./hugo-new-site
     command: hugo server --bind 0.0.0.0 --baseURL https://new-site.com --appendPort=false
     working_dir: /app/myhugoapp
     volumes:
       - ./hugo-new-site/myhugoapp:/app/myhugoapp
       - ./hugo-new-site/public:/app/myhugoapp/public
     ports:
       - "1316:1313"
   ```

4. **Add to haproxy.cfg**:
   ```
   acl is_newsite hdr(host) -i new-site.com
   use_backend hugo-newsite if is_newsite

   backend hugo-newsite
       server hugo-newsite hugo-newsite:1313 resolvers docker resolve-prefer ipv4
   ```

5. **Update playwright-tests dependencies** in docker-compose.test.yml

6. **Restart services**:
   ```bash
   sudo systemctl restart hubs-compose.service
   ```

## Troubleshooting

### Site Not Loading
1. Check container is running: `docker ps | grep hugo`
2. Check logs: `docker logs hubs-compose_hugo-X_1`
3. Verify HAProxy routing: Check `haproxy/haproxy.cfg`
4. Test backend directly: `curl http://localhost:131X`

### SSL Certificate Issues
1. Check certificate renewal: `docker logs haproxy`
2. Verify cert files: `docker exec haproxy ls -la /etc/haproxy/certs/`
3. Force renewal: See haproxy-certbot documentation

### Content Not Updating
1. Hugo uses live reload - changes should appear immediately
2. If not, restart the specific Hugo container
3. Check file permissions in volume mounts
4. Clear browser cache (Ctrl+Shift+R)

## Performance Optimization

- Hugo builds are served from memory (dev mode)
- Static assets are served directly by Hugo
- HAProxy handles SSL termination efficiently
- Each site runs independently - no cross-site interference

## Security Notes

- All HTTP traffic redirected to HTTPS (301)
- HSTS headers enabled
- Let's Encrypt auto-renewal configured
- Backend containers not exposed to internet
- Internal Docker network for container communication

## Maintenance

### Regular Tasks
- Monitor disk space for Hugo content
- Review HAProxy logs for errors
- Check SSL certificate expiration
- Update Hugo themes periodically

### Backup Strategy
- Git repository contains all source content
- Themes are version-controlled
- SSL certificates managed by Let's Encrypt (auto-renewal)
- Docker volumes for runtime data

---

**Last Updated**: 2025-12-18
**Maintained By**: GraphWiz AI
