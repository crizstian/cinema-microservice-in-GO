# Docker Compose - Cinema Microservices

Unified Docker Compose configuration for development and testing environments.

## Quick Start

```bash
# Start development environment
task dev:up

# Stop and clean
task dev:down

# View logs
task dev:log
```

## Profiles

The compose file uses profiles to support multiple environments:

| Profile | MongoDB | Storage | Use Case |
|---------|---------|---------|----------|
| `dev` | 3-node replica set | Persistent volumes | Local development |
| `test` | Single node | tmpfs (ephemeral) | Fast E2E testing |
| `e2e` | - | - | Test runner only |

### Development Profile

```bash
# Start with 3 MongoDB replicas
docker compose --profile dev up -d

# Or via Task
task dev:up
```

Services:
- MongoDB: mongo1:27017, mongo2:27018, mongo3:27019
- Redis: localhost:6379
- NATS: localhost:4222 (JetStream enabled)
- All 8 microservices with health checks

### Test Profile

```bash
# Start test environment
docker compose --profile test up -d

# Run E2E tests
docker compose --profile test --profile e2e run --rm e2e-runner

# Or via Task (handles everything)
task test:e2e
```

Uses tmpfs for fast, disposable test runs.

## Services

| Service | Port | Health Check |
|---------|------|--------------|
| movie | 8000 | `/ping` |
| cinema | 8085 | `/ping` |
| user | 8004 | `/ping` |
| showtime | 3003 | `/ping` |
| seat | 3004 | `/ping` |
| payment | 8001 | `/ping` |
| notification | 8002 | `/ping` |
| booking | 8082 | `/ping` |

## Environment Variables

Override defaults with environment variables:

```bash
# Container name prefix
ENV_PREFIX=myenv docker compose --profile dev up -d

# MongoDB servers (for services)
MONGO_SERVERS=mongo1:27017,mongo2:27017 docker compose --profile dev up -d

# Registry and version
REGISTRY=myregistry VERSION=1.0.0 docker compose --profile dev up -d
```

## Manual Commands

```bash
# Validate configuration
docker compose config

# List profiles
docker compose config --profiles

# List services in profile
docker compose --profile dev config --services

# Build specific service
docker compose --profile dev build movie

# View logs for specific service
docker compose --profile dev logs -f booking

# Execute command in running container
docker compose --profile dev exec movie sh
```

## Troubleshooting

### Services not becoming healthy

```bash
# Check health status
docker compose --profile dev ps

# View service logs
docker compose --profile dev logs movie

# Check MongoDB replica set
docker exec dev-mongo1 mongosh --eval "rs.status()"
```

### Port conflicts

If ports are in use, stop existing containers or change the port mapping:

```bash
# Find what's using a port
lsof -i :27017

# Stop all cinema containers
docker compose --profile dev --profile test down
```

## Related

- [Dockerfiles](../../docker/)
- [Taskfile.yml](../../../Taskfile.yml)
- [Development Guide](../../../docs/development/README.md)
