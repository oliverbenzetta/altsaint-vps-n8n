# Container Name: N8N
# File Name: Makefile
# Description: Makefile for managing the N8N Docker service stack.
# Docker Internal Network: altsaint-net
# Version: 1.0.0
# Author: Alt Saint Group LTD

# SERVICE = n8n

# Makefile Targets, prevent conflicts with file names
.PHONY: up down update backup restore-postgres rebuild add-to-altsaint-net redis-shell first-install fix-perms

# Start the service in detached mode
up:
	# Build and start all containers in detached mode
	docker compose up -d

# Stop and remove containers, networks, and volumes
down:
	# Stop and remove all containers, networks and volumes created by compose
	docker compose down

# Update the service by pulling the latest code and images
update:
	# Pull the latest images from the registry and update the repository
	docker compose pull
	# Rebuild the containers with the latest code

# Create a backup of the database and Qdrant data
backup:
	# Call backup script that loads .env and runs pg_dump
	bash ./make-backup.sh

# Restore the database from a backup file
restore-postgres:
	# Call restore script that loads .env and runs pg_restore
	bash ./make-restore-postgres.sh

# Full rebuild: purge volumes, pull fresh images, rebuild from scratch, and start
rebuild:
	# Stop the entire stack and remove containers, networks, and volumes
	docker compose down --volumes

	# Pull the latest images from the registry
	docker compose pull

	# Rebuild all images without cache
	docker compose build --no-cache

	# Start the full stack in detached mode
	docker compose up -d

# Connect to Redis CLI
redis-shell:
	docker exec -it n8n-redis redis-cli

# Connect N8N container to the internal network
add-to-altsaint-net:
	# Get the N8N container ID from docker compose and connect it to the network
	# The double $$ ensures the shell, not make, evaluates the command substitution
	docker network connect altsaint-net $$(docker compose ps -q n8n) || true

# --- SPECIFIC TARGETS ---

# Perform initial deployment from scratch (creates directories, fixes permissions, and starts containers)
first-install:
	@echo "Creating required directories to prevent Root ownership issues..."
	mkdir -p ./service-data/postgres-data \
             ./service-data/qdrant-storage \
             ./service-data/qdrant-snapshots \
             ./service-data/redis-data \
             ./service-data/n8n-data \
             ./service-data/n8n-shared \
             ./service-data/backups
	make fix-perms
	@echo "Starting containers for the first time..."
	make up
	@echo "PROCESS COMPLETED! Access N8N once everything initializes."

# --- PERMISSIONS MANAGEMENT ---
# Fixes Permission denied errors
fix-perms:
	@echo "Fixing owners for user UID:$${UID:-1000}..."
	@if [ "$$(uname -s)" = "Linux" ]; then \
		chown -R $${UID:-1000}:$${GID:-1000} ./service-data || sudo chown -R $${UID:-1000}:$${GID:-1000} ./service-data; \
		chmod -R 755 ./service-data || sudo chmod -R 755 ./service-data; \
	else \
		echo "macOS detected (or non-Linux). Skipping aggressive chown. Docker Desktop handles ownership dynamically."; \
		chmod -R 755 ./service-data; \
	fi