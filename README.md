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

## Notes

- Qdrant is only exposed inside the internal network unless port mappings are modified.
- If you need custom n8n modules or nodes, you can extend the stack by adding a
  custom `Dockerfile` and enabling a `build` block in `docker-compose.yml`.
- The `service-data` directory is intentionally ignored by Git (except for `.gitkeep`)
  to prevent committing large or sensitive data.