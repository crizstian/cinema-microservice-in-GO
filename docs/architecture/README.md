# Architecture - Cinema Ticketing System

> **AI Agent Context**: This document describes the complete system architecture, service interactions, and design decisions. For implementation details of specific services, see [Services Documentation](../services/README.md).

**Last Updated**: 2026-04-17  
**Architecture Version**: 3.0 (Polyglot)

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Service Architecture](#service-architecture)
3. [Data Flow](#data-flow)
4. [Communication Patterns](#communication-patterns)
5. [Database Design](#database-design)
6. [Architecture Decision Records](#architecture-decision-records)

---

## System Overview

### Purpose

The Cinema Ticketing System enables users to:
- Browse movie catalogs and showtimes
- Select seats with real-time availability
- Process secure payments
- Receive confirmation notifications

### Architecture Style

**Polyglot Microservices with Event-Driven Communication**

- **Languages**: Go (core platform), Java 21 (business intelligence)
- **Java Frameworks**: Spring Boot 3.2, Quarkus 3.x, Micronaut 4.x
- **Synchronous**: HTTP/REST for user-facing operations
- **Asynchronous**: NATS JetStream for notifications and compensation
- **State Management**: MongoDB for persistence, Redis for temporary holds

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                 CINEMA TICKETING SYSTEM                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              EDGE LAYER                                          │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │                         API Gateway (Kong/Traefik)                         │  │   │
│  │  │  - JWT Validation    - Rate Limiting    - Request Routing                 │  │   │
│  │  │  - CORS              - Load Balancing   - API Versioning                  │  │   │
│  │  └───────────────────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                          │                                              │
│  ┌───────────────────────────────────────┼─────────────────────────────────────────┐   │
│  │                          SERVICE LAYER│                                          │   │
│  │                                       ▼                                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │   │
│  │  │    user     │  │   movie     │  │   cinema    │  │  showtime   │             │   │
│  │  │   :8004     │  │   :8001     │  │   :8005     │  │   :8006     │             │   │
│  │  │             │  │             │  │             │  │             │             │   │
│  │  │ - Register  │  │ - List all  │  │ - List      │  │ - List by   │             │   │
│  │  │ - Login     │  │ - Premieres │  │ - Rooms     │  │   movie     │             │   │
│  │  │ - Profile   │  │ - By ID     │  │ - Details   │  │ - By cinema │             │   │
│  │  │ - JWT       │  │             │  │             │  │ - CRUD      │             │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │   │
│  │         │                │                │                │                     │   │
│  │         ▼                ▼                ▼                ▼                     │   │
│  │     MongoDB          MongoDB          MongoDB          MongoDB                   │   │
│  │      users            movies       cinemas/rooms       showtimes                 │   │
│  │                                                                                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                              │   │
│  │  │    seat     │  │   booking   │  │   payment   │                              │   │
│  │  │   :8007     │  │   :8000     │  │   :8002     │                              │   │
│  │  │             │  │             │  │             │                              │   │
│  │  │ - Availab.  │  │ - Create    │  │ - Charge    │                              │   │
│  │  │ - Hold      │  │ - Get       │  │ - Refund    │                              │   │
│  │  │ - Reserve   │  │ - Cancel    │  │ - Get       │                              │   │
│  │  │ - Layout    │  │ - History   │  │             │                              │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘                              │   │
│  │         │                │                │                                      │   │
│  │    ┌────┴────┐           ▼                ▼                                      │   │
│  │    ▼         ▼       MongoDB          MongoDB ──────▶ Stripe API                │   │
│  │  Redis    MongoDB     booking          payment                                   │   │
│  │  (holds)  (seats)                                                                │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                          │                                              │
│  ┌───────────────────────────────────────┼──────────────────────────────────────────┐  │
│  │                      MESSAGING LAYER  │                                           │  │
│  │                                       ▼                                           │  │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐   │  │
│  │  │                         RabbitMQ                                          │   │  │
│  │  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                    │   │  │
│  │  │   │ booking.    │   │notification.│   │  seat.      │                    │   │  │
│  │  │   │ created     │   │ email       │   │  expired    │                    │   │  │
│  │  │   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘                    │   │  │
│  │  └──────────┼─────────────────┼─────────────────┼────────────────────────────┘   │  │
│  │             │                 │                 │                                 │  │
│  │             ▼                 ▼                 ▼                                 │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐│  │
│  │  │                        notification :8003                                    ││  │
│  │  │   - Email (Gmail SMTP)   - SMS (Twilio)   - Push (future)                   ││  │
│  │  └─────────────────────────────────────────────────────────────────────────────┘│  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                          │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                           OBSERVABILITY LAYER                                     │  │
│  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │  │
│  │   │ Prometheus  │   │  Grafana    │   │   Jaeger    │   │    ELK      │          │  │
│  │   │  (metrics)  │   │ (dashboards)│   │  (tracing)  │   │   (logs)    │          │  │
│  │   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘          │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Service Architecture

### Service Catalog

#### Go Services (Core Platform)

| Service | Type | Dependencies | Database | Status |
|---------|------|--------------|----------|--------|
| **user** | Authentication | - | MongoDB (users) | Planned |
| **movie** | Catalog | - | MongoDB (movies) | Production |
| **cinema** | Catalog | - | MongoDB (cinemas) | Planned |
| **showtime** | Scheduling | movie, cinema | MongoDB (showtimes) | Planned |
| **seat** | Inventory | showtime | MongoDB + Redis | Planned |
| **booking** | Orchestration | seat, payment, notification, showtime | MongoDB (booking) | Production |
| **payment** | Transaction | Stripe API | MongoDB (payment) | Production |
| **notification** | Messaging | Gmail, Twilio | - | Production |

#### Java Services (Business Intelligence)

| Service | Framework | Build | Port | Purpose | Status |
|---------|-----------|-------|------|---------|--------|
| **analytics** | Spring Boot 3.2 | Maven | 8010 | Reports, sales metrics, BI dashboards | Development |
| **loyalty** | Quarkus 3.x | Maven | 8011 | Points program, tiers, rewards | Development |
| **reviews** | Micronaut 4.x | Gradle | 8012 | Movie reviews, ratings, statistics | Development |

> **Note**: Java services use package domain `dev.cinema.latam.*` following Java naming conventions.

### Service Responsibilities

#### Catalog Layer (Read-Heavy)

```
┌─────────────────────────────────────────────────────────────────┐
│                       CATALOG SERVICES                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  user-service          movie-service        cinema-service      │
│  ┌─────────────┐       ┌─────────────┐      ┌─────────────┐    │
│  │ • Register  │       │ • List all  │      │ • List by   │    │
│  │ • Login     │       │ • Premieres │      │   city      │    │
│  │ • Profile   │       │ • By ID     │      │ • Rooms     │    │
│  │ • JWT auth  │       │ • Search    │      │ • Amenities │    │
│  └─────────────┘       └─────────────┘      └─────────────┘    │
│         │                    │                    │              │
│         └────────────────────┼────────────────────┘              │
│                              │                                   │
│                              ▼                                   │
│                    showtime-service                              │
│                    ┌─────────────┐                               │
│                    │ • By movie  │                               │
│                    │ • By cinema │                               │
│                    │ • By date   │                               │
│                    │ • Pricing   │                               │
│                    └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

#### Transaction Layer (Write-Heavy)

```
┌─────────────────────────────────────────────────────────────────┐
│                    TRANSACTION SERVICES                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│     seat-service           booking-service                       │
│     ┌─────────────┐        ┌─────────────┐                      │
│     │ • Check     │        │ • Create    │                      │
│     │   availab.  │◄──────▶│   booking   │                      │
│     │ • Hold temp │        │ • Validate  │                      │
│     │ • Reserve   │        │ • Orchestr. │                      │
│     │ • Release   │        │ • Compensate│                      │
│     └─────────────┘        └──────┬──────┘                      │
│           │                       │                              │
│           │                       │                              │
│           ▼                       ▼                              │
│     ┌─────────────┐        ┌─────────────┐                      │
│     │   Redis     │        │  payment-   │                      │
│     │   (holds)   │        │  service    │                      │
│     │   TTL: 5min │        │ • Charge    │                      │
│     └─────────────┘        │ • Refund    │                      │
│                            └─────────────┘                      │
│                                   │                              │
│                                   ▼                              │
│                            ┌─────────────┐                      │
│                            │ Stripe API  │                      │
│                            └─────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Ticket Purchase Flow (Happy Path)

```
┌──────┐     ┌───────┐    ┌──────┐   ┌────────┐   ┌──────┐   ┌───────┐   ┌───────┐   ┌────────┐
│Client│     │Gateway│    │ User │   │Showtime│   │ Seat │   │Booking│   │Payment│   │Notific.│
└──┬───┘     └───┬───┘    └──┬───┘   └───┬────┘   └──┬───┘   └───┬───┘   └───┬───┘   └───┬────┘
   │             │           │           │           │           │           │           │
   │ 1. Login    │           │           │           │           │           │           │
   │────────────▶│           │           │           │           │           │           │
   │             │──────────▶│           │           │           │           │           │
   │             │◀──────────│           │           │           │           │           │
   │◀────────────│ JWT Token │           │           │           │           │           │
   │             │           │           │           │           │           │           │
   │ 2. Get Showtimes        │           │           │           │           │           │
   │────────────▶│───────────────────────▶           │           │           │           │
   │◀────────────│◀───────────────────────           │           │           │           │
   │  (list)     │           │           │           │           │           │           │
   │             │           │           │           │           │           │           │
   │ 3. Get Seat Availability│           │           │           │           │           │
   │────────────▶│───────────────────────────────────▶           │           │           │
   │◀────────────│◀───────────────────────────────────           │           │           │
   │  (seat map) │           │           │           │           │           │           │
   │             │           │           │           │           │           │           │
   │ 4. Hold Seats (A1, A2)  │           │           │           │           │           │
   │────────────▶│───────────────────────────────────▶           │           │           │
   │             │           │           │    ┌──────┴──────┐    │           │           │
   │             │           │           │    │ Redis SET   │    │           │           │
   │             │           │           │    │ TTL=5min    │    │           │           │
   │             │           │           │    └──────┬──────┘    │           │           │
   │◀────────────│◀───────────────────────────────────           │           │           │
   │ hold_id,    │           │           │  expires_at          │           │           │
   │ expires_at  │           │           │           │           │           │           │
   │             │           │           │           │           │           │           │
   │ 5. Create Booking (with hold_id, payment info)  │           │           │           │
   │────────────▶│───────────────────────────────────────────────▶           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │    5a. Validate Hold  │           │           │
   │             │           │           │◀──────────│           │           │           │
   │             │           │           │──────────▶│           │           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │           │  5b. Charge│           │           │
   │             │           │           │           │──────────▶│           │           │
   │             │           │           │           │◀──────────│           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │  5c. Confirm Reserve  │           │           │
   │             │           │           │◀──────────│           │           │           │
   │             │           │           │──────────▶│           │           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │           │  5d. Notify (async)   │           │
   │             │           │           │           │──────────────────────▶│           │
   │             │           │           │           │           │           │──────────▶│
   │             │           │           │           │           │           │   Email   │
   │             │           │           │           │           │           │◀──────────│
   │◀────────────│◀───────────────────────────────────────────────           │           │
   │  Ticket +   │           │           │           │           │           │           │
   │  Receipt    │           │           │           │           │           │           │
```

### Compensation Flow (Payment Fails)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        BOOKING SAGA - COMPENSATION                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   STEP 1-3: Normal Flow                                                      │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐                              │
│   │ Validate │───▶│  Validate│───▶│  Process │──X (PAYMENT FAILED)          │
│   │  Showtime│    │   Hold   │    │  Payment │                              │
│   └──────────┘    └────┬─────┘    └──────────┘                              │
│                        │                                                     │
│   STEP 4: Compensation │                                                     │
│                        │                                                     │
│                        │ ROLLBACK                                            │
│                        ▼                                                     │
│                   ┌──────────┐                                              │
│                   │ Release  │◀─── Event: payment.failed                     │
│                   │   Hold   │                                              │
│                   └──────────┘                                              │
│                        │                                                     │
│                        ▼                                                     │
│                   ┌──────────┐                                              │
│                   │  Return  │                                              │
│                   │  Error   │                                              │
│                   └──────────┘                                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Communication Patterns

### Synchronous (HTTP/REST)

Used for:
- User-facing API requests
- Real-time operations (seat holds)
- Operations requiring immediate confirmation

| From | To | Endpoint | Timeout | Retries |
|------|-----|----------|---------|---------|
| Gateway | All services | Various | 5-30s | 1-3 |
| booking | showtime | `GET /showtimes/{id}` | 3s | 2 |
| booking | seat | `POST /seats/hold` | 3s | 2 |
| booking | seat | `POST /seats/reserve` | 3s | 2 |
| booking | payment | `POST /payment/makePurchase` | 30s | 1 |

### Asynchronous (RabbitMQ)

Used for:
- Notifications (email, SMS)
- Compensation events
- Non-critical operations

| Event | Producer | Consumer(s) | Purpose |
|-------|----------|-------------|---------|
| `booking.created` | booking | notification | Send confirmation |
| `booking.cancelled` | booking | notification, payment | Notify + refund |
| `payment.failed` | payment | seat | Release hold |
| `seat.hold.expired` | Redis TTL | seat | Cleanup |

### Event Schema

```json
{
  "event_type": "booking.created",
  "event_id": "evt_abc123",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0",
  "data": {
    "booking_id": "bkg_xyz789",
    "user_id": "usr_123",
    "showtime_id": "sht_456",
    "seats": ["A1", "A2"],
    "total_amount": 450,
    "payment_id": "ch_stripe123"
  }
}
```

---

## Database Design

### MongoDB Collections

| Database | Collection | Service | Indexes |
|----------|------------|---------|---------|
| `cinema_users` | users | user | email (unique), phone |
| `cinema_movies` | movies | movie | title, releaseDate |
| `cinema_cinemas` | cinemas, rooms | cinema | city, cinema_id |
| `cinema_showtimes` | showtimes | showtime | movie_id, cinema_id, start_time |
| `cinema_seats` | seats, reservations | seat | showtime_id, status |
| `cinema_booking` | bookings | booking | order_id (unique), user_id |
| `cinema_payment` | payments | payment | charge_id (unique), booking_id |

### Redis Keys

| Pattern | TTL | Purpose |
|---------|-----|---------|
| `seat:hold:{showtime_id}:{seat_id}` | 300s | Temporary seat hold |
| `session:{session_id}` | 3600s | User session |
| `rate:{ip}` | 60s | Rate limiting |

---

## Architecture Decision Records

### ADR-001: Synchronous Communication for Payment Flow

**Decision**: Use HTTP/REST for the payment flow.

**Context**: Payment requires immediate user feedback.

**Consequences**:
- Simpler error handling
- Higher coupling between services
- Requires circuit breakers

### ADR-002: Redis for Seat Holds

**Decision**: Use Redis with TTL for temporary seat holds.

**Context**: Need atomic operations with automatic expiration.

**Consequences**:
- Additional infrastructure component
- Excellent performance
- Built-in expiration

### ADR-003: RabbitMQ for Notifications

**Decision**: Use async messaging for notifications.

**Context**: Email sending should not block user response.

**Consequences**:
- Better user experience
- Notification may arrive after response
- Requires queue monitoring

### ADR-004: SAGA with Choreography

**Decision**: Use event-driven SAGA pattern.

**Context**: Need distributed transaction compensation.

**Consequences**:
- Lower coupling than orchestration
- Harder to debug (requires tracing)
- Requires idempotent handlers

### ADR-005: Spec-Driven Development

**Decision**: Design OpenAPI specs before implementation.

**Context**: Need contract consistency across teams.

**Consequences**:
- Higher initial investment
- Better documentation
- Enables contract testing

### ADR-006: dev:up vs test:e2e Environment Profiles

**Decision**: Separate Docker Compose profiles for development and testing.

**Context**: Need different configurations for local dev vs CI/CD.

**Details**: [ADR-006](./adr/ADR-006-dev-up-vs-test-e2e.md)

### ADR-007: CI/CD Pipeline Chaining for Monorepo

**Decision**: Use orchestrator + child pipeline pattern for CI/CD.

**Context**: Need scalable CI/CD that supports thousands of services without N triggers.

**Details**: [CI/CD Monorepo Strategy](./ci-monorepo-strategy.md)

**Consequences**:
- O(1) maintenance regardless of service count
- Independent builds per service
- Zero-config for new services
- Centralized control of CI standards

### ADR-008: Polyglot Architecture with Java Services

**Decision**: Add Java 21 services using Spring Boot, Quarkus, and Micronaut frameworks.

**Context**: Need business intelligence capabilities and framework comparison for demos.

**Rationale**:
- Spring Boot: Industry standard, extensive ecosystem, familiar to most Java developers
- Quarkus: Native compilation ready, fast startup, low memory footprint
- Micronaut: Compile-time DI, GraalVM native support, minimal reflection

**Consequences**:
- (+) Framework comparison in production conditions
- (+) Demonstrates polyglot CI/CD capabilities
- (+) Enables Java-specific integrations (e.g., Kafka Streams, Spring Batch)
- (-) Additional build tooling (Maven + Gradle)
- (-) Larger devcontainer image

### ADR-009: Java Package Domain Convention

**Decision**: Use `dev.cinema.latam` as the base package for all Java services.

**Context**: Following Java reversed domain naming convention.

**Alternatives considered**:
- `com.cinema.latam` - Traditional commercial domain
- `io.cinema.latam` - Modern API-style domain
- `dev.cinema.latam` - Development/demo-focused (chosen)

**Consequences**:
- Consistent namespace across all Java services
- Clear separation from Go services
- Suitable for demo/educational purposes

---

## CI/CD Architecture

For the complete CI/CD strategy documentation including:
- Pipeline Chaining architecture
- Orchestrator and Child pipeline flows
- Scaling analysis
- Multi-language support

See: **[CI/CD Monorepo Strategy](./ci-monorepo-strategy.md)**

---

## Related Documentation

- [Services Documentation](../services/README.md) - Individual service details
- [API Documentation](../api/README.md) - OpenAPI specs and contracts
- [Development Guide](../development/README.md) - Local setup
- [Operations Guide](../operations/README.md) - Deployment and CI/CD

---

## References

- [Original Architecture Analysis](./legacy/architecture-analysis.md)
- [Original Architecture Design](./legacy/architecture-design.md)
- [Martin Fowler - Microservices](https://martinfowler.com/articles/microservices.html)
- [SAGA Pattern](https://microservices.io/patterns/data/saga.html)
