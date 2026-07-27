#!/usr/bin/env bash
# PostgreSQL Database Backup Script for hubs-compose
# Usage: ./backup-db.sh [--cleanup N] [--quiet]
#   --cleanup N   Keep only last N backups (default: 7)
#   --quiet      Suppress output
#   --test       Test connection without creating backup

set -euo pipefail

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-reticulum}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASSWORD="${DB_CREDENTIALS:-postgres}"
BACKUP_DIR="${BACKUP_DIR:-/var/hubs-compose/backups}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"
KEEP_DAYS=${KEEP_DAYS:-7}

# Parse arguments
CLEANUP=0
QUIET=false
TEST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cleanup)
      CLEANUP="$2"
      shift 2
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --test)
      TEST=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Log function
log() {
  if [ "$QUIET" = false ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
  fi
}

# Test database connection
test_connection() {
  if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1" &>/dev/null; then
    log "✅ Database connection successful"
    return 0
  else
    log "❌ Database connection failed"
    return 1
  fi
}

# Create backup
create_backup() {
  log "🔄 Starting backup of $DB_NAME to $BACKUP_FILE"
  
  if PGPASSWORD="$DB_PASSWORD" pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"; then
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "✅ Backup created: $BACKUP_FILE ($SIZE)"
    
    # Verify backup
    if gzip -t "$BACKUP_FILE" 2>/dev/null; then
      log "✅ Backup integrity verified"
    else
      log "❌ Backup integrity check failed"
      rm -f "$BACKUP_FILE"
      return 1
    fi
    return 0
  else
    log "❌ Backup failed"
    return 1
  fi
}

# Cleanup old backups
cleanup_backups() {
  local keep=${1:-$KEEP_DAYS}
  log "🧹 Cleaning up backups older than $keep days"
  
  # Delete backups older than KEEP_DAYS
  find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"$keep" -delete 2>/dev/null
  
  # Also enforce max count if CLEANUP is set
  if [ "$CLEANUP" -gt 0 ] 2>/dev/null; then
    (cd "$BACKUP_DIR" && ls -t ${DB_NAME}_*.sql.gz | tail -n +$((CLEANUP + 1)) | xargs rm -f 2>/dev/null)
    log "🧹 Kept last $CLEANUP backups"
  fi
}

# Main
main() {
  if [ "$TEST" = true ]; then
    if test_connection; then
      log "✅ Connection test passed"
      exit 0
    else
      exit 1
    fi
  fi

  if ! test_connection; then
    exit 1
  fi

  if ! create_backup; then
    exit 1
  fi

  # Always cleanup
  cleanup_backups "$KEEP_DAYS"
  
  log "✅ Backup completed successfully"
}

main "$@"
