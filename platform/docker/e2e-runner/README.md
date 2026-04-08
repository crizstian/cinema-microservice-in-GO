# E2E Test Runner

Dockerfile for running end-to-end integration tests against the cinema microservices.

## Usage

This container is used by the `test:e2e` task:

```bash
task test:e2e
```

Or manually via docker-compose:

```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile test --profile e2e run --rm e2e-runner
```

## How It Works

1. Builds from `golang:1.24-alpine`
2. Copies test files from `tests/integration/`
3. Runs `go test -v -timeout 5m ./...`
4. Connects to services via Docker network hostnames

## Environment Variables

Set automatically by docker-compose:

| Variable | Value |
|----------|-------|
| `USER_SERVICE_URL` | `http://user:8004` |
| `MOVIE_SERVICE_URL` | `http://movie:8000` |
| `CINEMA_SERVICE_URL` | `http://cinema:8085` |
| `SHOWTIME_SERVICE_URL` | `http://showtime:3003` |
| `SEAT_SERVICE_URL` | `http://seat:3004` |
| `PAYMENT_SERVICE_URL` | `http://payment:8000` |
| `BOOKING_SERVICE_URL` | `http://booking:8082` |
| `NOTIFICATION_SERVICE_URL` | `http://notification:8000` |

## Test Suite

The E2E tests verify the complete booking flow:

1. User registration
2. Browse movies
3. Select showtime
4. View seat map
5. Hold seats
6. Create booking with payment
7. Verify booking
8. Notification service health

See: [tests/integration/](../../../tests/integration/)
