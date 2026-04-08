# Cinema Microservices - Test Suite

## 1. Overview

Automated testing suite for cinema microservices: unit tests, integration tests, contract tests, and E2E tests.

**Testing Pyramid:**
```
       /E2E\         Full system with Docker (slow)
      /------\
     /Contract\      Pact consumer/provider
    /----------\
   /Integration\     Service + DB (manual)
  /--------------\
 /  Unit Tests    \  Isolated logic (fast, no infra)
```

## 2. Architecture

```
                    +------------------+
                    |   E2E Tests      |
                    | (Go test suite)  |
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
   |     :27017      |  :6379  |     :4222             |
   +---------------------------------------------------+
```

### Services

| Service      | Port  | Description                          | Dependencies           |
|--------------|-------|--------------------------------------|------------------------|
| movie        | 8000  | Movie catalog management             | MongoDB, NATS          |
| cinema       | 8085  | Cinema/theater management            | MongoDB, NATS          |
| user         | 8004  | User registration and authentication | MongoDB, Redis, NATS   |
| showtime     | 3003  | Showtime scheduling                  | MongoDB, NATS, movie   |
| seat         | 3004  | Seat availability and holds          | MongoDB, Redis, NATS   |
| payment      | 8001  | Payment processing (Stripe mock)     | MongoDB, NATS          |
| booking      | 8082  | Booking orchestration                | MongoDB, NATS, all svc |
| notification | 8002  | Email notifications                  | NATS                   |

### Infrastructure

| Component | Version | Purpose                              | Port  |
|-----------|---------|--------------------------------------|-------|
| MongoDB   | 8.0     | Primary database (replica set rs0)   | 27017 |
| Redis     | 7       | Session management, seat hold TTL    | 6379  |
| NATS      | 2.10    | Async messaging (JetStream enabled)  | 4222  |

## 3. Prerequisites

> **Note:** This project runs in a devcontainer based on `golang:alpine`. All tools are pre-installed.

| Tool | Version | Install (Alpine) |
|------|---------|------------------|
| Go | 1.24+ | Pre-installed in devcontainer |
| Docker | 24+ | Pre-installed (Docker-in-Docker) |
| Task | 3+ | `go install github.com/go-task/task/v3/cmd/task@latest` |
| Spectral | 6+ | `npm install -g @stoplight/spectral-cli` |

## 4. Directory Structure

```
tests/
├── README.md
├── integration/
│   ├── go.mod                  # Test module dependencies
│   └── e2e_booking_test.go     # E2E test suite
└── test-results/               # JUnit XML reports (CI output)

platform/
├── docker/
│   ├── go-service/             # Service Dockerfile
│   └── testing/                # E2E test infrastructure
│       ├── docker-compose.e2e.yml    # Profiles: infra, full, e2e
│       ├── e2e-runner.Dockerfile     # Test runner container
│       └── mongo-init/
│           ├── mongo-init.Dockerfile # MongoDB init container
│           └── *.js                  # Seed data scripts
└── scripts/
    └── taskfile/               # Task automation scripts
        ├── lib/
        │   ├── common.sh       # Shared functions
        │   └── report.sh       # Test reporting
        ├── test-unit.sh
        ├── test-unit-all.sh
        ├── test-e2e.sh
        ├── coverage.sh
        └── ...
```

## 5. Quick Start

```bash
# List all commands
task --list

# Run unit tests (no infrastructure needed)
task test:unit:all

# Run CI pipeline (lint + unit + openapi, no infra)
task test:ci

# Run E2E tests (starts full system with Docker)
task test:e2e
```

## 6. Health Checks

All services expose a `/ping` endpoint that returns `pong`:

```bash
curl http://localhost:8000/ping  # movie   -> "pong"
curl http://localhost:8085/ping  # cinema  -> "pong"
curl http://localhost:8004/ping  # user    -> "pong"
curl http://localhost:3003/ping  # showtime-> "pong"
curl http://localhost:3004/ping  # seat    -> "pong"
curl http://localhost:8001/ping  # payment -> "pong"
curl http://localhost:8082/ping  # booking -> "pong"
curl http://localhost:8002/ping  # notification -> "pong"
```

Docker Compose uses these endpoints to determine service readiness.

## 7. E2E Test Coverage

The E2E test suite (`tests/integration/e2e_booking_test.go`) validates:

| Step | Test | Description |
|------|------|-------------|
| 1 | User Registration | Create account, login, get JWT token |
| 2 | Browse Movies | List available movies from catalog |
| 3 | Select Showtime | Query showtimes for a movie |
| 4 | View Seat Map | Check seat availability for a showtime |
| 5 | Hold Seats | Temporarily reserve seats (with TTL) |
| 6 | Create Booking | Complete booking with payment |
| 7 | Verify Booking | Confirm booking was created |
| 8 | Notification | Verify notification service processed event |
| 9 | Concurrent Holds | Race condition prevention (409 Conflict) |
| 10 | Hold Expiration | TTL-based seat release (skipped) |

## 8. Commands Reference

### Testing

| Command | Description | Requires Infra |
|---------|-------------|----------------|
| `task test:unit SERVICE=booking` | Unit tests for one service | No |
| `task test:unit:all` | Unit tests for all services | No |
| `task test:ci` | CI pipeline: lint + unit + openapi (JUnit XML) | No |
| `task test:integration` | Integration tests (manual) | Yes |
| `task test:e2e` | E2E tests (full system) | Yes (auto) |

### Infrastructure

| Command | Description |
|---------|-------------|
| `task infra:up` | Start MongoDB + Redis + NATS |
| `task infra:down` | Stop and remove volumes |
| `task infra:logs` | Stream container logs |
| `task infra:reset` | Restart infrastructure |

### Linting & Format

| Command | Description |
|---------|-------------|
| `task lint` | Go + OpenAPI linting |
| `task lint:go` | Go linting only |
| `task lint:openapi` | OpenAPI specs only |
| `task fmt` | Format all Go code |

### Coverage

| Command | Description |
|---------|-------------|
| `task coverage` | Generate HTML report (test-results/coverage.html) |

### Contracts (Pact)

| Command | Description |
|---------|-------------|
| `task contract:consumer` | Generate pact JSON files |
| `task contract:verify` | Verify provider contracts |
| `task contract:clean` | Delete pact files |

## 9. Configuration

### Environment Variables

Tests can be configured via environment variables:

| Variable               | Default                    | Description                |
|------------------------|----------------------------|----------------------------|
| USER_SERVICE_URL       | http://localhost:8004      | User service endpoint      |
| MOVIE_SERVICE_URL      | http://localhost:8000      | Movie service endpoint     |
| CINEMA_SERVICE_URL     | http://localhost:8085      | Cinema service endpoint    |
| SHOWTIME_SERVICE_URL   | http://localhost:3003      | Showtime service endpoint  |
| SEAT_SERVICE_URL       | http://localhost:3004      | Seat service endpoint      |
| PAYMENT_SERVICE_URL    | http://localhost:8001      | Payment service endpoint   |
| BOOKING_SERVICE_URL    | http://localhost:8082      | Booking service endpoint   |
| NOTIFICATION_SERVICE_URL| http://localhost:8002     | Notification service URL   |

### Docker Compose Profiles

| Profile | Services                                    |
|---------|---------------------------------------------|
| infra   | MongoDB, Redis, NATS (infrastructure only)  |
| full    | All 8 microservices + infrastructure        |

## 10. Test Data

### Available IDs

| Entity | ID | Description |
|--------|----|-----------  |
| Movie | `507f1f77bcf86cd799439011` | The Matrix |
| Movie | `507f1f77bcf86cd799439012` | Inception |
| Cinema | `507f1f77bcf86cd799439022` | Cinema Downtown |
| Room | `507f1f77bcf86cd799439031` | Room 1 (100 seats) |
| Room | `507f1f77bcf86cd799439032` | VIP Room (50 seats) |
| Showtime | `507f1f77bcf86cd799439033` | Tomorrow 7 PM |
| User | `507f1f77bcf86cd799439041` | test@example.com |

### Test Credentials

| Service | Value |
|---------|-------|
| Test User | test@example.com |
| Stripe (mock) | pk_test_mock / sk_test_mock |

## 11. Troubleshooting

### MongoDB not starting

```bash
docker compose -f tests/docker-compose.yml down -v
docker volume prune -f
task infra:up
```

### Connection refused

```bash
# Check containers are running
docker compose -f tests/docker-compose.yml ps
task health
```

### Services not healthy

```bash
# Check individual service logs
docker compose -f tests/docker-compose.yml logs booking

# Verify /ping endpoint
curl -v http://localhost:8082/ping
```

### NATS connection issues

```bash
# Check NATS health
curl http://localhost:8222/healthz

# View NATS connections
curl http://localhost:8222/connz
```

### E2E timeout

```bash
# Check service logs
docker compose -f tests/docker-compose.yml logs booking

# Increase wait time (edit Taskfile.yml sleep value)
```

## 12. Changes History

### 2024-04 - NATS Message Queue Integration

**What changed:**
- Added NATS 2.10 container with JetStream enabled to docker-compose.yml
- All services now receive `NATS_URL` environment variable
- Services connect to `nats://nats:4222` for async messaging

**Why:**
- Enable reliable async communication between services
- Support booking event notifications (payment confirmed, email sent)
- Decouple services for better scalability and resilience
- Replace direct HTTP calls for non-critical operations

### 2024-04 - MongoDB No-Auth Mode

**What changed:**
- Modified `internal/db/mongo.go` in booking and payment services
- Added conditional URI building based on `DB_USER`/`DB_PASS` presence
- Empty credentials now build URI without authentication

**Why:**
- Simplified local/test environment setup
- Removed authentication overhead for E2E testing
- Production deployments still use full authentication

### 2024-04 - Docker-in-Docker Compatibility

**What changed:**
- Created `tests/data/mongo-init/Dockerfile` to bake init scripts into image
- Removed volume mounts for mongo-init scripts
- mongo-init container now uses `--rm` pattern

**Why:**
- Volume mounts don't propagate correctly in nested Docker (devcontainer)
- Baking scripts into image ensures consistent behavior across environments
- Works reliably in GitHub Actions, local Docker, and devcontainers

### 2024-04 - Health Check Standardization

**What changed:**
- All 8 services now expose `/ping` endpoint returning plain text `pong`
- Docker Compose healthchecks use `wget -qO- http://localhost:PORT/ping | grep -q pong`
- E2E tests verify `/ping` endpoints for all services before running flow tests

**Why:**
- Consistent health check pattern across all microservices
- Docker can properly determine when services are ready
- Prevents tests from running against unhealthy services
- Clear contract: if `/ping` returns `pong`, service is ready

### 2024-04 - Go 1.24 and GOWORK=off

**What changed:**
- Updated Dockerfile to use Go 1.24 and Alpine 3.21
- Added `ENV GOWORK=off` to prevent workspace mode conflicts
- Each service builds independently without go.work interference

**Why:**
- Go 1.24 required by go.mod files
- go.work workspace mode caused "module not found" errors in Docker builds
- GOWORK=off ensures each service builds in isolation
