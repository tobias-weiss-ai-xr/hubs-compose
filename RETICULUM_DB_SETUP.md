# Reticulum Database Initialization

This document explains how the Reticulum database is initialized and how to work with it.

## Overview

Reticulum requires a PostgreSQL database named `ret_dev` with a proper schema to function. The docker-compose setup automatically initializes this database on first container startup.

## How Database Initialization Works

### Step 1: PostgreSQL Container Startup

When the `db` service starts, PostgreSQL looks for initialization scripts in `/docker-entrypoint-initdb.d/` and executes them in alphabetical order.

### Step 2: Automatic Database Creation

The file `db-init/reticulum-init.sql` is automatically executed, which:
- Creates the `ret_dev` database
- Sets up required PostgreSQL extensions (uuid-ossp, citext)
- Creates schema tracking tables for Ecto migrations
- Grants proper permissions to the postgres user

### Step 3: Reticulum Migrations (Manual)

Once the database exists, the Reticulum service will run additional schema migrations when it starts. These are defined in the Reticulum codebase.

## Initial Setup

### First Time Running

1. **Start the database service:**
   ```bash
   cd /opt/git/hubs-compose
   docker compose up -d db
   ```

2. **Wait for PostgreSQL to initialize:**
   ```bash
   docker compose logs db --follow
   # Watch for: "PostgreSQL init process complete" or "ready to accept connections"
   ```

3. **Verify the ret_dev database exists:**
   ```bash
   docker compose exec db psql -U postgres -l
   ```
   
   You should see `ret_dev` in the database list.

4. **Start remaining services:**
   ```bash
   docker compose up -d
   ```

### After First Startup

If services are already running and you need to reinitialize:

```bash
# WARNING: This will delete all data in the ret_dev database
docker compose down
docker volume rm hubs-compose_pgdata
docker compose up -d
```

## Manual Database Operations

### Connect to ret_dev Database

```bash
# Using docker compose
docker compose exec db psql -U postgres -d ret_dev

# Or directly
psql -h localhost -U postgres -d ret_dev
```

### Check Database Structure

```bash
docker compose exec db psql -U postgres -d ret_dev -c "\dt"
```

This lists all tables created by Ecto migrations.

### Troubleshooting

#### "database ret_dev does not exist"

If you see this error in postgrest or reticulum logs:

1. **Check if database was created:**
   ```bash
   docker compose exec db psql -U postgres -l | grep ret_dev
   ```

2. **If missing, manually create it:**
   ```bash
   docker compose exec db psql -U postgres -c "CREATE DATABASE ret_dev;"
   docker compose exec db psql -U postgres -d ret_dev -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
   docker compose exec db psql -U postgres -d ret_dev -c "CREATE EXTENSION IF NOT EXISTS \"citext\";"
   ```

3. **Restart dependent services:**
   ```bash
   docker compose restart postgrest reticulum
   ```

#### Database Connection Refused

If `db` container is not responding:

```bash
# Check if db is running
docker compose ps db

# Check logs
docker compose logs db --tail 50

# Restart the database
docker compose restart db
```

## Viewing Database Details

### List all databases:
```bash
docker compose exec db psql -U postgres -l
```

### Show table structure:
```bash
docker compose exec db psql -U postgres -d ret_dev -c "\d+"
```

### Check schema migrations:
```bash
docker compose exec db psql -U postgres -d ret_dev -c "SELECT * FROM schema_migrations ORDER BY version;"
```

### View table sizes:
```bash
docker compose exec db psql -U postgres -d ret_dev -c "
  SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

## PostgreSQL Credentials

| Property | Value |
|----------|-------|
| Host | db (or localhost from host) |
| Port | 5432 |
| User | postgres |
| Password | postgres |
| Database | ret_dev |
| Superuser | postgres |

## Import Existing Database Backup

If you have an existing `ret_dev` database dump and want to import it:

### From SQL dump file:

```bash
# Copy the dump file into the db init directory
cp /path/to/backup.sql /opt/git/hubs-compose/db-init/99-restore-backup.sql

# Restart the db service
docker compose restart db

# Watch initialization
docker compose logs db --follow
```

The `99-` prefix ensures this script runs after the base initialization.

### Backup current database:

```bash
docker compose exec db pg_dump -U postgres ret_dev > /opt/git/hubs-compose/backups/ret_dev-$(date +%Y%m%d-%H%M%S).sql
```

## Related Services

- **postgrest**: REST API layer that connects to ret_dev
- **reticulum**: Hubs backend service that manages rooms and users in ret_dev
- **db**: PostgreSQL container housing ret_dev

## See Also

- [Reticulum GitHub Repository](https://github.com/Hubs-Foundation/reticulum)
- [PostgreSQL Docker Documentation](https://hub.docker.com/_/postgres)
- [Ecto Database Migrations](https://hexdocs.pm/ecto/Ecto.Migration.html)
