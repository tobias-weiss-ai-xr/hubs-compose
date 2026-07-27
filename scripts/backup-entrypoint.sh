#!/usr/bin/env bash
# Entrypoint script to run alongside main services for automated backups
# This runs as a sidecar container with cron

set -euo pipefail

# Source environment variables
: "${DB_HOST:?DB_HOST not set}"
: "${DB_PORT:?DB_PORT not set}"
: "${POSTGRES_DB:?POSTGRES_DB not set}"
: "${POSTGRES_USER:?POSTGRES_USER not set}"
: "${DB_CREDENTIALS:?DB_CREDENTIALS not set}"

BACKUP_DIR="/backups"
LOG_FILE="/var/log/backup.log"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR" /var/log

# Write crontab for daily backups at 2 AM
cat > /etc/crontab <<EOF
# Daily database backup at 2:00 AM
0 2 * * * /backup-db.sh --cleanup 7 >> /var/log/backup.log 2>&1
EOF

# Start cron in foreground
echo "Starting cron for database backups..."
echo "Backups will be stored in: $BACKUP_DIR"
echo "Logs available at: $LOG_FILE"

# Copy backup script to path
cp /scripts/backup-db.sh /backup-db.sh
chmod +x /backup-db.sh

# Run cron in foreground
exec cron -f
