# Platform Docker

This directory contains Docker configurations for the Cinema Microservices platform.

**Last Updated**: 2026-04-08

---

## Directory Structure

```
platform/docker/
├── devcontainer/          # VS Code DevContainer configuration
│   ├── Dockerfile         # Development environment image
│   └── README.md          # DevContainer usage guide
├── go-service/            # Generic Go service Dockerfile
│   ├── Dockerfile         # Multi-stage build for all Go services
│   ├── .dockerignore      # Build exclusions
│   └── README.md          # Build instructions
├── mongodb/               # MongoDB replica set configuration
│   ├── Dockerfile         # MongoDB with replica set support
│   ├── Dockerfile.local   # Local development variant
│   ├── files/             # Initialization scripts
│   └── startup/           # Container startup scripts
└── testing/               # E2E testing infrastructure
    ├── docker-compose.e2e.yml  # Full test environment
    ├── e2e-runner.Dockerfile   # Test runner image
    └── mongo-init/             # Test data initialization
```

---

## Components

### Go Service Dockerfile

The centralized Dockerfile for all Go microservices:

```bash
# Build a service
task build SERVICE=booking

# Or directly
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  -t cinema/booking:latest \
  services/booking
```

See: [go-service/README.md](./go-service/README.md)

### DevContainer

Development environment for VS Code:

```bash
# Open project in VS Code
# Press F1 → "Dev Containers: Reopen in Container"
```

Includes: Go 1.22+, Docker CLI, kubectl, Task, Spectral, pact-go

See: [devcontainer/README.md](./devcontainer/README.md)

### MongoDB

MongoDB 8.0 replica set configuration for local development:

```bash
# Start MongoDB cluster
cd platform/deploy/docker-compose
docker compose up -d mongo1 mongo2 mongo3 mongo-init
```

### Testing Infrastructure

E2E test environment with all services:

```bash
# Run E2E tests
task test:e2e

# Or manually
docker compose -f platform/docker/testing/docker-compose.e2e.yml up
```

---

## Related Documentation

- [Development Guide](../../docs/development/README.md)
- [Operations Guide](../../docs/operations/README.md)
- [Docker Compose](../deploy/docker-compose/readme.md)
