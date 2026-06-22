# Setup Guide

## Prerequisites

- **Docker** (Engine 24+) and **Docker Compose** (v2.20+)
  - [Install Docker](https://docs.docker.com/engine/install/)
  - Verify: `docker compose version`
- **Mutagen** v0.17+ and **Mutagen Compose** (matching versions)
  - [Install Mutagen](https://mutagen.io/documentation/introduction/installation)
  - `mutagen version` should match `mutagen-compose version`

## Step-by-Step Setup

### 1. Hosts Entries

Add to your `/etc/hosts` file:
```
127.0.0.1   hubs.local hubs-proxy.local
```

### 2. Clone & Environment

```bash
git clone git@codeberg.org:graphwiz-ai/hubs-compose.git
cd hubs-compose
cp .env.example .env
# Edit .env with your secrets (SMTP, DB, etc.)
```

Key settings in `.env`:
```bash
HUBS_HOST=hubs.tobias-weiss.org     # Your public hostname
DB_CREDENTIALS=your_secure_password # Change this!
MEDIASOUP_ANNOUNCED_IP=your_ip      # For WebRTC behind NAT
```

### 3. Start Services

```bash
# Start all services
docker compose up --build -d

# Monitor startup
docker compose logs -f
```

**Wait times:**
- Reticulum, Dialog, DB, Coturn: ~30s
- Hubs Client (webpack build): ~3m30s (first time)
- Hubs Admin: ~2m

### 4. Accept TLS Certificates

The stack uses self-signed dev certificates. Visit each URL in your browser
and accept the security warning:

- https://hubs.local:4001 — Reticulum API
- https://hubs.local:8081 — Hubs Client
- https://hubs.local:4443 — Dialog
- https://hubs.local:8989 — Hubs Admin
- https://hubs.local:9091 — Spoke
- https://hubs.local:5349 — Coturn (TLS, browser may not accept)

### 5. Verify Everything is Healthy

```bash
# All containers should show "(healthy)"
docker ps

# Check reticulum health endpoint
curl -sk https://hubs.local:4001/health

# Run test suite
docker exec hubs-compose-reticulum-1 mix test
```

## Common Operations

### Rebuild a Single Service
```bash
docker compose build reticulum
docker compose up -d reticulum
```

### View Logs
```bash
docker compose logs -f reticulum   # Follow reticulum logs
docker compose logs dialog         # Show dialog logs
```

### Run Mix Commands (Reticulum)
```bash
docker exec hubs-compose-reticulum-1 mix deps.get
docker exec hubs-compose-reticulum-1 mix ecto.migrate
docker exec hubs-compose-reticulum-1 mix test
```

### Run E2E Tests
```bash
cd e2e
npx playwright test --reporter=list
```

### Stop Everything
```bash
docker compose down
# To also remove volumes (reset state):
docker compose down -v
```

## Troubleshooting

### Container Shows "unhealthy"
Check logs:
```bash
docker compose logs <service-name>
```

**Common causes:**
- **hubs-client**: Webpack still building (wait 3m30s)
- **reticulum**: DB not ready, port conflict (port 4000 taken?)
- **coturn**: DB connection failed (wait for DB to be ready first)

### "APP is not defined" in Hubs console
Ensure `/etc/hosts` has `hubs.local`. The webpack config expects
`hubs.local:4001` for API calls.

### Port Conflicts
Default ports conflict with these common services:
- 4000: litellm-proxy (use 4001)
- 443: HTTPS proxy (use 4443 for dialog)
- 5432: Local PostgreSQL (change `docker-compose.yml` or stop local PG)

### Mutagen Sync Issues
```bash
# Check sync sessions
mutagen sync list

# Force re-sync
mutagen sync terminate <session-name>
docker compose up -d
```
