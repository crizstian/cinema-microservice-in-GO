# API Documentation - Cinema Ticketing System

> **AI Agent Context**: This document describes the API design philosophy, OpenAPI specifications, and contract testing strategy. All services have OpenAPI specs in `/services/{name}/api/openapi.yaml`.

**Last Updated**: 2026-04-08  
**API Version**: v1  
**Spec Format**: OpenAPI 3.0.3

---

## Table of Contents

1. [API Design Principles](#api-design-principles)
2. [OpenAPI Specifications](#openapi-specifications)
3. [Contract Testing](#contract-testing)
4. [API Reference](#api-reference)
5. [Authentication](#authentication)
6. [Error Handling](#error-handling)

---

## API Design Principles

### Spec-Driven Development (SDD)

We follow **Contract-First** development:

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Design    │───▶│  Validate   │───▶│ Implement   │───▶│   Test      │
│  OpenAPI    │    │  Spectral   │    │  Handlers   │    │  Contracts  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### RESTful Conventions

| Convention | Example |
|------------|---------|
| **Resource naming** | `/movies`, `/bookings/{id}` |
| **Plural nouns** | `/users`, not `/user` |
| **HTTP verbs** | GET (read), POST (create), PUT (update), DELETE |
| **Nested resources** | `/cinemas/{id}/rooms` |
| **Query filters** | `/showtimes?movie_id=xxx&date=2024-01-15` |

### Versioning Strategy

- **URL path versioning**: `/api/v1/movies`
- **Current version**: v1
- **Breaking changes**: New version (`/api/v2/`)
- **Deprecation**: 6-month notice

---

## OpenAPI Specifications

### Specification Locations

| Service | Spec Location | Status |
|---------|---------------|--------|
| movie | [/services/movie/api/openapi.yaml](../../services/movie/api/openapi.yaml) | Production |
| booking | [/services/booking/api/openapi.yaml](../../services/booking/api/openapi.yaml) | Production |
| payment | [/services/payment/api/openapi.yaml](../../services/payment/api/openapi.yaml) | Production |
| notification | [/services/notification/api/openapi.yaml](../../services/notification/api/openapi.yaml) | Production |
| user | [/services/user/api/openapi.yaml](../../services/user/api/openapi.yaml) | Planned |
| cinema | [/services/cinema/api/openapi.yaml](../../services/cinema/api/openapi.yaml) | Planned |
| showtime | [/services/showtime/api/openapi.yaml](../../services/showtime/api/openapi.yaml) | Planned |
| seat | [/services/seat/api/openapi.yaml](../../services/seat/api/openapi.yaml) | Planned |

### Validation

We use **Spectral** for OpenAPI linting:

```bash
# Validate single spec
spectral lint services/movie/api/openapi.yaml

# Validate all specs
spectral lint services/*/api/openapi.yaml

# With Taskfile
task lint:openapi
```

### Spectral Rules

Configuration in `/.spectral.yaml`:

```yaml
extends: spectral:oas
rules:
  operation-operationId: error
  operation-description: warn
  operation-tags: error
  oas3-schema: error
  info-contact: off
```

### Spec Structure

Each OpenAPI spec follows this structure:

```yaml
openapi: 3.0.3
info:
  title: Movie Service API
  version: 1.0.0
  description: |
    Movie catalog management service.
    
    ## Overview
    Provides read-only access to movie catalog.
    
    ## Authentication
    No authentication required for public endpoints.

servers:
  - url: http://localhost:8001
    description: Local development
  - url: https://api.cinema.example.com
    description: Production

tags:
  - name: Movies
    description: Movie catalog operations

paths:
  /movies/all:
    get:
      operationId: getAllMovies
      tags: [Movies]
      summary: List all movies
      responses:
        '200':
          description: Success
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Movie'

components:
  schemas:
    Movie:
      type: object
      required: [id, title]
      properties:
        id:
          type: string
          example: "mov_abc123"
        title:
          type: string
          example: "Dune Part Two"
```

---

## Contract Testing

### Why Contract Testing?

| Problem | Solution |
|---------|----------|
| Integration breaks in production | Catch at build time |
| E2E tests are slow | Fast unit-level verification |
| API changes break consumers | Consumer defines expectations |
| No documentation of expectations | Contracts are living docs |

### Consumer-Driven Contracts (Pact)

We use **Pact** for contract testing between services.

#### Contract Matrix

| Consumer | Provider | Interactions | Contract File |
|----------|----------|--------------|---------------|
| booking | payment | makePurchase, refund, invalid amount | booking-service-payment-service.json |
| booking | seat | verifyHold, reserveSeats, releaseHold | booking-service-seat-service.json |
| booking | showtime | getShowtime, listShowtimes | booking-service-showtime-service.json |
| booking | notification | sendEmail | booking-service-notification-service.json |

#### Contract Test Locations

```
services/booking/contracts/
├── consumer/
│   ├── payment_consumer_test.go
│   ├── seat_consumer_test.go
│   ├── showtime_consumer_test.go
│   └── notification_consumer_test.go
└── provider/
    └── (verified by each provider service)

services/payment/contracts/
└── provider/
    └── payment_provider_test.go
```

### Running Contract Tests

#### Consumer Tests (Generate Contracts)

```bash
cd services/booking
go test -v ./contracts/consumer/...

# Output: contracts/*.json files
```

#### Provider Verification

```bash
cd services/payment

# Start service
go run cmd/payment/main.go &

# Verify contracts
PACT_PROVIDER_VERIFICATION=true \
PROVIDER_URL=http://localhost:3001 \
go test -v ./contracts/provider/...
```

### Contract Interactions

#### Example: Payment Contract

**Consumer Expectation (booking-service)**:

```go
// Consumer test defines what booking expects from payment
err = mockProvider.
    AddInteraction().
    Given("a valid credit card").
    UponReceiving("a request to process payment").
    WithRequest("POST", "/payment/makePurchase", func(b *consumer.V2RequestBuilder) {
        b.Header("Content-Type", matchers.String("application/json"))
        b.JSONBody(matchers.MapMatcher{
            "userName":    matchers.String("John Doe"),
            "currency":    matchers.String("mxn"),
            "number":      matchers.Regex("4242424242424242", `^\d{16}$`),
            "amount":      matchers.Integer(450),
            "description": matchers.Like("Ticket purchase"),
        })
    }).
    WillRespondWith(201, func(b *consumer.V2ResponseBuilder) {
        b.JSONBody(map[string]interface{}{
            "user":   "John Doe",
            "amount": 450,
            "charge": map[string]interface{}{
                "id":     "ch_test123",
                "status": "succeeded",
            },
        })
    })
```

**Provider Verification (payment-service)**:

```go
// Provider verifies it meets the contract
verifier := provider.NewVerifier()
verifier.VerifyProvider(t, provider.VerifyRequest{
    Provider:        "payment-service",
    ProviderBaseURL: "http://localhost:3001",
    PactFiles:       []string{"../../contracts/booking-service-payment-service.json"},
    StateHandlers: map[string]models.StateHandler{
        "a valid credit card": func() error {
            // Setup test data
            return nil
        },
    },
})
```

### CI/CD Integration (Harness)

Contract tests run in the Harness CI pipeline:

```yaml
- stage:
    name: Contract Tests
    type: CI
    spec:
      execution:
        steps:
          - step:
              type: RunTests
              name: Consumer Contract Tests
              spec:
                language: Go
                buildTool: Go
                args: "-v ./contracts/consumer/..."
                packages: ./services/booking/contracts/consumer
                runOnlySelectedTests: true  # Test Intelligence
                reports:
                  type: JUnit
                  spec:
                    paths:
                      - "**/*-junit.xml"
```

See [Operations Guide](../operations/README.md) for full pipeline configuration.

---

## API Reference

### Endpoints Summary

#### Movie Service (Port 8001)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/movies/all` | List all movies |
| GET | `/movies/premieres` | Get recent releases |
| GET | `/movies/:id` | Get movie by ID |

#### Booking Service (Port 8000)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/booking/` | Create booking |
| GET | `/booking/:orderId` | Get booking |

#### Payment Service (Port 8002)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/payment/makePurchase` | Process payment |
| GET | `/payment/:id` | Get payment |
| POST | `/payment/:id/refund` | Process refund |

#### Notification Service (Port 8003)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/notification/sendEmail` | Send email |
| POST | `/notification/sendSMS` | Send SMS (stub) |

#### User Service (Port 8004) - Planned

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users/register` | Register user |
| POST | `/users/login` | Login |
| GET | `/users/me` | Get profile |
| PUT | `/users/me` | Update profile |

#### Cinema Service (Port 8005) - Planned

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/cinemas` | List cinemas |
| GET | `/cinemas/:id` | Get cinema |
| GET | `/cinemas/:id/rooms` | Get rooms |

#### Showtime Service (Port 8006) - Planned

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/showtimes` | List showtimes |
| GET | `/showtimes/:id` | Get showtime |

#### Seat Service (Port 8007) - Planned

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/seats/availability` | Get seat map |
| POST | `/seats/hold` | Hold seats |
| DELETE | `/seats/hold/:holdId` | Release hold |
| POST | `/seats/reserve` | Confirm reservation |

---

## Authentication

### Current State

Currently, services are **not authenticated** (MVP phase).

### Planned Authentication

Using **JWT Bearer tokens** from user-service:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

JWT Payload:

```json
{
  "sub": "usr_abc123",
  "email": "user@example.com",
  "membership": "regular",
  "iat": 1705312200,
  "exp": 1705315800
}
```

### API Gateway Validation

Kong/Traefik will validate JWTs at the edge:

```yaml
# Kong plugin configuration
plugins:
  - name: jwt
    config:
      uri_param_names: []
      claims_to_verify:
        - exp
      key_claim_name: iss
```

---

## Error Handling

### Standard Error Response

All services return errors in consistent format:

```json
{
  "type": "validation_error",
  "message": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "amount",
    "constraint": "must be greater than 0"
  },
  "request_id": "req_abc123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Error Types

| Type | HTTP Code | Description |
|------|-----------|-------------|
| `validation_error` | 400 | Invalid input |
| `authentication_error` | 401 | Missing/invalid token |
| `authorization_error` | 403 | Insufficient permissions |
| `not_found` | 404 | Resource doesn't exist |
| `conflict` | 409 | Resource state conflict |
| `rate_limit_exceeded` | 429 | Too many requests |
| `internal_error` | 500 | Server error |
| `service_unavailable` | 503 | Dependency down |

### Error Codes by Service

#### Payment Service

| Code | Description |
|------|-------------|
| `INVALID_CARD` | Card validation failed |
| `PAYMENT_DECLINED` | Payment was declined |
| `INSUFFICIENT_FUNDS` | Card has insufficient funds |
| `INVALID_AMOUNT` | Amount must be > 0 |

#### Seat Service

| Code | Description |
|------|-------------|
| `SEAT_NOT_AVAILABLE` | Seat already held/reserved |
| `HOLD_EXPIRED` | Hold has expired |
| `HOLD_NOT_FOUND` | Hold ID doesn't exist |
| `INVALID_SHOWTIME` | Showtime doesn't exist |

---

## Related Documentation

- [Architecture Overview](../architecture/README.md)
- [Services Documentation](../services/README.md)
- [Contract Testing Details](./contracts.md)
- [Development Guide](../development/README.md)

---

## External Resources

- [OpenAPI Specification](https://spec.openapis.org/oas/v3.0.3)
- [Spectral Linter](https://stoplight.io/open-source/spectral)
- [Pact Documentation](https://docs.pact.io/)
- [REST API Design Guidelines](https://restfulapi.net/)
