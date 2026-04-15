# Container Name: N8N
# File Name: make-restore-postgres.sh
# Description: Script to restore the N8N PostgreSQL database from a backup.
# Docker Internal Network: altsaint-net
# Version: 1.0.0
# Author: Alt Saint Group LTD

#!/usr/bin/env bash

# Stop script on first error
# set -e

# Use strict error handling to prevent silent failures
set -euo pipefail

# Define backup directory
BACKUP_DIR="service-data/backups/n8n-postgres-backups"

# Define backup file (default postgres-latest.sql unless provided as argument)
RESTORE_FILE="${1:-postgres-latest.sql}"

# Full path to restore file
RESTORE_PATH="$BACKUP_DIR/$RESTORE_FILE"

# Ensure restore file exists
if [ ! -f "$RESTORE_PATH" ]; then
  echo "Restore file not found: $RESTORE_PATH"
  exit 1
fi

# Stopping the n8n app container before restoring
echo "Stopping n8n application container..."
docker compose stop n8n

# Drop and recreate the public schema inside the existing database
# Uses environment variables DB_USER and DB_NAME defined in the postgres service
echo "Dropping existing public schema in database..."
docker compose exec -T postgres sh -c '
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "DROP SCHEMA IF EXISTS public CASCADE;"
'
echo "Recreating public schema..."
docker compose exec -T postgres sh -c '
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -c "CREATE SCHEMA public AUTHORIZATION \"$DB_USER\";"
'
# Restore the database by feeding SQL into psql inside the container
echo "Restoring database from: $RESTORE_PATH"
docker compose exec -T postgres sh -c '
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1
' < "$RESTORE_PATH"

# Print simple summary
echo "Restore completed:"
echo "  - Source SQL: $RESTORE_PATH"

# Starting the n8n app container after restoring
echo "Starting n8n application container..."
docker compose start n8n
