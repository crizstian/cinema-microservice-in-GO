# E2E Integration Tests - Cinema Booking System

End-to-end integration tests for the complete cinema booking flow.

## Quick Start

```bash
# Run full E2E test suite
task test:e2e
```

This command:
1. Starts test infrastructure (MongoDB, Redis, NATS)
2. Initializes MongoDB replica set
3. Starts all 8 microservices
4. Runs the E2E test suite
5. Cleans up containers

## Test Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         COMPLETE BOOKING FLOW                                 │
└──────────────────────────────────────────────────────────────────────────────┘

  Step 1: Register/Login           Step 2: Browse Movies        Step 3: Select Showtime
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │   user-service  │              │  movie-service  │          │showtime-service │
  │   POST /users/  │              │  GET /movies    │          │ GET /showtimes  │
  │    register     │              │                 │          │  ?movie_id=X    │
  └────────┬────────┘              └────────┬────────┘          └────────┬────────┘
           │                                │                            │
           ▼                                ▼                            ▼
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │  Access Token   │              │  List of movies │          │  Available      │
  │  (JWT)          │              │                 │          │  showtimes      │
  └─────────────────┘              └─────────────────┘          └─────────────────┘

  Step 4: View Seat Map            Step 5: Hold Seats          Step 6: Create Booking
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │  seat-service   │              │  seat-service   │          │ booking-service │
  │ GET /seats/     │              │ POST /seats/    │          │ POST /booking   │
  │  availability   │              │    hold         │          │  (SAGA)         │
  └────────┬────────┘              └────────┬────────┘          └────────┬────────┘
           │                                │                            │
           ▼                                ▼                            ▼
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │  Seat map with  │              │   hold_id       │          │  Ticket with    │
  │  availability   │              │   (TTL: 5 min)  │          │  confirmation   │
  └─────────────────┘              └─────────────────┘          └─────────────────┘
```

## Project Structure

```
tests/integration/
├── e2e_booking_test.go      # E2E test suite
├── go.mod                   # Go module
├── go.sum
└── README.md

# Dockerfile is centralized at:
platform/docker/e2e-runner/Dockerfile
```

## Test Cases

### TestE2ESuite (Complete Flow)

| Test | Description |
|------|-------------|
| `Test01_UserRegistration` | Register user and login |
| `Test02_BrowseMovies` | List movies in cartelera |
| `Test03_SelectShowtime` | Select available showtime |
| `Test04_ViewSeatMap` | View seat availability |
| `Test05_HoldSeats` | Hold seats temporarily (5 min TTL) |
| `Test06_CreateBooking` | Create booking with payment |
| `Test07_VerifyBooking` | Verify ticket created |
| `Test08_VerifyNotification` | Verify notification service |
| `Test09_ConcurrentSeatHolds` | Prevent double booking |
| `Test10_HoldExpiration` | Hold expiration (placeholder) |

### TestHealthChecks

Standalone test that verifies all 8 services are responding.

## Services

| Service | Port | Description |
|---------|------|-------------|
| user | 8004 | Authentication and profiles |
| movie | 8000 | Movie catalog |
| cinema | 8085 | Cinema locations |
| showtime | 3003 | Show schedules |
| seat | 3004 | Seat inventory and holds |
| payment | 8001 | Payment processing (Stripe mock) |
| booking | 8082 | SAGA orchestrator |
| notification | 8002 | Email notifications (mock) |

## Environment Variables

The test runner receives these from docker-compose:

```bash
USER_SERVICE_URL=http://user:8004
MOVIE_SERVICE_URL=http://movie:8000
CINEMA_SERVICE_URL=http://cinema:8085
SHOWTIME_SERVICE_URL=http://showtime:3003
SEAT_SERVICE_URL=http://seat:3004
PAYMENT_SERVICE_URL=http://payment:8000
BOOKING_SERVICE_URL=http://booking:8082
NOTIFICATION_SERVICE_URL=http://notification:8000
```

## Manual Execution

```bash
# Start test environment manually
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test up -d

# Wait for services
sleep 30

# Run tests from host (requires services to be port-forwarded)
cd tests/integration
go test -v ./...

# Or run via container
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test --profile e2e run --rm e2e-runner

# Cleanup
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test down -v
```

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
# Check replica set status
docker exec test-mongo mongosh --eval "rs.status()"
```

### Test failures

The test output shows detailed logs for each step. Common issues:

- **Service not available**: Wait longer for startup or check logs
- **Seat hold conflict**: Previous test run left stale data
- **Connection refused**: Service crashed, check logs

## Extending Tests

Add new test cases to `e2e_booking_test.go`:

```go
func (s *E2ETestSuite) Test11_MyNewTest() {
    s.T().Log("Step 11: My New Test")

    resp, err := s.get(SomeServiceURL+"/endpoint", s.accessToken)
    require.NoError(s.T(), err)
    defer resp.Body.Close()

    assert.Equal(s.T(), http.StatusOK, resp.StatusCode)
}
```

## Related

- [Docker Compose](../../platform/deploy/docker-compose/)
- [E2E Runner Dockerfile](../../platform/docker/e2e-runner/)
- [Taskfile.yml](../../Taskfile.yml)
