# Platform Docker

All Dockerfiles for the Cinema Microservices platform.

---

## Directory Structure

```
platform/docker/
├── devcontainer/          # VS Code DevContainer
│   └── Dockerfile         # Development environment image
├── e2e-runner/            # E2E test runner
│   └── Dockerfile         # Go test container
├── go-service/            # Service build template
│   └── Dockerfile         # Multi-stage build for all Go services
└── mongodb/               # MongoDB initialization
    ├── Dockerfile         # Replica set init + seeding
    └── seed/              # Database seed scripts
        ├── 01-init-replica.js
        ├── 02-create-databases.js
        ├── 03-create-indexes.js
        └── 04-seed-test-data.js
```

---

## Components

### Go Service Dockerfile

Centralized multi-stage build for all microservices:

```bash
# Build via Task
task build SERVICE=booking

# Or directly
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg SERVICE_PORT=8082 \
  -t cinema/booking:latest .
```

Features:
- Multi-stage build (builder + runtime)
- Non-root user for security
- Health check endpoint
- Build metadata labels

### DevContainer

Development environment for VS Code / Claude Code:

```bash
# Open in VS Code → "Reopen in Container"
# Or use Claude Code desktop with devcontainer support
```

Includes:
- Go 1.24
- Docker CLI + BuildX
- kubectl, Task, Spectral
- pact-go, go-junit-report
- MongoDB Shell

### MongoDB Init

Single Dockerfile supporting both dev and test environments:

```bash
# Environment variables:
# - MONGO_HOST: Primary MongoDB host
# - REPLICA_SET: Replica set name (default: rs0)
# - REPLICA_MEMBERS: Comma-separated members (empty = single node)
# - AUTH_ENABLED: Enable authentication (default: false)
```

Used by docker-compose profiles:
- `dev`: 3-node replica set (mongo1, mongo2, mongo3)
- `test`: Single node with tmpfs

### E2E Runner

Runs integration tests inside the Docker network:

```bash
# Used by test:e2e task
docker compose --profile test --profile e2e run --rm e2e-runner
```

---

## Docker Compose

The unified docker-compose is located at:
```
platform/deploy/docker-compose/docker-compose.yml
```

Available profiles:
| Profile | Description |
|---------|-------------|
| `dev` | 3 MongoDB replicas, persistent volumes |
| `test` | 1 MongoDB node, tmpfs (ephemeral) |
| `e2e` | E2E test runner container |

---

## Related

- [Docker Compose](../deploy/docker-compose/)
- [Development Guide](../../docs/development/README.md)
- [Taskfile.yml](../../Taskfile.yml)
