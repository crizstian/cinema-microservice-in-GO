# Development Guide - Cinema Ticketing System

> **AI Agent Context**: This guide covers local development setup, testing strategies, and contribution guidelines. For architecture decisions, see [Architecture Documentation](../architecture/README.md).

**Last Updated**: 2026-04-08

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Environment](#development-environment)
3. [Building Services](#building-services)
4. [Testing Strategy](#testing-strategy)
5. [Code Style](#code-style)
6. [Contributing](#contributing)

---

## Getting Started

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Go | 1.22+ | Service development |
| Docker | 24+ | Containerization |
| Docker Compose | v2+ | Local orchestration |
| Task | 3.x | Task automation |
| Node.js | 20+ | OpenAPI tooling (Spectral) |

### Quick Start

```bash
# Clone repository
git clone https://github.com/your-org/cinema-microservices.git
cd cinema-microservices

# Install dependencies
go work sync
npm install  # For Spectral

# Start infrastructure
cd platform/deploy/docker-compose
docker compose up -d mongo1 mongo2 mongo3

# Run a service locally
cd services/booking
go run ./cmd/booking

# Run tests
go test ./...
```

### VS Code DevContainer (Recommended)

The easiest way to get started is using VS Code Dev Containers:

1. Install VS Code + "Dev Containers" extension
2. Open project folder
3. Press `F1` → "Dev Containers: Reopen in Container"
4. Wait for container to build
5. All tools pre-installed and configured

DevContainer includes:
- Go 1.22
- Docker CLI
- kubectl
- Task
- git
- Spectral
- pact-go

Configuration: [/.devcontainer/devcontainer.json](../../.devcontainer/devcontainer.json)

---

## Development Environment

### Project Structure

```
/workspace/
├── services/                    # Microservices
│   ├── booking/                 # Each service is independent
│   │   ├── cmd/booking/main.go  # Entry point
│   │   ├── internal/            # Private code
│   │   ├── contracts/           # Pact tests
│   │   ├── api/openapi.yaml     # API spec
│   │   └── go.mod               # Module definition
│   └── ...
├── platform/                    # Infrastructure
│   ├── docker/                  # Dockerfiles
│   ├── deploy/                  # Deployment configs
│   └── scripts/                 # Build scripts
├── docs/                        # Documentation
├── contracts/                   # Generated Pact files
├── tests/                       # Integration/E2E tests
├── go.work                      # Go workspace
├── Taskfile.yml                 # Task definitions
└── VERSION                      # Semantic version
```

### Go Workspace

This is a **Go Workspace** monorepo. Each service is an independent module:

```bash
# go.work defines the workspace
cat go.work
# use (
#     ./services/booking
#     ./services/movie
#     ./services/payment
#     ./services/notification
# )

# Sync all modules
go work sync

# Add a new service to workspace
go work use ./services/new-service
```

### Environment Variables

#### MongoDB Connection

```env
DB_USER=cristian
DB_PASS=cristianPassword2017
DB_SERVERS=localhost:27017,localhost:27018,localhost:27019
DB_NAME=booking
DB_REPLICA=rs1
```

#### Service Configuration

```env
SERVICE_PORT=8000
LOG_LEVEL=debug
```

#### External Services

```env
# Payment
STRIPE_KEY=sk_test_xxx

# Notification
EMAIL=your-email@gmail.com
EMAIL_PASS=your-app-password
```

---

## Building Services

### Local Build

```bash
cd services/booking
go build -o booking ./cmd/booking
./booking
```

### Docker Build

Using the centralized Dockerfile:

```bash
# With Taskfile (recommended)
task build SERVICE=booking

# Or directly
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  -t cinema/booking:latest \
  .
```

### Build All Services

```bash
task build:all
```

### Taskfile Commands

```bash
# List all commands
task

# Version management
task version              # Show current version
task version:bump-patch   # Bump patch (x.x.X)
task version:bump-minor   # Bump minor (x.X.0)
task version:bump-major   # Bump major (X.0.0)

# Building
task build SERVICE=movie  # Build single service
task build:all            # Build all services

# Docker Compose
task compose:up           # Start all services
task compose:down         # Stop all services
task compose:logs         # View logs

# Release workflow
task release:patch        # Bump + build + update compose
```

---

## Testing Strategy

### Test Pyramid

```
                    ┌──────────┐
                    │   E2E    │  ← Few, slow, expensive
                    ├──────────┤
                 ┌──┴──────────┴──┐
                 │   CONTRACT     │  ← Balance: fast + reliable
                 ├────────────────┤
           ┌─────┴────────────────┴─────┐
           │        INTEGRATION         │  
           ├────────────────────────────┤
     ┌─────┴────────────────────────────┴─────┐
     │               UNIT                     │  ← Many, fast, cheap
     └────────────────────────────────────────┘
```

### Test Types

| Type | Location | Dependencies | Speed |
|------|----------|--------------|-------|
| Unit | `internal/*_test.go` | None | Fast |
| Integration | `internal/db/*_test.go` | MongoDB | Medium |
| Contract | `contracts/consumer/` | None (mock) | Fast |
| E2E | `tests/e2e/` | All services | Slow |

### Running Tests

#### Unit Tests

```bash
# Single service
cd services/booking
go test -v -short ./...

# All services
go test -short ./services/*/internal/...

# With coverage
go test -cover -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

#### Integration Tests

Require MongoDB running:

```bash
# Start MongoDB
docker compose -f platform/deploy/docker-compose/docker-compose.yml up -d mongo1 mongo2 mongo3

# Set test URI
export MONGODB_TEST_URI="mongodb://localhost:27017"

# Run integration tests
go test -v -tags=integration ./services/booking/internal/db/...
```

#### Contract Tests

```bash
# Consumer tests (generate contracts)
cd services/booking
go test -v ./contracts/consumer/...

# Provider verification
cd services/payment
PACT_PROVIDER_VERIFICATION=true \
PROVIDER_URL=http://localhost:3001 \
go test -v ./contracts/provider/...
```

#### E2E Tests

The E2E test suite validates the complete booking flow across all 8 microservices.

```bash
# Run full E2E test suite (recommended)
task test:e2e

# This command:
# 1. Cleans up previous test containers and volumes
# 2. Starts all services with fresh data
# 3. Waits for all 8 services to be healthy
# 4. Runs the test suite
# 5. Cleans up after completion
```

**E2E Test Flow:**

1. **User Registration** - Creates user in user-service
2. **Browse Movies** - Retrieves movie catalog from movie-service
3. **Select Showtime** - Gets available showtimes from showtime-service
4. **View Seat Map** - Checks seat availability from seat-service
5. **Hold Seats** - Reserves seats temporarily (5 min TTL)
6. **Create Booking** - SAGA orchestration through booking-service:
   - Validates showtime exists
   - Verifies seat hold is active
   - Processes payment (mock mode for testing)
   - Confirms seat reservation
   - Creates ticket
   - Sends notification
7. **Verify Booking** - Retrieves booking by order ID
8. **Verify Notification** - Confirms notification service health
9. **Concurrent Hold Test** - Race condition prevention (409 on duplicate)
10. **Hold Expiration** - Skipped (requires waiting for TTL)

**Important:** E2E tests use strict assertions - no graceful degradation.
All critical steps must succeed for tests to pass.

### Test Commands (Taskfile)

```bash
# Unit tests
task test:unit SERVICE=booking
task test:unit:all

# Integration tests
task test:integration

# Contract tests
task test:contract

# E2E tests
task test:e2e

# Full pipeline
task test:pipeline

# CI mode (with JUnit output)
task test:ci
```

### Coverage Requirements

| Type | Target | Enforcement |
|------|--------|-------------|
| Unit | 70%+ | CI fails below |
| Integration | 50%+ | Warning below |
| Overall | 60%+ | CI fails below |

Generate coverage report:

```bash
task coverage
open coverage/coverage.html
```

### Writing Tests

#### Unit Test Example

```go
func TestBookingService_Create(t *testing.T) {
    // Arrange
    mockPayment := &MockPaymentClient{}
    mockSeat := &MockSeatClient{}
    service := NewBookingService(mockPayment, mockSeat)
    
    // Act
    booking, err := service.Create(BookingRequest{
        ShowtimeID: "sht_123",
        Seats:      []string{"A1", "A2"},
        Payment:    450,
    })
    
    // Assert
    assert.NoError(t, err)
    assert.NotEmpty(t, booking.OrderID)
    assert.Equal(t, "confirmed", booking.Status)
}
```

#### Table-Driven Test Example

```go
func TestPayment_Validation(t *testing.T) {
    tests := []struct {
        name    string
        request PaymentRequest
        wantErr bool
        errCode string
    }{
        {
            name:    "valid payment",
            request: PaymentRequest{Amount: 100, Currency: "mxn"},
            wantErr: false,
        },
        {
            name:    "zero amount",
            request: PaymentRequest{Amount: 0, Currency: "mxn"},
            wantErr: true,
            errCode: "INVALID_AMOUNT",
        },
        {
            name:    "negative amount",
            request: PaymentRequest{Amount: -100, Currency: "mxn"},
            wantErr: true,
            errCode: "INVALID_AMOUNT",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := tt.request.Validate()
            if tt.wantErr {
                assert.Error(t, err)
                assert.Contains(t, err.Error(), tt.errCode)
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

---

## Code Style

### Go Style

Follow standard Go conventions:

- `gofmt` for formatting
- `golangci-lint` for linting
- Effective Go guidelines

```bash
# Format code
gofmt -w .

# Lint
golangci-lint run ./...

# With Taskfile
task lint:go
task fmt:all
```

### Linter Configuration

`.golangci.yml`:

```yaml
run:
  timeout: 5m

linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - gofmt
    - goimports

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck
```

### Naming Conventions

| Item | Convention | Example |
|------|------------|---------|
| Package | lowercase, no underscores | `booking`, `api` |
| File | snake_case | `booking_service.go` |
| Exported func | PascalCase | `CreateBooking` |
| Unexported func | camelCase | `validateRequest` |
| Interface | Verb suffix | `BookingCreator` |
| Struct | Noun | `BookingService` |
| Constant | ALL_CAPS | `MAX_RETRIES` |

### Error Handling

```go
// Use errors.New for simple errors
if amount <= 0 {
    return errors.New("amount must be positive")
}

// Use fmt.Errorf for context
if err != nil {
    return fmt.Errorf("failed to process payment: %w", err)
}

// Custom error types for specific handling
type ValidationError struct {
    Field   string
    Message string
}

func (e ValidationError) Error() string {
    return fmt.Sprintf("validation failed: %s - %s", e.Field, e.Message)
}
```

---

## Contributing

### Workflow

1. **Fork** the repository
2. **Create branch** from `main`: `git checkout -b feature/my-feature`
3. **Make changes** following style guide
4. **Run tests**: `task test:pipeline`
5. **Commit** using conventional commits
6. **Push** and create Pull Request

### Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructure
- `test`: Adding tests
- `chore`: Maintenance

Examples:

```bash
feat(booking): add seat validation before payment
fix(payment): handle Stripe timeout correctly
docs(api): update OpenAPI spec for payment service
test(seat): add concurrency tests for holds
```

### Pull Request Checklist

- [ ] Code follows style guide
- [ ] Tests pass: `task test:pipeline`
- [ ] Coverage meets threshold
- [ ] Documentation updated if needed
- [ ] OpenAPI spec updated if API changed
- [ ] No secrets or credentials committed
- [ ] Conventional commit messages

### Code Review

- At least 1 approval required
- CI must pass
- No merge conflicts
- Squash and merge preferred

---

## Troubleshooting

### MongoDB Connection Failed

```bash
# Check MongoDB is running
docker ps | grep mongo

# Check replica set status
docker exec mongo1 mongosh --eval "rs.status()"

# Restart replica set
docker compose -f platform/deploy/docker-compose/docker-compose.yml restart
```

### Tests Timeout

```bash
# Increase timeout
go test -timeout 60s ./...

# Skip slow tests
go test -short ./...
```

### Docker Build Fails

```bash
# Clean Docker cache
docker builder prune -f

# Rebuild with no cache
docker build --no-cache -f platform/docker/go-service/Dockerfile .
```

### Go Module Issues

```bash
# Reset go.sum
rm go.sum
go mod tidy

# Clear module cache
go clean -modcache
```

---

## Related Documentation

- [Architecture Overview](../architecture/README.md)
- [Services Documentation](../services/README.md)
- [API Documentation](../api/README.md)
- [Operations Guide](../operations/README.md)
