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

Centralized multi-stage build supporting both local development and CI pipelines:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DOCKERFILE STAGES                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ARG BINARY_SOURCE = builder (default) | prebuilt                      │
│                                                                         │
│  ┌─────────────────┐       ┌─────────────────┐                         │
│  │     builder     │       │    prebuilt     │                         │
│  │  (compile src)  │       │ (copy binary)   │                         │
│  │                 │       │                 │                         │
│  │  golang:alpine  │       │     scratch     │                         │
│  │  go build → /app│       │  COPY bin → /app│                         │
│  └────────┬────────┘       └────────┬────────┘                         │
│           │                         │                                   │
│           └────────────┬────────────┘                                   │
│                        │                                                │
│                        ▼                                                │
│               ┌─────────────────┐                                       │
│               │     runtime     │                                       │
│               │                 │                                       │
│               │  alpine:3.21    │                                       │
│               │  COPY --from=   │                                       │
│               │  ${BINARY_SRC}  │                                       │
│               └─────────────────┘                                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

#### Usage: Local Development

Compiles Go code inside Docker (self-contained):

```bash
# Via Task (recommended)
task build SERVICE=booking

# Direct docker build
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg SERVICE_PORT=8001 \
  -t cinema/booking:latest .
```

#### Usage: CI Pipeline (Harness)

Uses pre-compiled binary for faster builds with Cache Intelligence:

```bash
# Step 1: Build binary (benefits from Go module cache)
cd services/booking
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o booking ./cmd/booking

# Step 2: Build image (just copies binary, very fast)
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg SERVICE_PORT=8001 \
  --build-arg BINARY_SOURCE=prebuilt \
  -t cinema/booking:latest .
```

#### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `SERVICE_NAME` | (required) | Service name (e.g., booking, movie) |
| `SERVICE_PORT` | 8000 | Port to expose |
| `VERSION` | 0.0.0-dev | Semantic version |
| `COMMIT_SHA` | unknown | Git commit SHA |
| `BUILD_DATE` | unknown | ISO8601 build timestamp |
| `BINARY_SOURCE` | builder | `builder` (compile) or `prebuilt` (copy) |
| `GO_VERSION` | 1.24 | Go version for builder stage |
| `ALPINE_VERSION` | 3.21 | Alpine version for runtime |

#### Features

- **Dual-mode build**: Same Dockerfile for local and CI
- **Multi-stage**: Minimal runtime image (~10MB)
- **Non-root user**: Runs as `appuser:appgroup` (UID 1000)
- **Health check**: Built-in `/health/live` endpoint check
- **OCI labels**: Standard image metadata
- **Cache optimized**: Separate layers for deps vs source

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

## CI/CD Integration

The Go service Dockerfile is optimized for Harness CI:

| Feature | Local | CI Pipeline |
|---------|-------|-------------|
| **BINARY_SOURCE** | `builder` (default) | `prebuilt` |
| **Go module cache** | Docker layer cache | Harness Cache Intelligence |
| **Build speed** | ~30-60s | ~5-10s (cache hit) |
| **Context required** | Full repo | Full repo |

### CI Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Harness CI Pipeline                                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Build Binary Step (golang image)                                   │
│     └─ Uses Cache Intelligence for /harness/.go (GOPATH)               │
│     └─ Output: services/<service>/<service> binary                     │
│                                                                         │
│  2. BuildAndPushDockerRegistry Step                                    │
│     └─ --build-arg BINARY_SOURCE=prebuilt                              │
│     └─ Skips builder stage, just copies binary                         │
│     └─ Uses Docker layer caching for runtime layers                    │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Related

- [Docker Compose](../deploy/docker-compose/)
- [Development Guide](../../docs/development/README.md)
- [Taskfile.yml](../../Taskfile.yml)
- [CI Pipeline](.harness/pipelines/CI/CI-Unified-v3.yaml)
