# Cinema Microservices - Test Suite

## Overview

Automated testing suite: unit tests, contract tests (Pact), and E2E tests.

**Testing Pyramid:**
```
       /E2E\         Full system with Docker (slow)
      /------\
     /Contract\      Pact consumer/provider
    /----------\
   /  Unit Tests \   Isolated logic (fast, no infra)
```

## Quick Start

```bash
# List all test commands
task --list

# Unit tests (no infrastructure needed)
task test:all

# Contract tests (Pact)
task test:contract

# E2E tests (starts full system)
task test:e2e

# CI pipeline (lint + unit + coverage)
task test:ci
```

## Directory Structure

```
tests/
├── README.md
├── contracts/              # Pact contract tests
│   ├── consumer/           # Consumer contract tests
│   └── provider/           # Provider verification
├── integration/            # E2E test suite
│   ├── e2e_booking_test.go # Complete booking flow tests
│   ├── go.mod
│   └── README.md
└── test-results/           # JUnit XML reports (CI output)

platform/
├── docker/
│   ├── e2e-runner/         # E2E test runner Dockerfile
│   ├── go-service/         # Service Dockerfile
│   └── mongodb/            # MongoDB init + seeds
└── deploy/
    └── docker-compose/
        └── docker-compose.yml  # Unified compose (dev + test profiles)
```

## Architecture

```
                    +------------------+
                    |   E2E Tests      |
                    | (e2e-runner)     |
                    +--------+---------+
                             |
        +--------------------+--------------------+
        |         |          |         |          |
   +----v----+ +--v---+ +----v----+ +--v---+ +---v----+
   |  user   | |movie | | cinema  | |seat  | |showtime|
   | :8004   | |:8000 | | :8085   | |:3004 | | :3003  |
   +---------+ +------+ +---------+ +------+ +--------+
        |         |          |         |          |
        |    +----v----+ +---v----+ +--v---+      |
        |    | payment | |booking | |notif.|      |
        |    | :8001   | | :8082  | |:8002 |      |
        |    +---------+ +--------+ +------+      |
        |         |          |         |          |
   +----v---------v----------v---------v----------v----+
   |                  Infrastructure                    |
   |  MongoDB (rs0)  |  Redis  |  NATS (JetStream)     |
   +---------------------------------------------------+
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| user | 8004 | Authentication, JWT tokens |
| movie | 8000 | Movie catalog |
| cinema | 8085 | Cinema locations |
| showtime | 3003 | Show schedules |
| seat | 3004 | Seat inventory, holds |
| payment | 8001 | Payment processing |
| booking | 8082 | SAGA orchestrator |
| notification | 8002 | Email notifications |

## Commands Reference

### Testing

| Command | Description | Requires Infra |
|---------|-------------|----------------|
| `task test SERVICE=booking` | Unit tests for one service | No |
| `task test:all` | Unit tests for all services | No |
| `task test:contract` | Pact consumer + provider | No |
| `task test:e2e` | E2E tests (full system) | Auto |
| `task test:ci` | CI: lint + unit + coverage | No |

### Development Environment

| Command | Description |
|---------|-------------|
| `task dev:up` | Start dev environment (3 MongoDB replicas) |
| `task dev:down` | Stop and clean volumes |
| `task dev:log` | Stream container logs |

## Health Checks

All services expose `/ping` returning `pong`:

```bash
curl http://localhost:8000/ping  # movie
curl http://localhost:8085/ping  # cinema
curl http://localhost:8004/ping  # user
curl http://localhost:3003/ping  # showtime
curl http://localhost:3004/ping  # seat
curl http://localhost:8001/ping  # payment
curl http://localhost:8082/ping  # booking
curl http://localhost:8002/ping  # notification
```

## E2E Test Flow

The E2E suite validates the complete booking workflow:

1. **User Registration** - Create account, login, get JWT
2. **Browse Movies** - List available movies
3. **Select Showtime** - Query showtimes
4. **View Seat Map** - Check seat availability
5. **Hold Seats** - Temporary reservation (5 min TTL)
6. **Create Booking** - SAGA: validate, pay, confirm, notify
7. **Verify Booking** - Confirm ticket created
8. **Notification** - Verify service health
9. **Concurrent Holds** - Race condition prevention
10. **Hold Expiration** - TTL release (skipped)

## Docker Compose Profiles

| Profile | Description |
|---------|-------------|
| `dev` | 3 MongoDB replicas, persistent volumes |
| `test` | 1 MongoDB node, tmpfs (fast, ephemeral) |
| `e2e` | E2E test runner container |

## Troubleshooting

### Services not starting

```bash
# Check container status
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test ps

# View logs
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test logs booking
```

### MongoDB issues

```bash
# Check replica set
docker exec test-mongo mongosh --eval "rs.status()"
```

### Clean restart

```bash
# Remove all containers and volumes
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test --profile dev down -v

# Rebuild
task dev:up
```

## Related

- [E2E Test Details](./integration/README.md)
- [Docker Compose](../platform/deploy/docker-compose/README.md)
- [Development Guide](../docs/development/README.md)
