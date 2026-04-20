<p align="center">
  <img src="https://img.shields.io/badge/Go-1.24+-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go 1.24+"/>
  <img src="https://img.shields.io/badge/Java-21-ED8B00?style=for-the-badge&logo=openjdk&logoColor=white" alt="Java 21"/>
  <img src="https://img.shields.io/badge/MongoDB-8.0-47A248?style=for-the-badge&logo=mongodb&logoColor=white" alt="MongoDB 8.0"/>
  <img src="https://img.shields.io/badge/Redis-7.x-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis 7"/>
  <img src="https://img.shields.io/badge/Docker-Ready-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker"/>
  <img src="https://img.shields.io/badge/Harness-CI%2FCD-0078D4?style=for-the-badge&logo=harness&logoColor=white" alt="Harness CI/CD"/>
</p>

<h1 align="center">Cinema Microservices Platform</h1>

<p align="center">
  <strong>Enterprise-grade cinema ticketing system built with polyglot microservices</strong><br/>
  Featuring Go + Java services, real-time seat reservations, payment processing, and event-driven notifications
</p>

<p align="center">
  <a href="./docs/README.md">Documentation</a> &bull;
  <a href="./docs/architecture/README.md">Architecture</a> &bull;
  <a href="./docs/api/README.md">API Reference</a> &bull;
  <a href="./docs/development/README.md">Development Guide</a>
</p>

---

## Overview

This platform implements a complete cinema ticketing workflow using a distributed microservices architecture. Each service is independently deployable, follows domain-driven design principles, and communicates via both synchronous REST APIs and asynchronous NATS messaging.

**Key Capabilities:**
- Real-time seat availability with distributed locking
- SAGA-based booking orchestration with automatic rollback
- Stripe payment integration with idempotency guarantees
- Event-driven notifications (email, SMS, push)
- Contract testing with Pact for service compatibility

---

## Architecture

```
                                    ┌─────────────────────────────────────────────────────────┐
                                    │                      CLIENTS                            │
                                    │              Web App  /  Mobile  /  Kiosk               │
                                    └─────────────────────────┬───────────────────────────────┘
                                                              │
                                    ┌─────────────────────────▼───────────────────────────────┐
                                    │                    API GATEWAY                          │
                                    │              Load Balancing / Auth / Rate Limit         │
                                    └─────────────────────────┬───────────────────────────────┘
                                                              │
   ┌──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┐
   │                                    GO SERVICES (Core Platform)                                                   │
   │                                                          │                                                       │
   │    ┌──────────┐   ┌──────────┐   ┌──────────┐     ┌──────────┐    ┌──────────┐   ┌──────────┐   ┌──────────┐   │
   │    │  USER    │   │  MOVIE   │   │  CINEMA  │     │ SHOWTIME │    │   SEAT   │   │ BOOKING  │   │ PAYMENT  │   │
   │    │ :8004    │   │ :8000    │   │ :8085    │     │ :3003    │    │ :3004    │   │ :8082    │   │ :8001    │   │
   │    └────┬─────┘   └────┬─────┘   └────┬─────┘     └────┬─────┘    └────┬─────┘   └────┬─────┘   └────┬─────┘   │
   │         └──────────────┴──────────────┴────────────────┴───────────────┴──────────────┴──────────────┘         │
   └──────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────┘
                                                              │
   ┌──────────────────────────────────────────────────────────┼──────────────────────────────────────────────────────┐
   │                                 JAVA SERVICES (Business Intelligence)                                            │
   │                                                          │                                                       │
   │              ┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐                            │
   │              │    ANALYTICS      │    │     LOYALTY       │    │     REVIEWS       │                            │
   │              │ :8010 SpringBoot  │    │ :8011 Quarkus     │    │ :8012 Micronaut   │                            │
   │              │ Reports & Metrics │    │ Points & Rewards  │    │ Ratings & Stats   │                            │
   │              └───────────────────┘    └───────────────────┘    └───────────────────┘                            │
   └──────────────────────────────────────────────────────────┬───────────────────────────────────────────────────────┘
                                                              │
                                    ┌──────────────────────────▼──────────────────────┐
                                    │                    NATS                         │
                                    │           Event Bus / JetStream                 │
                                    └──────────────────────────┬──────────────────────┘
                                                               │
                                    ┌──────────────────────────▼──────────────────────┐
                                    │              NOTIFICATION :8002                 │
                                    │           Email / SMS / Push                    │
                                    └─────────────────────────────────────────────────┘
```

---

## Services

### Go Services (Core Platform)

| Service | Port | Domain | Description |
|:--------|:----:|:-------|:------------|
| **user** | 8004 | Identity | Authentication, JWT tokens, user profiles |
| **movie** | 8000 | Catalog | Movie metadata, search, recommendations |
| **cinema** | 8085 | Catalog | Cinema locations, rooms, amenities |
| **showtime** | 3003 | Schedule | Show schedules, pricing, availability windows |
| **seat** | 3004 | Inventory | Seat maps, real-time holds, distributed locks |
| **booking** | 8082 | Transaction | SAGA orchestrator, reservation lifecycle |
| **payment** | 8001 | Financial | Stripe integration, refunds, receipts |
| **notification** | 8002 | Communication | Multi-channel delivery, templates, tracking |

### Java Services (Business Intelligence)

| Service | Port | Framework | Description |
|:--------|:----:|:----------|:------------|
| **analytics** | 8010 | Spring Boot 3.2 | Reports, sales metrics, business intelligence |
| **loyalty** | 8011 | Quarkus 3.x | Points program, tiers, rewards |
| **reviews** | 8012 | Micronaut 4.x | Movie reviews, ratings, statistics |

---

## Quick Start

### Prerequisites

- Go 1.24+
- Java 21+ (for Java services)
- Maven 3.9+ / Gradle 8.5+
- Docker & Docker Compose
- [Task](https://taskfile.dev) (recommended) or Make

### Development Environment

```bash
# Clone repository
git clone https://github.com/crizstian/cinema-microservices.git
cd cinema-microservices

# Option 1: DevContainer (recommended)
# Open in VS Code → "Reopen in Container"

# Option 2: Local setup
go work sync

# Start full dev environment (MongoDB 3-node replica + Redis + NATS + all services)
task dev:up

# View logs
task dev:log

# Stop environment
task dev:down
```

### Running Tests

```bash
# Unit tests for single service
task test SERVICE=booking

# Unit tests for all services
task test:all

# Contract tests (Pact consumer + provider)
task test:contract

# Full E2E tests (starts test environment automatically)
task test:e2e

# CI pipeline (lint + unit + contracts + coverage)
task test:ci
```

---

## Technology Stack

| Layer | Technology | Purpose |
|:------|:-----------|:--------|
| **Languages** | Go 1.24, Java 21 | Polyglot microservices |
| **Go Framework** | Echo v4 | Lightweight HTTP routing, middleware |
| **Java Frameworks** | Spring Boot, Quarkus, Micronaut | Enterprise Java (comparison-ready) |
| **Database** | MongoDB 8.0 | Document store, replica set transactions |
| **Cache** | Redis 7 | Session management, distributed locks |
| **Messaging** | NATS JetStream | Event streaming, pub/sub |
| **Payments** | Stripe | PCI-compliant payment processing |
| **API Specs** | OpenAPI 3.0 | Contract-first design |
| **Contracts** | Pact | Consumer-driven contract testing |
| **CI/CD** | Harness | Test Intelligence, deployment pipelines |
| **Containers** | Docker | Standardized builds, orchestration |

---

## Project Structure

```
cinema-microservices/
├── services/                    # Microservices (polyglot)
│   │
│   │ # Go Services
│   ├── booking/                 # SAGA orchestrator
│   ├── cinema/                  # Cinema locations
│   ├── movie/                   # Movie catalog
│   ├── notification/            # Multi-channel notifications
│   ├── payment/                 # Stripe integration
│   ├── seat/                    # Real-time seat inventory
│   ├── showtime/                # Schedule management
│   ├── user/                    # Authentication & profiles
│   │
│   │ # Java Services
│   ├── analytics/               # Spring Boot - Reports & metrics
│   ├── loyalty/                 # Quarkus - Points & rewards
│   └── reviews/                 # Micronaut - Reviews & ratings
│
├── platform/
│   ├── docker/                  # All Dockerfiles
│   │   ├── devcontainer/        # Development container (Go + Java)
│   │   ├── e2e-runner/          # E2E test runner
│   │   ├── go-service/          # Go service build template
│   │   ├── java-service/        # Java service build template
│   │   └── mongodb/             # MongoDB init + seeds
│   ├── deploy/
│   │   └── docker-compose/      # Docker Compose (dev + test profiles)
│   └── scripts/                 # Build & test automation
├── tests/
│   ├── contracts/               # Pact contract tests
│   └── integration/             # E2E test suite
├── docs/                        # Documentation hub
├── go.work                      # Go workspace configuration
├── Taskfile.yml                 # Task automation (Go + Java)
└── VERSION                      # Semantic versioning
```

---

## Task Automation

All common operations are automated via [Taskfile](https://taskfile.dev):

```bash
task --list             # List all available tasks

# Build (Go)
task build SERVICE=booking      # Build single service Docker image
task build:all                  # Build all Go service images

# Build (Java)
task java:build SERVICE=analytics    # Build Java service Docker image
task java:build:all                  # Build all Java services

# Development Environment
task dev:up                     # Start dev environment (3 MongoDB replicas)
task dev:down                   # Stop and clean volumes
task dev:log                    # Stream logs (optionally: SERVICE=booking)
task dev:clean                  # Remove images and build cache

# Testing (Go)
task test SERVICE=booking       # Unit tests for single service
task test:all                   # Unit tests for all Go services
task test:contract              # Pact contract tests
task test:e2e                   # End-to-end tests (full system)

# Testing (Java)
task java:test SERVICE=analytics     # Unit tests for Java service
task java:test:all                   # Unit tests for all Java services

# Run locally (Java)
task java:run SERVICE=analytics      # Run Java service in dev mode
```

---

## Documentation

| Section | Description |
|:--------|:------------|
| [Documentation Hub](./docs/README.md) | Start here — system overview and navigation |
| [Architecture](./docs/architecture/README.md) | C4 diagrams, data flows, ADRs |
| [Services](./docs/services/README.md) | Detailed service specifications |
| [API Reference](./docs/api/README.md) | OpenAPI specs, error handling |
| [Development](./docs/development/README.md) | Setup, testing, code style |
| [Operations](./docs/operations/README.md) | CI/CD pipelines, deployment |
| [Contracts](./docs/api/contracts.md) | Pact testing, consumer/provider |

---

## Contributing

1. Review the [Development Guide](./docs/development/README.md)
2. Create a feature branch from `main`
3. Write tests following the testing pyramid
4. Run `task test:ci` before submitting
5. Open a Pull Request with a clear description

---

## Version

**Current**: 0.1.0 | **License**: MIT

<p align="center">
  <sub>Built with precision for scalability and maintainability</sub>
</p>
