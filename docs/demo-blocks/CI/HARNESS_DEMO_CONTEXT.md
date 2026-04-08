# Cinema Microservices - Harness Demo Context

> **Purpose**: Complete monorepo context for Harness Sales Engineer demos  
> **Version**: 0.1.0 | **Go**: 1.24 | **Services**: 8 microservices

---

## Executive Summary

This is a **production-grade cinema ticketing platform** built as a Go microservices monorepo. It demonstrates real-world patterns for distributed systems: SAGA transactions, event-driven architecture, consumer-driven contracts, and infrastructure-as-code.

**Perfect for Harness demos because:**
- 8 independent services = ideal for **looping strategies**
- Multiple test levels = showcase **Test Intelligence**
- Contract testing = demonstrate **pipeline dependencies**
- OpenAPI specs = show **API governance** in CI
- Semantic versioning = demonstrate **artifact management**

---

## 1. Repository Structure

```
cinema-microservices/
├── services/                    # 8 Go microservices (each a Go module)
│   ├── booking/                 # SAGA orchestrator (consumer of 4 services)
│   ├── movie/                   # Movie catalog
│   ├── cinema/                  # Cinema locations
│   ├── showtime/                # Schedule management
│   ├── seat/                    # Real-time seat inventory (Redis + MongoDB)
│   ├── payment/                 # Stripe integration (Pact provider)
│   ├── notification/            # Email/SMS delivery
│   └── user/                    # Authentication (JWT)
├── platform/
│   ├── docker/
│   │   ├── go-service/          # Generic multi-stage Dockerfile
│   │   └── devcontainer/        # Development container
│   └── deploy/
│       ├── docker-compose/      # Local deployment
│       └── hashicorp/           # Terraform (Consul, Vault)
├── contracts/                   # Pact contract JSON files
├── tests/
│   ├── integration/             # E2E test suite
│   ├── test-results/            # JUnit XML reports
│   └── docker-compose.yml       # Test infrastructure
├── go.work                      # Go workspace (8 modules)
├── Taskfile.yml                 # 30+ automation tasks
├── VERSION                      # Semantic version (0.1.0)
└── .spectral.yaml               # OpenAPI linting rules
```

---

## 2. Microservices Matrix

| Service | Port | Database | External APIs | Key Feature |
|---------|------|----------|---------------|-------------|
| **booking** | 8082 | MongoDB | payment, seat, showtime, notification | SAGA orchestrator |
| **movie** | 8000 | MongoDB | - | Catalog queries |
| **cinema** | 8085 | MongoDB | - | Location management |
| **showtime** | 3003 | MongoDB | movie (validation) | Schedule conflicts |
| **seat** | 3004 | MongoDB + Redis | - | Distributed locks, TTL holds |
| **payment** | 8001 | MongoDB | Stripe | Idempotent charges |
| **notification** | 8002 | - | SMTP | Async delivery |
| **user** | 8004 | MongoDB | - | JWT auth, bcrypt |

### Service Dependencies Graph

```
                    ┌──────────────┐
                    │    USER      │
                    │   (auth)     │
                    └──────────────┘
                           │
    ┌──────────────────────┼──────────────────────┐
    │                      │                      │
    ▼                      ▼                      ▼
┌────────┐          ┌──────────┐          ┌──────────┐
│ MOVIE  │◄─────────│ SHOWTIME │          │  CINEMA  │
│        │          │          │          │          │
└────────┘          └────┬─────┘          └──────────┘
                         │
                         ▼
                    ┌────────┐
                    │  SEAT  │◄────────────┐
                    └────┬───┘             │
                         │                 │
                         ▼                 │
                 ┌──────────────┐          │
                 │   BOOKING    │──────────┘
                 │   (SAGA)     │
                 └──────┬───────┘
                        │
            ┌───────────┼───────────┐
            ▼           ▼           ▼
       ┌─────────┐ ┌──────────┐ ┌──────────────┐
       │ PAYMENT │ │   SEAT   │ │ NOTIFICATION │
       │         │ │ (confirm)│ │              │
       └─────────┘ └──────────┘ └──────────────┘
```

---

## 3. Build & Execution

### 3.1 Docker Build (Centralized Dockerfile)

All services use a single, parameterized Dockerfile:

```dockerfile
# platform/docker/go-service/Dockerfile
FROM golang:1.24-alpine AS builder
ARG SERVICE_NAME
ARG SERVICE_PORT=8000
ARG VERSION=dev
ARG COMMIT_SHA=unknown
ARG BUILD_DATE=unknown

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags "-X main.Version=${VERSION}" \
    -o /service ./cmd/${SERVICE_NAME}

FROM alpine:3.21
USER 1000:1000
COPY --from=builder /service /service
EXPOSE ${SERVICE_PORT}
CMD ["/service"]
```

**Build Commands:**
```bash
# Single service
task build SERVICE=booking TAG=v1.0.0

# All services (looping)
task build:all

# Direct Docker build
docker build \
  --file platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg SERVICE_PORT=8082 \
  --build-arg VERSION=0.1.0 \
  --build-arg COMMIT_SHA=$(git rev-parse --short HEAD) \
  --tag crizstian/cinema/booking:0.1.0 \
  services/booking
```

### 3.2 Local Execution

```bash
# Run single service locally
cd services/booking && go run ./cmd/booking

# Required env vars (service-specific)
export DB_SERVERS=localhost:27017
export DB_NAME=cinema
export SERVICE_PORT=8082
export PAYMENT_URL=http://localhost:8001
export SEAT_SERVICE_URL=http://localhost:3004
export SHOWTIME_SERVICE_URL=http://localhost:3003
export NOTIFICATION_URL=http://localhost:8002
```

### 3.3 Docker Compose (Full System)

```bash
# Start infrastructure only
docker compose -f tests/docker-compose.yml --profile infra up -d

# Start all services
docker compose -f tests/docker-compose.yml --profile full up -d

# Development environment
docker compose -f platform/deploy/docker-compose/docker-compose.yml up -d
```

---

## 4. Testing Pyramid

### 4.1 Test Levels Summary

| Level | Files | Infra Required | Execution Time | Output |
|-------|-------|----------------|----------------|--------|
| **Unit** | 36 files | None | ~30 seconds | test-results/*.out |
| **Integration** | 1 suite | MongoDB, Redis, NATS | ~2 minutes | tests/test-results/ |
| **Contract** | 5 files | None (mock mode) | ~45 seconds | contracts/*.json |
| **E2E** | 1 suite | Full system (8 services) | ~5 minutes | Docker logs |

### 4.2 Unit Tests

**Characteristics:**
- Co-located with source code (`*_test.go`)
- Uses `-short` flag to skip slow tests
- Race detection with `-race`
- Coverage profiles per service

**Execution:**
```bash
# Single service
task test:unit SERVICE=booking

# All services
task test:unit:all

# Direct Go command
cd services/booking && go test -v -race -short -cover \
  $(go list ./... | grep -v '/contracts' | grep -v '/integration')
```

**Service Coverage:**
| Service | Test Files | Coverage Target |
|---------|-----------|-----------------|
| booking | 9 | API, models, service, routes |
| movie | 8 | API, db, models, server |
| showtime | 6 | API, clients, db |
| payment | 4 | API, models, routes |
| user | 3 | API, middleware, models |
| cinema | 2 | API, models |
| notification | 2 | API, models |
| seat | 1 | API |

### 4.3 Contract Tests (Pact)

**Consumer Tests** (booking service):
```
services/booking/contracts/consumer/
├── notification_consumer_test.go
├── payment_consumer_test.go
├── seat_consumer_test.go
└── showtime_consumer_test.go
```

**Provider Tests** (payment service):
```
services/payment/contracts/provider/
└── payment_provider_test.go
```

**Execution:**
```bash
# Generate pact files (consumer side)
task contract:consumer
# Output: contracts/*.json

# Verify provider compliance
task contract:verify
# Uses: PACT_PROVIDER_VERIFICATION=true
```

### 4.4 Integration Tests

**Location:** `tests/integration/e2e_booking_test.go`

**Test Flow (10 steps):**
1. User registration
2. Movie catalog query
3. Showtime selection
4. Seat map retrieval
5. Seat hold (5-min TTL)
6. Booking creation with payment
7. Booking verification
8. Notification check
9. Concurrent hold prevention
10. Hold expiration validation

**Execution:**
```bash
task infra:up          # Start MongoDB, Redis, NATS
task test:integration  # Run integration suite
```

### 4.5 E2E Tests

**Infrastructure:** Full Docker Compose with all 8 services

**Execution:**
```bash
task test:e2e
# 1. Starts full system (--profile full)
# 2. Waits for 8 healthy services (90 iterations, 2s each)
# 3. Builds and runs e2e-runner container
# 4. Cleanup (docker compose down -v)
```

### 4.6 CI Pipeline Task

```bash
task test:ci
# 1. Lint (go vet + Spectral OpenAPI)
# 2. Unit tests with JUnit XML output
# 3. Coverage profiles
# Output: tests/test-results/{service}-unit.xml
```

---

## 5. Task Automation (Taskfile.yml)

### 5.1 Complete Task List

```yaml
# VERSION MANAGEMENT
version              # Display current version (0.1.0)
version:bump-patch   # 0.1.0 → 0.1.1 (bug fixes)
version:bump-minor   # 0.1.0 → 0.2.0 (features)
version:bump-major   # 0.1.0 → 1.0.0 (breaking changes)
version:set          # Manual: task version:set -- 2.0.0
version:tag          # Git tag: v0.1.0

# BUILD
build                # Single: task build SERVICE=booking
build:all            # All services (loops over SERVICES var)

# PUSH (Docker Registry)
push                 # Single: task push SERVICE=booking
push:all             # All services

# COMPOSE
compose:update       # Update image tag in docker-compose.yml
compose:update-all   # All services

# RELEASE (version + build + compose)
release:patch        # Bug fix release
release:minor        # Feature release
release:major        # Breaking change release

# DEV
dev:up               # Start services via docker-compose
dev:down             # Stop services
dev:logs             # Stream logs

# LINT
lint                 # All linters
lint:go              # go vet across all services
lint:openapi         # Spectral validation

# TEST
test:unit            # Single service unit tests
test:unit:all        # All services unit tests
test:integration     # Integration tests (requires infra)
test:e2e             # Full E2E (docker-compose)
test:ci              # CI pipeline (lint + unit + JUnit)

# INFRASTRUCTURE
infra:up             # MongoDB + Redis + NATS
infra:down           # Stop and remove volumes
infra:logs           # Stream infra logs
infra:reset          # Restart infrastructure

# COVERAGE
coverage             # HTML report at test-results/coverage.html

# CONTRACTS
contract:consumer    # Run Pact consumer tests
contract:verify      # Verify provider compliance
contract:clean       # Delete pact JSON files

# UTILITIES
images               # List project Docker images
clean                # Remove images + prune cache
health               # Check service health endpoints
```

### 5.2 Dynamic Variables

```yaml
vars:
  REGISTRY: '{{.REGISTRY | default "docker.io/crizstian/cinema"}}'
  VERSION:
    sh: cat VERSION 2>/dev/null || echo "0.0.0-dev"
  COMMIT_SHA:
    sh: git rev-parse --short HEAD 2>/dev/null || echo "unknown"
  BUILD_DATE:
    sh: date -u +"%Y-%m-%dT%H:%M:%SZ"
  SERVICES:
    sh: ls -d services/*/go.mod 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {} | tr '\n' ' '
```

### 5.3 Looping Pattern (Monorepo)

```yaml
build:all:
  desc: "Build Docker images for all services"
  cmds:
    - for: { var: SERVICES, split: " " }
      task: build
      vars:
        SERVICE: "{{.ITEM}}"
```

---

## 6. OpenAPI Specifications

All services have OpenAPI 3.0 specs:

```
services/booking/api/openapi.yaml
services/cinema/api/openapi.yaml
services/movie/api/openapi.yaml
services/notification/api/openapi.yaml
services/payment/api/openapi.yaml
services/seat/api/openapi.yaml
services/showtime/api/openapi.yaml
services/user/api/openapi.yaml
```

**Linting:**
```bash
spectral lint services/*/api/openapi.yaml --ruleset .spectral.yaml
```

---

## 7. Environment Variables

### 7.1 Common (All Services)

| Variable | Example | Purpose |
|----------|---------|---------|
| `SERVICE_PORT` | 8082 | HTTP listen port |
| `DB_SERVERS` | mongo:27017 | MongoDB connection |
| `DB_NAME` | cinema | Database name |
| `DB_REPLICA` | rs0 | Replica set name |
| `NATS_URL` | nats://nats:4222 | Event bus |

### 7.2 Service-Specific

| Service | Variable | Purpose |
|---------|----------|---------|
| booking | `PAYMENT_URL` | Payment service endpoint |
| booking | `SEAT_SERVICE_URL` | Seat service endpoint |
| booking | `SHOWTIME_SERVICE_URL` | Showtime service endpoint |
| booking | `NOTIFICATION_URL` | Notification service endpoint |
| payment | `STRIPE_PUBLIC` | Stripe publishable key |
| payment | `STRIPE_SECRET` | Stripe secret key |
| payment | `STRIPE_MOCK` | true for testing |
| notification | `EMAIL` | SMTP sender address |
| notification | `EMAIL_PASS` | SMTP password |
| user | `JWT_SECRET` | Token signing key |
| user | `REDIS_URL` | Session store |
| seat | `REDIS_ADDR` | Distributed locks |
| seat | `HOLD_TTL_SECONDS` | Seat hold duration |

---

## 8. CI/CD Integration Points

### 8.1 Build Artifacts

| Artifact | Path | Format |
|----------|------|--------|
| Docker Images | `${REGISTRY}/${SERVICE}:${VERSION}` | OCI |
| Unit Test Results | `tests/test-results/{service}-unit.xml` | JUnit XML |
| Coverage Profiles | `test-results/{service}.out` | Go coverage |
| Coverage HTML | `test-results/coverage.html` | HTML |
| Pact Contracts | `contracts/*.json` | Pact JSON |
| OpenAPI Specs | `services/*/api/openapi.yaml` | OpenAPI 3.0 |

### 8.2 Pipeline Stages (Recommended)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    LINT     │───▶│    TEST     │───▶│    BUILD    │───▶│   DEPLOY    │
│             │    │             │    │             │    │             │
│ go vet      │    │ Unit (all)  │    │ Docker      │    │ Push images │
│ Spectral    │    │ Contracts   │    │ build:all   │    │ Update tags │
│             │    │ Coverage    │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │
                          ▼
                   ┌─────────────┐
                   │ INTEGRATION │
                   │             │
                   │ E2E tests   │
                   │ (optional)  │
                   └─────────────┘
```

### 8.3 Test Intelligence Opportunities

**File-to-Test Mapping:**
```
services/booking/internal/api/booking.go
  → services/booking/internal/api/booking_test.go

services/payment/internal/models/payment.go
  → services/payment/internal/models/payment_test.go
```

**Test Selection Criteria:**
- Changed service → run that service's unit tests
- Changed contracts → run contract tests
- Changed infrastructure → run integration tests
- Changed OpenAPI → run Spectral lint

---

## 9. Harness Demo Scenarios

### 9.1 CI Pipeline Demo

**Story**: "Build and test a monorepo with 8 microservices"

**Highlights:**
- Matrix/looping strategy over `SERVICES` variable
- Parallel test execution per service
- JUnit XML report aggregation
- Coverage threshold gates

### 9.2 Test Intelligence Demo

**Story**: "Only run tests affected by code changes"

**Setup:**
1. Enable TI on Go tests
2. Make change to `services/payment/internal/api/payment.go`
3. Show TI selects only payment tests (not all 8 services)
4. Compare execution time: 8 services vs 1 service

**Metrics:**
- Without TI: ~30 seconds (all unit tests)
- With TI: ~5 seconds (only changed service)

### 9.3 Pipeline Variables Demo

**Story**: "Single pipeline, multiple environments"

**Variables:**
```yaml
REGISTRY: <+input>          # docker.io/crizstian/cinema
VERSION: <+pipeline.version>
ENVIRONMENT: <+stage.name>  # dev, staging, prod
SERVICE: <+matrix.service>  # booking, movie, etc.
```

### 9.4 Looping Strategy Demo

**Story**: "Build 8 services without duplicating pipeline config"

**Matrix Configuration:**
```yaml
strategy:
  matrix:
    service:
      - booking
      - cinema
      - movie
      - notification
      - payment
      - seat
      - showtime
      - user
  maxConcurrency: 4
```

**Dynamic from Taskfile:**
```bash
SERVICES=$(ls -d services/*/go.mod | xargs -I{} dirname {} | xargs -I{} basename {})
```

### 9.5 Contract Testing Demo

**Story**: "Ensure service compatibility before deployment"

**Pipeline Steps:**
1. Build booking service (consumer)
2. Run consumer contract tests → generate pact files
3. Build payment service (provider)
4. Verify provider against contracts
5. Publish contracts to Pact Broker (optional)

### 9.6 Multi-Stage Deployment Demo

**Story**: "Progressive rollout with quality gates"

**Stages:**
1. **Build**: All services in parallel (looping)
2. **Unit Tests**: Test Intelligence selects affected
3. **Contract Tests**: Consumer/provider verification
4. **Integration**: E2E against staging
5. **Deploy Staging**: Push images, update compose
6. **Deploy Prod**: Manual approval gate

---

## 10. Key Commands Reference

```bash
# Build
task build:all                    # Build all 8 service images
task build SERVICE=booking        # Build single service

# Test
task test:unit:all                # Unit tests (no infra)
task test:ci                      # CI mode with JUnit XML
task test:integration             # Requires infra:up
task test:e2e                     # Full system test

# Contract
task contract:consumer            # Generate pact files
task contract:verify              # Verify providers

# Coverage
task coverage                     # HTML report

# Release
task version:bump-patch           # Increment version
task release:patch                # Full release workflow

# Infrastructure
task infra:up                     # Start test infrastructure
task dev:up                       # Start all services
task health                       # Check all endpoints
```

---

## 11. Quick Reference Card

| What | Command/Path |
|------|--------------|
| **Version** | `cat VERSION` → 0.1.0 |
| **Services** | booking, cinema, movie, notification, payment, seat, showtime, user |
| **Main Dockerfile** | `platform/docker/go-service/Dockerfile` |
| **Test Infrastructure** | `tests/docker-compose.yml` |
| **OpenAPI Specs** | `services/*/api/openapi.yaml` |
| **Pact Contracts** | `contracts/*.json` |
| **JUnit Reports** | `tests/test-results/*-unit.xml` |
| **Coverage** | `test-results/coverage.html` |
| **All Tasks** | `task --list` |

---

## 12. Differentiators for Harness Demo

| Feature | This Repo Demonstrates |
|---------|------------------------|
| **Looping Strategy** | 8 services, single pipeline config |
| **Test Intelligence** | Go tests with clear file-to-test mapping |
| **Pipeline Variables** | SERVICE, VERSION, REGISTRY, ENVIRONMENT |
| **Artifact Management** | Docker images with semantic versioning |
| **Contract Testing** | Pact consumer/provider in pipeline |
| **Quality Gates** | Lint, coverage thresholds, contract verification |
| **JUnit Integration** | XML reports for all test levels |
| **Infrastructure as Code** | Terraform (Consul, Vault) |
| **OpenAPI Governance** | Spectral linting in CI |

---

*Generated for Harness Sales Engineer demos. Last updated: 2026-04-08*
