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

## Managing multiple instances

This stack supports multiple n8n instances on the same Docker host, such as
`n8n-production`, `n8n-staging`, and `n8n-custom`.

Use a separate copy of this repository or a separate deployment directory for
each instance. This keeps each instance's `.env` file and `service-data/`
directory isolated.

Each instance must have:

- A unique `COMPOSE_PROJECT_NAME`.
- A unique set of host ports.
- Its own public URLs or tunnel routes.

Recommended host port allocation:

| Instance | `COMPOSE_PROJECT_NAME` | `N8N_IP_HOST_PORT` | `DB_EXTERNAL_PORT` | `QDRANT_HOST_PORT` | `MCP_PORT` |
| --- | --- | ---: | ---: | ---: | ---: |
| Production | `n8n-production` | `5678` | `5432` | `6333` | `3000` |
| Staging | `n8n-staging` | `5679` | `5434` | `6334` | `3001` |
| Custom | `n8n-custom` | `5680` | `5435` | `6335` | `3002` |

Example `.env` values for staging:

```
COMPOSE_PROJECT_NAME=n8n-staging
N8N_IP_HOST_PORT=5679
DB_EXTERNAL_PORT=5434
QDRANT_HOST_PORT=6334
MCP_PORT=3001
```

Example `.env` values for a custom instance:

```
COMPOSE_PROJECT_NAME=n8n-custom
N8N_IP_HOST_PORT=5680
DB_EXTERNAL_PORT=5435
QDRANT_HOST_PORT=6335
MCP_PORT=3002
```

The container ports stay the same across all instances:

| Service | Internal container port |
| --- | ---: |
| n8n | `5678` |
| PostgreSQL | `5432` |
| Qdrant | `6333` |
| n8n MCP | `3000` |

Only the host-side ports must change between instances.

If an instance is behind a reverse proxy or Docker tunnel, keep these URLs
aligned with the domain and protocol exposed publicly:

```
N8N_EDITOR_BASE_URL=https://n8n-staging.altsaint.com
N8N_API_BASE_URL=https://n8n-staging.altsaint.com
WEBHOOK_URL=https://n8n-staging.altsaint.com/
```

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
