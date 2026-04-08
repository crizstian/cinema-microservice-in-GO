# Cinema Ticketing System - Documentation Hub

> **AI Agent Note**: This documentation is structured for both human developers and AI agents. Each section contains metadata, clear hierarchies, and cross-references to enable comprehensive understanding of the system.

**Last Updated**: 2026-04-08  
**System Version**: 2.0  
**Status**: Active Development

---

## Quick Navigation

| Section | Description | Key Files |
|---------|-------------|-----------|
| [Architecture](./architecture/README.md) | System design, data flow, ADRs | System overview, service interactions |
| [Services](./services/README.md) | Microservice specifications | 8 services (4 existing + 4 new) |
| [API](./api/README.md) | OpenAPI specs, contracts | REST APIs, Pact contracts |
| [Development](./development/README.md) | Setup, testing, contributing | DevContainer, testing guide |
| [Operations](./operations/README.md) | CI/CD, deployment, monitoring | Harness pipelines, Docker |

---

## System Overview

### What is This System?

A **cinema ticketing microservices platform** built with Go that enables:
- Movie catalog browsing
- Showtime selection by cinema/date
- Real-time seat selection with temporary holds
- Secure payment processing (Stripe)
- Email confirmation notifications
- User registration and authentication

### Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CINEMA TICKETING SYSTEM                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────────┐                       │
│   │  user   │  │  movie  │  │ cinema  │  │ showtime │  ← Catalog Layer      │
│   │  :8004  │  │  :8001  │  │  :8005  │  │  :8006   │                       │
│   └────┬────┘  └────┬────┘  └────┬────┘  └────┬─────┘                       │
│        │            │            │            │                              │
│   ┌────┴────────────┴────────────┴────────────┴────┐                        │
│   │                  booking :8000                  │  ← Orchestration       │
│   │              (saga coordinator)                 │                        │
│   └───────┬─────────────────┬───────────────┬──────┘                        │
│           │                 │               │                                │
│   ┌───────┴───────┐  ┌──────┴──────┐  ┌─────┴─────┐                         │
│   │  seat :8007   │  │payment :8002│  │notification│  ← Transaction Layer   │
│   │ (holds+reserve)│  │  (Stripe)  │  │   :8003   │                         │
│   └───────┬───────┘  └──────┬──────┘  └─────┬─────┘                         │
│           │                 │               │                                │
│      ┌────┴────┐       ┌────┴────┐     ┌────┴────┐                          │
│      │  Redis  │       │ Stripe  │     │  Gmail  │  ← External Services     │
│      │ (holds) │       │   API   │     │  SMTP   │                          │
│      └─────────┘       └─────────┘     └─────────┘                          │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                        MongoDB Replica Set                            │  │
│   │                    (mongo1:27017, mongo2, mongo3)                     │  │
│   └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Service Matrix

| Service | Port | Status | Database | Description |
|---------|------|--------|----------|-------------|
| **movie** | 8001 | Production | MongoDB movies | Movie catalog (read-only) |
| **booking** | 8000 | Production | MongoDB booking | Reservation orchestrator |
| **payment** | 8002 | Production | MongoDB payment | Stripe integration |
| **notification** | 8003 | Production | - | Email/SMS sender |
| **user** | 8004 | Planned | MongoDB users | Auth & profiles |
| **cinema** | 8005 | Planned | MongoDB cinemas | Cinema & room catalog |
| **showtime** | 8006 | Planned | MongoDB showtimes | Schedule management |
| **seat** | 8007 | Planned | MongoDB + Redis | Seat availability & holds |

---

## Technology Stack

### Core Technologies

| Category | Technology | Version | Purpose |
|----------|------------|---------|---------|
| **Language** | Go | 1.22+ | All microservices |
| **Framework** | Echo | v4 | HTTP routing |
| **Database** | MongoDB | 8.0 | Primary storage |
| **Cache** | Redis | 7.x | Seat holds, sessions |
| **Payments** | Stripe | v2024 | Payment processing |
| **Email** | Gmail SMTP | - | Notifications |

### Infrastructure

| Category | Technology | Purpose |
|----------|------------|---------|
| **Containers** | Docker | Service packaging |
| **Orchestration** | Docker Compose / K8s | Local/prod deployment |
| **CI/CD** | Harness | Pipelines, Test Intelligence |
| **API Specs** | OpenAPI 3.0 | Contract-first development |
| **Testing** | Pact | Consumer-driven contracts |

---

## Documentation Map

### For AI Agents

When analyzing this codebase, start with these files in order:

1. **This file** (`docs/README.md`) - System overview
2. **[Architecture](./architecture/README.md)** - How services interact
3. **[Services](./services/README.md)** - Individual service details
4. **[OpenAPI Specs](./api/README.md)** - API contracts in `/services/*/api/openapi.yaml`

### For Developers

| Task | Go To |
|------|-------|
| **Set up dev environment** | [Development Guide](./development/README.md) |
| **Understand the architecture** | [Architecture](./architecture/README.md) |
| **Add a new feature** | [Services](./services/README.md) |
| **Write tests** | [Testing Guide](./development/testing.md) |
| **Deploy changes** | [Operations](./operations/README.md) |

### For DevOps/SRE

| Task | Go To |
|------|-------|
| **CI/CD pipelines** | [Operations](./operations/README.md) |
| **Docker builds** | [Docker Guide](./development/docker.md) |
| **Deployment** | [Deployment Guide](./operations/deployment.md) |

---

## Repository Structure

```
/workspace/
├── services/                    # Microservices (Go)
│   ├── booking/                 # Reservation orchestrator
│   ├── movie/                   # Movie catalog
│   ├── payment/                 # Payment processing
│   ├── notification/            # Email/SMS
│   ├── user/                    # Auth & profiles (new)
│   ├── cinema/                  # Cinema catalog (new)
│   ├── showtime/                # Schedules (new)
│   └── seat/                    # Seat management (new)
│
├── platform/                    # Infrastructure
│   ├── docker/                  # Dockerfiles
│   │   ├── go-service/          # Generic service Dockerfile
│   │   ├── devcontainer/        # VS Code devcontainer
│   │   └── mongodb/             # MongoDB replica set
│   ├── deploy/
│   │   ├── docker-compose/      # Local deployment
│   │   └── hashicorp/           # Nomad/Consul/Vault
│   └── scripts/                 # Build scripts
│
├── docs/                        # Documentation (you are here)
│   ├── README.md                # This file
│   ├── architecture/            # System design
│   ├── services/                # Service specifications
│   ├── api/                     # API documentation
│   ├── development/             # Developer guides
│   └── operations/              # DevOps guides
│
├── contracts/                   # Pact contract files
├── tests/                       # Integration/E2E tests
├── go.work                      # Go workspace config
├── Taskfile.yml                 # Task automation
└── VERSION                      # Semantic version
```

---

## Key Concepts

### Consumer-Driven Contracts

We use **Pact** for contract testing between services:
- Consumers (booking) define expectations
- Providers (payment, seat, etc.) verify they meet expectations
- Contracts prevent integration failures

See: [Contract Testing](./api/contracts.md)

### Spec-Driven Development

All APIs are designed **OpenAPI-first**:
1. Design OpenAPI spec
2. Validate with Spectral
3. Generate code/models
4. Implement handlers
5. Contract tests

See: [API Guide](./api/README.md)

### SAGA Pattern

The booking flow uses **choreography-based SAGA**:
1. Hold seats (seat-service)
2. Process payment (payment-service)
3. Confirm reservation (seat-service)
4. Send notification (async)

If any step fails, compensating transactions execute.

See: [Architecture](./architecture/README.md)

---

## Quick Commands

```bash
# Development
task                    # Show available commands
task build:all          # Build all service images
task test:unit:all      # Run unit tests
task test:pipeline      # Full test suite

# Docker Compose
cd platform/deploy/docker-compose
docker compose up -d    # Start all services
docker compose logs -f  # View logs

# Single service
cd services/booking
go run ./cmd/booking    # Run locally
go test ./...           # Run tests
```

---

## Links

### Internal Documentation

- [Architecture Overview](./architecture/README.md)
- [Services Specification](./services/README.md)
- [API Documentation](./api/README.md)
- [Development Guide](./development/README.md)
- [Operations Guide](./operations/README.md)

### External Resources

- [Go Project Layout](https://github.com/golang-standards/project-layout)
- [OpenAPI Specification](https://spec.openapis.org/oas/v3.0.3)
- [Pact Contract Testing](https://docs.pact.io/)
- [Harness CI/CD](https://developer.harness.io/)

---

## Contributing

1. Follow [Development Guide](./development/README.md)
2. Use conventional commits
3. Ensure tests pass: `task test:pipeline`
4. Update documentation for significant changes

---

**Maintained by**: Cinema Microservices Team  
**Architecture Version**: 2.0  
**Documentation Version**: 2.0
