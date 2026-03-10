# Container Name: N8N
# File Name: make-backup.sh
# Description: Script to create a backup of the N8N PostgreSQL database and Qdrant data.
# Docker Internal Network: altsaint-net
# Version: 1.0.0
# Author: Alt Saint Group LTD

#!/usr/bin/env bash

# Stop script on first error
# set -e

# Use strict error handling to prevent silent failures
set -euo pipefail

# Define backup directory and timestamp
BACKUP_DIR="service-data/backups"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"/n8n-postgres-backups

# Dump Postgres database from inside the container
# The script uses the standard PostgreSQL environment variables (DB_USER, DB_NAME)
# which are set in the n8n-postgres container via the .env file
docker exec n8n-postgres sh -c 'pg_dump -U "$DB_USER" "$DB_NAME"' \
  > "$BACKUP_DIR/n8n-postgres-backups/postgres-$TIMESTAMP.sql"

# Save the Postgres dump without timestamp for easy access
cp "$BACKUP_DIR/n8n-postgres-backups/postgres-$TIMESTAMP.sql" "$BACKUP_DIR/n8n-postgres-backups/postgres-latest.sql"

# Remove and Copy Qdrant storage directory
rm -rf "$BACKUP_DIR/qdrant-storage-latest"
cp -R service-data/qdrant-storage \
  "$BACKUP_DIR/qdrant-storage-latest"

# Remove and Copy Qdrant snapshots director
rm -rf "$BACKUP_DIR/qdrant-snapshots-latest"
cp -R service-data/qdrant-snapshots \
  "$BACKUP_DIR/qdrant-snapshots-latest"

# Remove and Copy n8n data directory
rm -rf "$BACKUP_DIR/n8n-data-latest"
cp -R service-data/n8n-data \
  "$BACKUP_DIR/n8n-data-latest"

# Print simple summary
echo "Backup done:"
echo "  - Postgres:  $BACKUP_DIR/n8n-postgres-backups/postgres-$TIMESTAMP.sql"
echo "  - Qdrant storage:   $BACKUP_DIR/qdrant-storage-latest"
echo "  - Qdrant snapshots: $BACKUP_DIR/qdrant-snapshots-latest"