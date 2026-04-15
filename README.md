# n8n with PostgreSQL and Qdrant
Docker-based self-hosted automation stack

This repository provides a production-ready containerized deployment of n8n with
PostgreSQL and Qdrant. All persistent data is stored inside the `service-data`
directory, keeping the stack portable across machines and easy to back up or
restore .

## Structure

- **docker-compose.yml**  
  Defines the full service stack:
    - `postgres` – PostgreSQL 16 used by n8n for workflow and metadata storage.
    - `qdrant` – Vector database used for semantic search and embeddings.
    - `n8n` – The main n8n automation application, configured using `.env`.

  All services communicate through the internal Docker network `altsaint-net`
  and persist their volumes inside `service-data/*`.

- **Makefile**  
  Provides helper commands for managing the stack:
    - `make up` – Start all containers in detached mode.
    - `make down` – Stop and remove the stack.
    - `make update` – Pull the latest images from Docker Hub.
    - `make backup` – Create PostgreSQL dumps and back up Qdrant data.
    - `make restore-postgres` – Restore PostgreSQL from a dump.
    - `make rebuild` – Full rebuild: purge volumes, pull fresh images and start from scratch.

- **.env**  
  Contains all environment variables required by the stack (n8n, PostgreSQL and Qdrant).
  This file should never be committed. Use `.env.example` as a template.

- **service-data/**  
  Holds all persistent service volumes:
    - `postgres-data/` – PostgreSQL storage.
    - `qdrant-storage/` – Qdrant storage.
    - `qdrant-snapshots/` – Qdrant snapshot storage.
    - `n8n-data/` – n8n configuration and workflow data.
    - `n8n-shared/` – Shared folder used by n8n.
    - `backups/` – PostgreSQL dump files and optional Qdrant backups.

## Usage

1. Review and edit your `.env` file to configure:
   - n8n host, domain and protocol
   - PostgreSQL credentials
   - Qdrant settings
   - Timezone configuration

2. Ensure the internal Docker network exists (only once):
   ```
   docker network create altsaint-net
   ```

3. Start the stack:
   ```
   make up
   ```

4. Access n8n through the host/protocol you set in `.env`.

5. Stop and remove all containers:
   ```
   make down
   ```

6. Pull the latest images:
   ```
   make update
   ```

7. Create backups (PostgreSQL dump + Qdrant directories):
   ```
   make backup
   ```

8. Restore the PostgreSQL database:
   ```
   make restore-postgres
   ```

9. Full rebuild:
   ```
   make rebuild
   ```

## Running an additional instance

To run a second instance of this stack on the same Docker host, use a separate
copy of this repository or a separate deployment directory. This keeps each
instance's `service-data/` directory isolated.

Before starting the new instance, update its `.env` file:

1. Set a unique project name:
   ```
   COMPOSE_PROJECT_NAME=n8n-staging
   ```

   Use a different value for each instance, for example `n8n-production`,
   `n8n-staging`, or `n8n-client-a`. This value is used to generate container
   names such as `${COMPOSE_PROJECT_NAME}-postgres`,
   `${COMPOSE_PROJECT_NAME}-qdrant`, `${COMPOSE_PROJECT_NAME}-redis`, and
   `${COMPOSE_PROJECT_NAME}-mcp`.

2. Set unique host ports for every service published to the Docker host:
   ```
   N8N_IP_HOST_PORT=5679
   DB_EXTERNAL_PORT=5433
   QDRANT_HOST_PORT=6334
   MCP_PORT=3001
   ```

   These variables must not reuse ports already published by another running
   instance. The internal container ports stay the same; only the host-side
   ports need to change.

3. If the n8n instance is accessed directly through one of these host ports,
   update the public URLs to match the selected `N8N_IP_HOST_PORT`:
   ```
   N8N_EDITOR_BASE_URL=http://your-hostname:5679
   N8N_API_BASE_URL=http://your-hostname:5679
   WEBHOOK_URL=http://your-hostname:5679/
   ```

   If the instance is behind a reverse proxy, keep these URLs aligned with the
   domain and protocol exposed by the proxy.

After updating `.env`, start the new instance from its own directory:

```
make up
```

## Notes

- Qdrant is only exposed inside the internal network unless port mappings are modified.
- If you need custom n8n modules or nodes, you can extend the stack by adding a
  custom `Dockerfile` and enabling a `build` block in `docker-compose.yml`.
- The `service-data` directory is intentionally ignored by Git (except for `.gitkeep`)
  to prevent committing large or sensitive data.
