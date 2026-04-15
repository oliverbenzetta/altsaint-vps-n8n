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

## Migrating credentials between instances

n8n stores credentials encrypted in PostgreSQL using an instance-specific
encryption key. The built-in CLI (`n8n export:credentials`) does not always work
reliably, so this stack uses a direct database approach: extract the encrypted
data from PostgreSQL, decrypt it with Node.js inside the n8n container, and
re-encrypt it with the destination instance's key before inserting.

All commands below use placeholder values. Replace them with your actual
container names, database credentials and encryption keys.

### Variables reference

| Variable | Description | Example |
| --- | --- | --- |
| `<N8N_SRC>` | Source n8n container | `altsaint-vps-n8n-production` |
| `<PG_SRC>` | Source PostgreSQL container | `altsaint-vps-n8n-production-postgres` |
| `<N8N_DST>` | Destination n8n container | `altsaint-vps-n8n-staging` |
| `<PG_DST>` | Destination PostgreSQL container | `altsaint-vps-n8n-staging-postgres` |
| `<DB_USER>` | PostgreSQL user | `root` |
| `<DB_NAME>` | PostgreSQL database | `n8n` |
| `<KEY_SRC>` | Source encryption key | _(from source config)_ |
| `<KEY_DST>` | Destination encryption key | _(from destination config)_ |
| `<PROJECT_ID>` | Destination personal project ID | _(from destination database)_ |

### Step 1 – Get the source encryption key

```bash
docker exec <N8N_SRC> cat /home/node/.n8n/config
```

Save the `encryptionKey` value.

### Step 2 – Extract encrypted credentials from PostgreSQL

```bash
docker exec <PG_SRC> psql -U <DB_USER> -d <DB_NAME> -t -A \
  -c "COPY (SELECT json_agg(json_build_object('id',id,'name',name,'type',type,'data',data)) FROM credentials_entity) TO '/tmp/creds.json';"
```

### Step 3 – Decrypt credentials

```bash
# Copy from postgres container to host, then to n8n container
docker cp <PG_SRC>:/tmp/creds.json /tmp/creds_encrypted.json
docker cp /tmp/creds_encrypted.json <N8N_SRC>:/tmp/creds_encrypted.json

# Decrypt and save to the shared folder
docker exec <N8N_SRC> node -e "
const crypto = require('crypto');
const fs = require('fs');

const ENCRYPTION_KEY = '<KEY_SRC>';

function decrypt(data) {
  const input = Buffer.from(data, 'base64');
  const salt = input.slice(8, 16);
  const ciphertext = input.slice(16);
  const password = Buffer.from(ENCRYPTION_KEY);
  let d = Buffer.alloc(0);
  let d_i = Buffer.alloc(0);
  while (d.length < 48) {
    d_i = crypto.createHash('md5').update(Buffer.concat([d_i, password, salt])).digest();
    d = Buffer.concat([d, d_i]);
  }
  const key = d.slice(0, 32);
  const iv = d.slice(32, 48);
  const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
  let decrypted = decipher.update(ciphertext, undefined, 'utf8');
  decrypted += decipher.final('utf8');
  return JSON.parse(decrypted);
}

const raw = JSON.parse(fs.readFileSync('/tmp/creds_encrypted.json', 'utf8'));
const creds = raw.map(r => ({
  id: r.id,
  name: r.name,
  type: r.type,
  data: decrypt(r.data)
}));
fs.writeFileSync('/files/credentials.json', JSON.stringify(creds, null, 2));
console.log('Exported ' + creds.length + ' credentials to /files/credentials.json');
"
```

The decrypted file is now at `./service-data/n8n-shared/credentials.json`.

### Step 4 – Clean up source temp files

```bash
rm /tmp/creds_encrypted.json
docker exec --user root <N8N_SRC> rm /tmp/creds_encrypted.json
docker exec --user root <PG_SRC> rm /tmp/creds.json
```

### Step 5 – Get the destination encryption key

```bash
docker exec <N8N_DST> cat /home/node/.n8n/config
```

### Step 6 – Get the destination user and project ID

The destination instance must have at least one registered user. If not, open
the n8n editor in a browser and create an account first.

```bash
docker exec <PG_DST> psql -U <DB_USER> -d <DB_NAME> -c "SELECT id, email FROM \"user\";"
docker exec <PG_DST> psql -U <DB_USER> -d <DB_NAME> -c "SELECT id, type FROM project WHERE type='personal';"
```

Save the project `id` value.

### Step 7 – Re-encrypt and generate import SQL

```bash
# Copy credentials.json to the destination n8n container
docker cp ./service-data/n8n-shared/credentials.json <N8N_DST>:/tmp/credentials.json

# Re-encrypt with the destination key and generate SQL
docker exec <N8N_DST> node -e "
const crypto = require('crypto');
const fs = require('fs');

const ENCRYPTION_KEY = '<KEY_DST>';

function encrypt(data) {
  const salt = crypto.randomBytes(8);
  const password = Buffer.from(ENCRYPTION_KEY);
  let d = Buffer.alloc(0);
  let d_i = Buffer.alloc(0);
  while (d.length < 48) {
    d_i = crypto.createHash('md5').update(Buffer.concat([d_i, password, salt])).digest();
    d = Buffer.concat([d, d_i]);
  }
  const key = d.slice(0, 32);
  const iv = d.slice(32, 48);
  const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);
  let encrypted = cipher.update(JSON.stringify(data), 'utf8');
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return Buffer.concat([Buffer.from('Salted__'), salt, encrypted]).toString('base64');
}

const creds = JSON.parse(fs.readFileSync('/tmp/credentials.json', 'utf8'));
let sql = '';
creds.forEach(c => {
  const encData = encrypt(c.data);
  sql += \"INSERT INTO credentials_entity (id, name, type, data, \\\"createdAt\\\", \\\"updatedAt\\\") VALUES ('\"+c.id.replace(/'/g,\"''\")+\"', '\"+c.name.replace(/'/g,\"''\")+\"', '\"+c.type.replace(/'/g,\"''\")+\"', '\"+encData+\"', NOW(), NOW()) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data, \\\"updatedAt\\\" = NOW();\\n\";
});
fs.writeFileSync('/files/import.sql', sql);
console.log('Generated SQL for ' + creds.length + ' credentials');
"
```

### Step 8 – Import into PostgreSQL

```bash
docker cp ./service-data/n8n-shared/import.sql <PG_DST>:/tmp/import.sql
docker exec <PG_DST> psql -U <DB_USER> -d <DB_NAME> -f /tmp/import.sql
```

### Step 9 – Link credentials to the user

```bash
docker exec <PG_DST> psql -U <DB_USER> -d <DB_NAME> -c "
INSERT INTO shared_credentials (\"credentialsId\", \"projectId\", role)
SELECT id, '<PROJECT_ID>', 'credential:owner'
FROM credentials_entity
ON CONFLICT DO NOTHING;
"
```

### Step 10 – Restart and clean up

```bash
docker restart <N8N_DST>
docker exec --user root <N8N_DST> rm /tmp/credentials.json
docker exec --user root <PG_DST> rm /tmp/import.sql
rm ./service-data/n8n-shared/credentials.json
rm ./service-data/n8n-shared/import.sql
```

### Importing workflows

Workflows can be imported using the n8n CLI. Place the export file in the shared
folder and run:

```bash
docker exec <N8N_DST> n8n import:workflow --input=/files/workflows.json
```

Workflows are imported in a deactivated state. Review and activate them manually
from the editor.

> **Note:** The destination instance must have at least one registered user
> before importing workflows, otherwise the import will fail with a foreign key
> error.

### Security considerations

- The decrypted `credentials.json` file contains passwords, tokens and API keys
  in plain text. Delete it immediately after completing the import.
- Never commit credential files to Git or leave them in publicly accessible
  paths.
- OAuth2 credentials (such as Gmail or Google Drive) may require manual
  re-authorization in the destination instance.

### Troubleshooting

| Problem | Solution |
| --- | --- |
| `No credentials found` with n8n CLI | Use the direct PostgreSQL method described above. |
| `Cannot find module 'pg'` | Do not use the `pg` module from Node.js inside the n8n container. Extract data with `psql` from the PostgreSQL container instead. |
| `Operation not permitted` when deleting `/tmp` files | Use `docker exec --user root`. |
| `Invalid initialization vector` | The encryption format is CryptoJS (base64 with `Salted__` prefix), not hex IV. Use the decrypt function from this guide. |
| Credentials visible but "could not be found" | Run the `shared_credentials` insert from Step 9 to link them to the user's project. |
| Workflow import fails with foreign key error | Create a user account in the destination instance before importing. |

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