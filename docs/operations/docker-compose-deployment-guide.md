# Cinema Microservices: Local Development Stack

## Executive Summary

Este documento cubre el despliegue local completo del sistema Cinema Microservices usando Docker Compose. Diseñado para ingenieros que quieran entender arquitectura distribuida, patrones de orquestación y técnicas de troubleshooting en sistemas de producción.

**Audiencia:** Staff Engineers, SREs, Backend Engineers con experiencia intermedia-avanzada.

**Propósito triple:**
1. **Arquitectura** — Entender patrones de microservicios, SAGA, distributed locking
2. **Despliegue** — Levantar un stack local production-like con Docker Compose
3. **Troubleshooting** — Diagnosticar y resolver problemas comunes en sistemas distribuidos

**Tiempo estimado:** 30-45 min (primera lectura completa) | 5 min (despliegue subsecuente)

---

## Tabla de Contenidos

1. [Stack Tecnológico](#1-stack-tecnológico)
2. [Diagramas de Arquitectura](#2-diagramas-de-arquitectura)
3. [Arquitectura del Sistema](#3-arquitectura-del-sistema)
4. [Patrones de Diseño](#4-patrones-de-diseño)
5. [Stack de Infraestructura](#5-stack-de-infraestructura)
6. [Configuración y Despliegue](#6-configuración-y-despliegue)
7. [Seguridad](#7-seguridad)
8. [Validación del Sistema](#8-validación-del-sistema)
9. [Flujos de Negocio](#9-flujos-de-negocio)
10. [Troubleshooting Avanzado](#10-troubleshooting-avanzado)
11. [Referencia Rápida](#11-referencia-rápida)

---

## 1. Stack Tecnológico

### 1.1 Decisiones Tecnológicas y Justificación

| Tecnología | Versión | Propósito | ¿Por qué esta elección? |
|------------|---------|-----------|-------------------------|
| **Go** | 1.24 | Lenguaje de servicios | Compilación a binario estático, bajo footprint de memoria (~10MB), excelente para microservicios con alta concurrencia. Garbage collector optimizado para baja latencia. |
| **Echo** | v4 | HTTP Framework | Minimalista, alto rendimiento (~30k req/s), middleware composable. Más ligero que Gin con API similar. |
| **MongoDB** | 8.0 | Base de datos principal | Schema flexible para dominio cinematográfico (películas, horarios variables). Replica set nativo para HA. Transactions desde 4.0. |
| **Redis** | 7-alpine | Cache y locks | Operaciones atómicas (WATCH/MULTI), TTL nativo para expiración de holds. Sub-millisecond latency. |
| **Docker Compose** | v2 | Orquestación local | Profiles para múltiples entornos, healthchecks integrados, networking declarativo. |
| **Alpine Linux** | 3.21 | Base image | ~5MB base, superficie de ataque mínima, musl libc compatible con Go static binaries. |

### 1.2 Librerías Clave por Servicio

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEPENDENCIAS COMUNES                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  github.com/labstack/echo/v4      → HTTP routing, middleware               │
│  go.mongodb.org/mongo-driver      → MongoDB driver oficial                 │
│  github.com/sirupsen/logrus       → Structured logging                     │
│  github.com/google/uuid           → UUID generation para IDs               │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEPENDENCIAS ESPECÍFICAS                            │
├─────────────────────────────────────────────────────────────────────────────┤
│  seat-service:                                                              │
│    github.com/redis/go-redis/v9   → Redis client con WATCH support         │
│                                                                             │
│  user-service:                                                              │
│    github.com/golang-jwt/jwt/v5   → JWT token handling                     │
│    golang.org/x/crypto/bcrypt     → Password hashing (cost=10)             │
│                                                                             │
│  booking-service:                                                           │
│    github.com/opentracing/opentracing-go  → Distributed tracing            │
│    github.com/uber/jaeger-client-go       → Jaeger implementation          │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.3 ¿Por qué Go y no Node.js/Java/Python?

| Criterio | Go | Node.js | Java | Python |
|----------|----|---------| -----|--------|
| **Memory footprint** | ~10-20MB | ~50-100MB | ~200-500MB | ~50-100MB |
| **Startup time** | <100ms | ~500ms | 2-5s (JVM) | ~1s |
| **Concurrency model** | Goroutines (M:N) | Event loop | Threads | asyncio/threads |
| **Binary distribution** | Single static binary | node_modules | JAR + JVM | virtualenv |
| **Type safety** | Compile-time | Runtime (TS helps) | Compile-time | Runtime |

**Conclusión:** Go ofrece el mejor balance entre performance, simplicidad operacional (single binary) y developer experience para microservicios HTTP.

### 1.4 ¿Por qué MongoDB y no PostgreSQL?

| Criterio | MongoDB | PostgreSQL |
|----------|---------|------------|
| **Schema flexibility** | Documentos anidados (películas con géneros, horarios con precios por tipo) | Requiere JOINs o JSONB |
| **Horizontal scaling** | Sharding nativo | Requiere Citus/extensiones |
| **Replica set** | Built-in, automatic failover | Requiere pgpool/patroni |
| **Transactions** | Multi-document desde 4.0 | ACID completo |
| **Query language** | JSON-like, aggregation pipeline | SQL estándar |

**Conclusión:** MongoDB simplifica el modelo de datos para este dominio y facilita el deployment de réplicas.

---

## 2. Diagramas de Arquitectura

### 2.1 C4 Model — Nivel 1: Context Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SYSTEM CONTEXT                                 │
└─────────────────────────────────────────────────────────────────────────────┘

                            ┌─────────────────┐
                            │    Customer     │
                            │    [Person]     │
                            │                 │
                            │ Busca películas,│
                            │ reserva boletos │
                            └────────┬────────┘
                                     │
                                     │ HTTP/JSON
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                     Cinema Microservices System                             │
│                         [Software System]                                   │
│                                                                             │
│    Permite a los usuarios buscar películas, consultar horarios,            │
│    seleccionar asientos y completar reservas con pago integrado.           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                     │
                    ┌────────────────┼────────────────┐
                    │                │                │
                    ▼                ▼                ▼
           ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
           │ Payment       │ │ Email/SMS     │ │ External      │
           │ Gateway       │ │ Provider      │ │ Movie DB      │
           │ [External]    │ │ [External]    │ │ [External]    │
           │               │ │               │ │               │
           │ Stripe (mock) │ │ SendGrid mock │ │ TMDB (futuro) │
           └───────────────┘ └───────────────┘ └───────────────┘
```

### 2.2 C4 Model — Nivel 2: Container Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CONTAINER DIAGRAM                                │
│                        Cinema Microservices System                          │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────────────┐
    │                         API Layer (HTTP)                             │
    │  ┌─────────────────────────────────────────────────────────────────┐ │
    │  │                     [Future: API Gateway]                       │ │
    │  │            Kong / Traefik / Ambassador                          │ │
    │  └─────────────────────────────────────────────────────────────────┘ │
    └──────────────────────────────────────────────────────────────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────────┐
        │                            │                                │
        ▼                            ▼                                ▼
┌───────────────┐          ┌─────────────────┐              ┌───────────────┐
│    movie      │          │    booking      │              │     user      │
│   [Container] │          │   [Container]   │              │  [Container]  │
│    Go/Echo    │          │    Go/Echo      │              │   Go/Echo     │
│    :8002      │          │     :8001       │              │    :8004      │
│               │          │                 │              │               │
│ Catálogo de   │          │ SAGA            │              │ Auth, JWT,    │
│ películas     │          │ Orchestrator    │              │ Perfiles      │
└───────┬───────┘          └────────┬────────┘              └───────┬───────┘
        │                           │                               │
        │              ┌────────────┴────────────┐                  │
        │              │                         │                  │
        │    ┌─────────▼─────────┐   ┌──────────▼──────────┐       │
        │    │     showtime      │   │       seat          │       │
        │    │    [Container]    │   │    [Container]      │       │
        │    │     Go/Echo       │   │     Go/Echo         │       │
        │    │      :8006        │   │      :8005          │       │
        │    │                   │   │                     │       │
        │    │ Funciones,        │   │ Holds (Redis),      │       │
        │    │ Horarios          │   │ Reservas (Mongo)    │       │
        │    └─────────┬─────────┘   └──────────┬──────────┘       │
        │              │                        │                   │
        │              │              ┌─────────┴─────────┐        │
        │              │              │                   │        │
        │              │    ┌────────▼────────┐  ┌───────▼───────┐ │
        │              │    │    payment      │  │  notification │ │
        │              │    │   [Container]   │  │  [Container]  │ │
        │              │    │    Go/Echo      │  │   Go/Echo     │ │
        │              │    │     :8007       │  │    :8008      │ │
        │              │    │                 │  │               │ │
        │              │    │ Mock Stripe     │  │ Mock Email    │ │
        │              │    └────────┬────────┘  └───────────────┘ │
        │              │             │                              │
        └──────────────┴─────────────┴──────────────────────────────┘
                                     │
    ┌────────────────────────────────┴────────────────────────────────┐
    │                        DATA LAYER                               │
    │  ┌─────────────────────────────────────────────────────────────┐│
    │  │              MongoDB Replica Set (rs0)                      ││
    │  │     ┌─────────────┐ ┌─────────────┐ ┌─────────────┐        ││
    │  │     │   mongo1    │ │   mongo2    │ │   mongo3    │        ││
    │  │     │  [PRIMARY]  │ │ [SECONDARY] │ │ [SECONDARY] │        ││
    │  │     │   :27017    │ │   :27018    │ │   :27019    │        ││
    │  │     └─────────────┘ └─────────────┘ └─────────────┘        ││
    │  │                                                             ││
    │  │  Databases: movie | cinema | showtime | user | seat |      ││
    │  │             booking | payment                               ││
    │  └─────────────────────────────────────────────────────────────┘│
    │                                                                 │
    │  ┌─────────────────────────────────────────────────────────────┐│
    │  │                    Redis (Standalone)                       ││
    │  │                        :6379                                ││
    │  │                                                             ││
    │  │  Keys: hold:{uuid} | seat_hold:{showtime}:{seat}           ││
    │  │  Purpose: Distributed locks, TTL-based seat holds           ││
    │  └─────────────────────────────────────────────────────────────┘│
    └─────────────────────────────────────────────────────────────────┘
```

### 2.3 C4 Model — Nivel 3: Component Diagram (Booking Service)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPONENT DIAGRAM                                    │
│                        booking-service                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           booking-service                                   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        cmd/booking/main.go                          │   │
│  │                         [Entrypoint]                                │   │
│  │           Dependency injection, server initialization              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    internal/server/server.go                        │   │
│  │                        [HTTP Server]                                │   │
│  │         Echo instance, middleware, route registration              │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│           ┌────────────────────────┴────────────────────────┐              │
│           ▼                                                  ▼              │
│  ┌─────────────────────┐                      ┌─────────────────────────┐  │
│  │ internal/routes/    │                      │  internal/tracing/      │  │
│  │   [Router]          │                      │    [Observability]      │  │
│  │                     │                      │                         │  │
│  │ POST /booking       │                      │  OpenTracing spans      │  │
│  │ GET /booking/:id    │                      │  Jaeger integration     │  │
│  └──────────┬──────────┘                      └─────────────────────────┘  │
│             │                                                               │
│             ▼                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    internal/api/booking.go                          │   │
│  │                       [API Handlers]                                │   │
│  │                                                                     │   │
│  │  MakeBooking()     → SAGA orchestration                            │   │
│  │  GetOrderByID()    → Query booking                                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│           ┌────────────────────────┴────────────────────────┐              │
│           ▼                                                  ▼              │
│  ┌─────────────────────┐                      ┌─────────────────────────┐  │
│  │ internal/ctrls/     │                      │  internal/config/       │  │
│  │  [Controllers]      │                      │   [External Clients]    │  │
│  │                     │                      │                         │  │
│  │ MakePayment()       │                      │  ShowtimeClient         │  │
│  │ CreateTicket()      │                      │  SeatClient             │  │
│  └──────────┬──────────┘                      │  PaymentClient          │  │
│             │                                 │  NotificationClient     │  │
│             ▼                                 └─────────────────────────┘  │
│  ┌─────────────────────┐                                                   │
│  │ internal/db/        │                                                   │
│  │  [Repository]       │                                                   │
│  │                     │                                                   │
│  │ MongoDB connection  │                                                   │
│  │ CRUD operations     │                                                   │
│  └─────────────────────┘                                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                    │
                    │ HTTP calls
                    ▼
    ┌───────────────────────────────────────────────────────┐
    │  External Services (via HTTP)                         │
    │                                                       │
    │  showtime:8006  │  seat:8005  │  payment:8007  │     │
    │  notification:8008                                    │
    └───────────────────────────────────────────────────────┘
```

### 2.4 Diagrama de Infraestructura — Docker Compose

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INFRASTRUCTURE DIAGRAM                                   │
│                     Docker Compose Stack                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        Docker Host                                          │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                    cinema-dev-network (bridge)                        │ │
│  │                                                                       │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │  │                   Application Tier                              │ │ │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐  │ │ │
│  │  │  │ booking │ │  movie  │ │ cinema  │ │  user   │ │showtime │  │ │ │
│  │  │  │  :8001  │ │  :8002  │ │  :8003  │ │  :8004  │ │  :8006  │  │ │ │
│  │  │  │ 256Mi   │ │ 256Mi   │ │ 256Mi   │ │ 256Mi   │ │ 256Mi   │  │ │ │
│  │  │  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘  │ │ │
│  │  │       │           │           │           │           │       │ │ │
│  │  │  ┌─────────┐ ┌─────────┐ ┌─────────┐                          │ │ │
│  │  │  │  seat   │ │ payment │ │ notif.  │                          │ │ │
│  │  │  │  :8005  │ │  :8007  │ │  :8008  │                          │ │ │
│  │  │  │ 512Mi   │ │ 512Mi   │ │ 256Mi   │                          │ │ │
│  │  │  └────┬────┘ └────┬────┘ └────┬────┘                          │ │ │
│  │  └───────┼───────────┼───────────┼───────────────────────────────┘ │ │
│  │          │           │           │                                 │ │
│  │  ┌───────┴───────────┴───────────┴───────────────────────────────┐ │ │
│  │  │                     Data Tier                                 │ │ │
│  │  │                                                               │ │ │
│  │  │  ┌─────────────────────────────────────────────────────────┐ │ │ │
│  │  │  │           MongoDB Replica Set (rs0)                     │ │ │ │
│  │  │  │  ┌───────────┐  ┌───────────┐  ┌───────────┐           │ │ │ │
│  │  │  │  │  mongo1   │  │  mongo2   │  │  mongo3   │           │ │ │ │
│  │  │  │  │ PRIMARY   │  │ SECONDARY │  │ SECONDARY │           │ │ │ │
│  │  │  │  │  :27017   │  │  :27018   │  │  :27019   │           │ │ │ │
│  │  │  │  │           │  │           │  │           │           │ │ │ │
│  │  │  │  │ ┌───────┐ │  │ ┌───────┐ │  │ ┌───────┐ │           │ │ │ │
│  │  │  │  │ │Volume │ │  │ │Volume │ │  │ │Volume │ │           │ │ │ │
│  │  │  │  │ │mongo1 │ │  │ │mongo2 │ │  │ │mongo3 │ │           │ │ │ │
│  │  │  │  │ │_data  │ │  │ │_data  │ │  │ │_data  │ │           │ │ │ │
│  │  │  │  │ └───────┘ │  │ └───────┘ │  │ └───────┘ │           │ │ │ │
│  │  │  │  └───────────┘  └───────────┘  └───────────┘           │ │ │ │
│  │  │  └─────────────────────────────────────────────────────────┘ │ │ │
│  │  │                                                               │ │ │
│  │  │  ┌─────────────────┐                                         │ │ │
│  │  │  │     Redis       │                                         │ │ │
│  │  │  │     :6379       │                                         │ │ │
│  │  │  │  ┌───────────┐  │                                         │ │ │
│  │  │  │  │  Volume   │  │                                         │ │ │
│  │  │  │  │redis_data │  │                                         │ │ │
│  │  │  │  └───────────┘  │                                         │ │ │
│  │  │  └─────────────────┘                                         │ │ │
│  │  └───────────────────────────────────────────────────────────────┘ │ │
│  │                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────┐   │ │
│  │  │                  Init Containers                            │   │ │
│  │  │  ┌─────────────────┐                                        │   │ │
│  │  │  │ mongo-init-dev  │ → rs.initiate() + seed data            │   │ │
│  │  │  │ Exited(0)       │                                        │   │ │
│  │  │  └─────────────────┘                                        │   │ │
│  │  └─────────────────────────────────────────────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  Port mappings to host:                                                     │
│  8001-8008 (services) | 27017-27019 (mongo) | 6379 (redis)                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.5 Diagrama de Secuencia — Booking Flow (SAGA)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      SEQUENCE DIAGRAM: Booking SAGA                         │
│                           (Happy Path)                                      │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────┐     ┌─────────┐    ┌──────────┐    ┌──────┐    ┌─────────┐   ┌───────┐
│Client│     │ booking │    │ showtime │    │ seat │    │ payment │   │notif. │
└──┬───┘     └────┬────┘    └────┬─────┘    └──┬───┘    └────┬────┘   └───┬───┘
   │              │              │             │             │            │
   │ POST /booking│              │             │             │            │
   │─────────────>│              │             │             │            │
   │              │              │             │             │            │
   │              │ ┌──────────────────────────────────────────────────┐ │
   │              │ │ SAGA Step 1: Validate Showtime                   │ │
   │              │ └──────────────────────────────────────────────────┘ │
   │              │              │             │             │            │
   │              │ GET /showtimes/{id}        │             │            │
   │              │─────────────>│             │             │            │
   │              │              │             │             │            │
   │              │    200 OK {showtime}       │             │            │
   │              │<─────────────│             │             │            │
   │              │              │             │             │            │
   │              │ ┌──────────────────────────────────────────────────┐ │
   │              │ │ SAGA Step 2: Verify Hold                         │ │
   │              │ └──────────────────────────────────────────────────┘ │
   │              │              │             │             │            │
   │              │ GET /seats/hold/{id}?session_id=X        │            │
   │              │────────────────────────────>│             │            │
   │              │              │             │             │            │
   │              │              │  200 OK {hold}             │            │
   │              │<────────────────────────────│             │            │
   │              │              │             │             │            │
   │              │ ┌──────────────────────────────────────────────────┐ │
   │              │ │ SAGA Step 3: Process Payment                     │ │
   │              │ └──────────────────────────────────────────────────┘ │
   │              │              │             │             │            │
   │              │ POST /payments/makePurchase              │            │
   │              │──────────────────────────────────────────>│            │
   │              │              │             │             │            │
   │              │              │   201 Created {charge_id} │            │
   │              │<──────────────────────────────────────────│            │
   │              │              │             │             │            │
   │              │ ┌──────────────────────────────────────────────────┐ │
   │              │ │ SAGA Step 4: Confirm Seats                       │ │
   │              │ └──────────────────────────────────────────────────┘ │
   │              │              │             │             │            │
   │              │ POST /seats/reserve        │             │            │
   │              │────────────────────────────>│             │            │
   │              │              │             │             │            │
   │              │              │  201 {reservation}        │            │
   │              │<────────────────────────────│             │            │
   │              │              │             │             │            │
   │              │ ┌──────────────────────────────────────────────────┐ │
   │              │ │ SAGA Step 5: Create Ticket (local MongoDB)       │ │
   │              │ └──────────────────────────────────────────────────┘ │
   │              │              │             │             │            │
   │              │ ┌──────────────────────────────────────────────────┐ │
   │              │ │ SAGA Step 6: Send Notification (fire & forget)   │ │
   │              │ └──────────────────────────────────────────────────┘ │
   │              │              │             │             │            │
   │              │ POST /notification/sendEmail             │            │
   │              │───────────────────────────────────────────────────────>│
   │              │              │             │             │            │
   │              │              │             │             │  202 Accepted
   │              │<───────────────────────────────────────────────────────│
   │              │              │             │             │            │
   │ 201 Created  │              │             │             │            │
   │ {ticket}     │              │             │             │            │
   │<─────────────│              │             │             │            │
   │              │              │             │             │            │
```

### 2.6 Diagrama de Secuencia — Booking SAGA (Failure + Compensation)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   SEQUENCE DIAGRAM: Booking SAGA                            │
│                    (Payment Failure → Compensation)                         │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────┐     ┌─────────┐    ┌──────────┐    ┌──────┐    ┌─────────┐
│Client│     │ booking │    │ showtime │    │ seat │    │ payment │
└──┬───┘     └────┬────┘    └────┬─────┘    └──┬───┘    └────┬────┘
   │              │              │             │             │
   │ POST /booking│              │             │             │
   │─────────────>│              │             │             │
   │              │              │             │             │
   │              │ Step 1: GET /showtimes/{id}│             │
   │              │─────────────>│             │             │
   │              │    200 OK    │             │             │
   │              │<─────────────│             │             │
   │              │              │             │             │
   │              │ Step 2: GET /seats/hold/{id}             │
   │              │────────────────────────────>│             │
   │              │              │  200 OK     │             │
   │              │<────────────────────────────│             │
   │              │              │             │             │
   │              │ Step 3: POST /payments/makePurchase      │
   │              │──────────────────────────────────────────>│
   │              │              │             │             │
   │              │              │             │  ╔═══════════════════╗
   │              │              │             │  ║ 402 Payment       ║
   │              │              │             │  ║ Failed            ║
   │              │              │             │  ║ (insufficient     ║
   │              │              │             │  ║  funds)           ║
   │              │              │             │  ╚═══════════════════╝
   │              │              │             │             │
   │              │         402 Payment Declined             │
   │              │<──────────────────────────────────────────│
   │              │              │             │             │
   │              │ ╔════════════════════════════════════════════════════╗
   │              │ ║           COMPENSATION TRIGGERED                   ║
   │              │ ╚════════════════════════════════════════════════════╝
   │              │              │             │             │
   │              │ Compensation: DELETE /seats/hold/{id}    │
   │              │────────────────────────────>│             │
   │              │              │  200 OK (released)        │
   │              │<────────────────────────────│             │
   │              │              │             │             │
   │ 500 Error    │              │             │             │
   │ {code:       │              │             │             │
   │ PAYMENT_     │              │             │             │
   │ FAILED}      │              │             │             │
   │<─────────────│              │             │             │
   │              │              │             │             │
```

### 2.7 Diagrama de Estado — Seat Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     STATE DIAGRAM: Seat Lifecycle                           │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────────┐
                              │    AVAILABLE    │
                              │   (default)     │
                              └────────┬────────┘
                                       │
                                       │ POST /seats/hold
                                       │ HoldSeats()
                                       │ Redis SET + TTL
                                       ▼
                    ┌──────────────────────────────────────┐
                    │               HELD                   │
                    │                                      │
                    │  Storage: Redis                      │
                    │  TTL: 300s (configurable)            │
                    │  Key: seat_hold:{showtime}:{seat}    │
                    │                                      │
                    │  Owner: session_id                   │
                    └──────────────────┬───────────────────┘
                                       │
                     ┌─────────────────┼─────────────────┐
                     │                 │                 │
                     ▼                 ▼                 ▼
          ┌──────────────────┐  ┌────────────┐  ┌──────────────────┐
          │  TTL Expires     │  │  Manual    │  │ POST /seats/     │
          │  (auto)          │  │  Release   │  │ reserve          │
          │                  │  │            │  │                  │
          │  Redis auto-     │  │  DELETE    │  │  ReserveSeats()  │
          │  deletes key     │  │  /hold/:id │  │                  │
          └────────┬─────────┘  └─────┬──────┘  └────────┬─────────┘
                   │                  │                  │
                   ▼                  ▼                  ▼
          ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
          │   AVAILABLE     │ │   AVAILABLE     │ │    RESERVED     │
          │   (recycled)    │ │   (explicit)    │ │   (permanent)   │
          │                 │ │                 │ │                 │
          │                 │ │                 │ │ Storage: MongoDB│
          │                 │ │                 │ │ reservations    │
          │                 │ │                 │ │ collection      │
          └─────────────────┘ └─────────────────┘ └─────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│ SPECIAL STATES                                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  UNAVAILABLE (permanent)     ─  Seat physically doesn't exist or is        │
│                                 blocked (wheelchair space, aisle, etc.)    │
│                                 Defined in room_layouts.seats[].type       │
│                                                                             │
│  CONFLICT (transient)        ─  Two sessions tried to hold same seat       │
│                                 simultaneously. WATCH transaction fails.   │
│                                 Returns HTTP 409 with conflicting holds.   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.8 Diagrama de Flujo de Datos

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DATA FLOW DIAGRAM                                    │
│                   Cinema Booking System                                     │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                              WRITE PATH                                      │
└──────────────────────────────────────────────────────────────────────────────┘

  Customer                                                              
     │                                                                  
     │ (1) Select movie/showtime                                        
     │     Browse catalog                                               
     ▼                                                                  
┌─────────┐      ┌─────────────┐                                        
│  movie  │─────>│  showtime   │  (2) Get available showtimes          
└─────────┘      └──────┬──────┘      for selected movie                
                        │                                               
                        │ (3) Query seat availability                   
                        ▼                                               
                  ┌──────────┐     ┌─────────────┐                      
                  │   seat   │<────│    Redis    │  (4) Check held seats
                  │          │     │   (reads)   │      (fast path)     
                  └────┬─────┘     └─────────────┘                      
                       │                                                
                       │ (5) Hold seats request                         
                       ▼                                                
                  ┌─────────────┐                                       
                  │    Redis    │  (6) WATCH + SET with TTL             
                  │   (write)   │      Atomic hold creation             
                  └─────────────┘                                       
                       │                                                
                       │ (7) Proceed to checkout                        
                       ▼                                                
                  ┌─────────┐                                           
                  │ booking │  (8) SAGA orchestration                   
                  │  (SAGA) │      Coordinates all steps                
                  └────┬────┘                                           
                       │                                                
        ┌──────────────┼──────────────┐                                 
        │              │              │                                 
        ▼              ▼              ▼                                 
   ┌─────────┐   ┌──────────┐   ┌──────────┐                           
   │ payment │   │   seat   │   │ booking  │                           
   │         │   │ (reserve)│   │   (db)   │                           
   └────┬────┘   └────┬─────┘   └────┬─────┘                           
        │             │              │                                  
        │             │              │ (9) Write to MongoDB             
        ▼             ▼              ▼                                  
   ┌──────────────────────────────────────────┐                        
   │              MongoDB                     │                        
   │   payments | reservations | bookings     │                        
   └──────────────────────────────────────────┘                        


┌──────────────────────────────────────────────────────────────────────────────┐
│                              READ PATH                                       │
└──────────────────────────────────────────────────────────────────────────────┘

  Customer                                                              
     │                                                                  
     │ GET /movies                                                      
     ▼                                                                  
┌─────────┐                                                             
│  movie  │──────┐                                                      
└─────────┘      │                                                      
                 │                                                      
     │           │  All reads go                                        
     │ GET       │  directly to                                         
     ▼           │  MongoDB                                             
┌──────────┐     │                                                      
│ showtime │─────┤  (No read cache                                      
└──────────┘     │   in current                                         
                 │   implementation)                                    
     │           │                                                      
     │ GET       │                                                      
     ▼           │                                                      
┌──────────┐     │                                                      
│   seat   │─────┤                                                      
└──────────┘     │                                                      
                 │                                                      
                 ▼                                                      
         ┌──────────────┐                                               
         │   MongoDB    │  Replica Set                                  
         │  (PRIMARY)   │  reads from PRIMARY                           
         └──────────────┘  by default                                   
                                                                        
         Note: Could add read preference                                
         secondaryPreferred for                                         
         read scaling                                                   
```

---

## 3. Arquitectura del Sistema

### 3.1 Topología de Servicios

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              API Gateway (futuro)                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌───────────────┐            ┌─────────────────┐            ┌───────────────┐
│    movie      │            │    booking      │            │     user      │
│    :8002      │            │     :8001       │            │    :8004      │
│   Catálogo    │◄───────────│   SAGA Orch.    │            │   Auth/JWT    │
└───────────────┘            └─────────────────┘            └───────────────┘
                                     │
        ┌─────────────────┬──────────┼──────────┬─────────────────┐
        ▼                 ▼          ▼          ▼                 ▼
┌───────────────┐ ┌───────────────┐ ┌─────────────────┐ ┌───────────────┐
│   showtime    │ │     seat      │ │     payment     │ │ notification  │
│    :8006      │ │    :8005      │ │     :8007       │ │    :8008      │
│   Horarios    │ │  Locks/Redis  │ │   Mock Stripe   │ │  Mock Email   │
└───────────────┘ └───────────────┘ └─────────────────┘ └───────────────┘
        │                 │
        ▼                 ▼
┌───────────────┐ ┌───────────────┐
│    cinema     │ │     Redis     │
│    :8003      │ │    :6379      │
│  Salas/Cines  │ │ Distributed   │
└───────────────┘ │    Locks      │
                  └───────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    MongoDB Replica Set (rs0)                                │
│              mongo1:27017 (PRIMARY) | mongo2:27018 | mongo3:27019           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  [PLANNED] Observability Stack                                              │
│  Jaeger :16686 (tracing) | Prometheus :9090 (metrics) | Grafana :3000      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Responsabilidades por Servicio

| Servicio | Puerto | Database | Responsabilidad |
|----------|--------|----------|-----------------|
| **booking** | 8001 | booking | SAGA Orchestrator — coordina el flujo de reserva completo |
| **movie** | 8002 | movie | Catálogo de películas, premieres, metadata |
| **cinema** | 8003 | cinema | Gestión de cines, salas, capacidades |
| **user** | 8004 | user | Autenticación, JWT tokens (access/refresh), perfiles |
| **seat** | 8005 | seat | Disponibilidad, holds temporales (Redis), reservas permanentes (Mongo) |
| **showtime** | 8006 | showtime | Funciones, horarios, precios por tipo de asiento |
| **payment** | 8007 | payment | Mock de procesador de pagos (simula Stripe) |
| **notification** | 8008 | — | Mock de notificaciones (email, SMS) |

### 3.3 Decisiones Arquitectónicas

**Database-per-Service Pattern**
Cada servicio tiene su propia base de datos lógica en MongoDB. Esto garantiza:
- Loose coupling entre servicios
- Escalabilidad independiente
- Autonomía de deployment

**Configuración centralizada:** `platform/config/services.yaml`

```yaml
services:
  movie:
    port: 8002
    dbName: movie        # ← Cada servicio usa su propia DB
    image: crizstian/movie-service
```

---

## 4. Patrones de Diseño

### 4.1 SAGA Pattern — Booking Orchestrator

El servicio `booking` implementa el patrón SAGA para coordinar transacciones distribuidas con compensaciones automáticas.

**Flujo de reserva (happy path):**

```
┌────────────────────────────────────────────────────────────────────────────┐
│ SAGA: MakeBooking                                                          │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  Step 1: ValidateShowtime ──► showtime-service                             │
│          ↓ success                                                         │
│  Step 2: VerifyHold ─────────► seat-service (Redis lookup)                 │
│          ↓ success                                                         │
│  Step 3: ProcessPayment ─────► payment-service (Stripe mock)               │
│          ↓ success                                                         │
│  Step 4: ConfirmSeats ───────► seat-service (Redis→Mongo)                  │
│          ↓ success                                                         │
│  Step 5: CreateTicket ───────► booking-service (local Mongo)               │
│          ↓ success                                                         │
│  Step 6: SendNotification ───► notification-service (async, no-fail)       │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

**Compensaciones (failure path):**

```go
// services/booking/internal/api/booking.go:66-72
// Payment failure → Release hold
if releaseErr := a.client.API.ReleaseHold(b.Booking.HoldID, b.Booking.SessionID); releaseErr != nil {
    log.WithError(releaseErr).Error("Failed to release hold during compensation")
}

// Seat confirmation failure → Refund payment
if refundErr := a.client.API.RefundPayment(chargeID, "Seat confirmation failed"); refundErr != nil {
    log.WithError(refundErr).Error("Failed to refund payment during compensation")
}
```

**¿Por qué SAGA y no 2PC?**
- 2PC (Two-Phase Commit) requiere locks distribuidos prolongados
- SAGA permite higher availability con eventual consistency
- Las compensaciones son explícitas y auditables

### 4.2 Distributed Locking — Seat Hold Pattern

El servicio `seat` usa Redis para locks temporales y MongoDB para reservas permanentes.

**Modelo de estado de asientos:**

```
            ┌─────────────┐
            │  available  │
            └──────┬──────┘
                   │ HoldSeats() → Redis SET con TTL
                   ▼
            ┌─────────────┐
            │    held     │ ◄── TTL 5 min (auto-expire)
            └──────┬──────┘
                   │ ReserveSeats() → Mongo INSERT + Redis DEL
                   ▼
            ┌─────────────┐
            │  reserved   │ ◄── Permanente en MongoDB
            └─────────────┘
```

**Implementación de lock atómico con WATCH:**

```go
// services/seat/internal/db/redis.go:69-127
// Usa WATCH para optimistic locking
err := r.client.Watch(ctx, txf, watchKeys...)

// Dentro de txf:
// 1. Verifica que ningún seat esté held
// 2. Si todos disponibles, ejecuta pipeline SET
// 3. Si hay conflicto, WATCH aborta la transacción
```

**Key structure en Redis:**
```
hold:{uuid}                     → Hold metadata (JSON)
seat_hold:{showtime_id}:{seat}  → Per-seat hold status
```

**¿Por qué Redis + MongoDB?**
- **Redis:** Fast TTL-based expiration, atomic operations
- **MongoDB:** Durabilidad, queries complejas, historial de reservas

### 4.3 Multi-stage Docker Builds

Cada servicio Go usa un Dockerfile optimizado con soporte dual para desarrollo local y CI:

```dockerfile
# platform/docker/go-service/Dockerfile
# Targets: runtime (default) | runtime-prebuilt (CI)

# Stage 1: Builder (compila desde source - desarrollo local)
FROM golang:${GO_VERSION}-alpine AS builder
# - Copia go.mod/go.sum primero (layer caching)
# - go mod download (cached si deps no cambian)
# - CGO_ENABLED=0 para binary estático

# Stage 2: Prebuilt (copia binario pre-compilado - CI)
FROM scratch AS prebuilt
# - Espera binario en services/<service>/<service>
# - Usado por Harness CI con Cache Intelligence

# Stage 3a: runtime (default - usa builder)
FROM alpine:${ALPINE_VERSION} AS runtime
# - COPY --from=builder /app /app/service
# - Compila dentro de Docker (local dev)

# Stage 3b: runtime-prebuilt (CI target)
FROM alpine:${ALPINE_VERSION} AS runtime-prebuilt
# - COPY --from=prebuilt /app /app/service
# - Solo 5-10MB final image
# - Non-root user (appuser:appgroup)
```

**Uso:**

| Escenario | Comando | --target |
|-----------|---------|----------|
| Local dev | `task build SERVICE=movie` | `runtime-prebuilt` (task compila primero) |
| docker-compose | `docker compose up` | `runtime` (default) |
| CI Pipeline | BuildAndPushDockerRegistry | `runtime-prebuilt` |

**Beneficios:**
- Imagen final ~10MB vs ~800MB con SDK
- Sin toolchain de compilación en runtime
- Healthchecks nativos de Docker
- **CI optimizado**: Cache Intelligence para Go modules + Docker layer caching

---

## 5. Stack de Infraestructura

### 5.1 MongoDB Replica Set

**Configuración en Docker Compose:**

```yaml
# Dev: 3 nodos con volumes persistentes
mongo1, mongo2, mongo3  →  rs0 (1 PRIMARY, 2 SECONDARY)

# Test: 1 nodo con tmpfs (efímero)
mongo  →  rs0 (single-node)
```

**¿Por qué replica set incluso en local?**
- Transactions requieren replica set (desde MongoDB 4.0)
- Change streams requieren oplog
- Paridad con producción

**Inicialización automática:**

```bash
# platform/docker/mongodb/Dockerfile
# Ejecuta init.sh que:
# 1. rs.initiate() con members
# 2. Espera PRIMARY election
# 3. Ejecuta seed scripts (04-seed-test-data.js)
```

### 5.2 Redis

**Uso principal:** Distributed locks para seat holds

```yaml
redis-dev:
  image: redis:7-alpine
  volumes:
    - redis_data:/data    # Persistencia AOF

redis-test:
  tmpfs:
    - /data               # Efímero para tests
```

**Monitoreo de locks:**

```bash
# Ver todos los holds activos
docker exec dev-redis redis-cli KEYS "seat_hold:*"

# Inspeccionar un hold específico
docker exec dev-redis redis-cli GET "hold:uuid-here"

# TTL de un seat hold
docker exec dev-redis redis-cli TTL "seat_hold:sht_001:A1"
```

### 5.3 NATS (Planned)

> **Nota:** NATS está definido en docker-compose pero **no está implementado** en los servicios actualmente. Está reservado para futuras features como:
> - Event sourcing
> - Pub/sub para notificaciones en tiempo real
> - CQRS con proyecciones

```yaml
# docker-compose.yml - disponible pero no consumido
nats:
  image: nats:2.10-alpine
  ports:
    - "4222:4222"   # Client connections
    - "8222:8222"   # HTTP monitoring
```

### 5.4 Networking

```yaml
networks:
  cinema-network:
    name: cinema-${ENV_PREFIX:-dev}-network
```

**Resolución DNS interna:**
- Desde DevContainer: `http://movie:8002`
- Desde host: `http://localhost:8002`

**Hostnames disponibles:**
`mongo1`, `mongo2`, `mongo3`, `mongo`, `redis`, `nats`, `movie`, `cinema`, `user`, `showtime`, `seat`, `payment`, `notification`, `booking`

---

## 6. Configuración y Despliegue

### 6.1 Prerequisitos

```bash
# Verificar versiones
docker --version          # ≥ 24.x
docker compose version    # ≥ v2.x
task --version            # ≥ 3.x (opcional pero recomendado)
```

### 6.2 Generar Configuración

```bash
# Source of truth: platform/config/services.yaml
# Genera: platform/deploy/docker-compose/.env
task config:generate

# Verificar configuración generada
task config:show
```

### 6.3 Levantar Entorno

```bash
# Opción 1: Con Task (recomendado)
task dev:up

# Opción 2: Docker Compose directo
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d
```

**Primera vez:** 3-5 minutos (build de imágenes + init MongoDB)
**Subsecuentes:** 30-60 segundos

### 6.4 Perfiles Disponibles

| Perfil | MongoDB | Storage | Caso de uso |
|--------|---------|---------|-------------|
| `dev` | 3 replicas | Volumes | Desarrollo diario |
| `test` | 1 nodo | tmpfs | Tests rápidos, CI |
| `debug` | 3 replicas | Volumes | + puertos de debug |
| `perf` | 3 replicas | Volumes | Load testing |
| `e2e` | (con test) | tmpfs | E2E test runner |

```bash
# Cambiar perfil
docker compose --profile test up -d
docker compose --profile debug up -d
```

### 6.5 Variables de Entorno Clave

```bash
# .env generado
ENV_PREFIX=dev                    # Prefijo de containers
MONGO_SERVERS=mongo1:27017        # Connection string
VERSION=dev                       # Tag de imágenes
HOLD_TTL_SECONDS=300              # TTL de seat holds (5 min)
JWT_SECRET=dev-secret-change-in-production
```

---

## 7. Seguridad

### 7.1 Consideraciones de Seguridad para Desarrollo Local

> **ADVERTENCIA:** Esta configuración es para desarrollo local únicamente. NO usar en producción sin los cambios indicados.

| Componente | Estado Dev | Acción para Producción |
|------------|------------|------------------------|
| **JWT_SECRET** | `dev-secret-change-in-production` | Generar secret fuerte (256+ bits), almacenar en secrets manager |
| **MongoDB** | Sin autenticación | Habilitar auth, crear usuarios con least privilege |
| **Redis** | Sin password | Configurar `requirepass`, usar TLS |
| **Stripe keys** | Mock (`pk_test_mock`) | Usar keys reales de Stripe Dashboard |
| **TLS/HTTPS** | No configurado | Terminar TLS en ingress/load balancer |
| **Network** | Todos los puertos expuestos | Solo exponer gateway, servicios internos sin puertos públicos |

### 7.2 Autenticación JWT

El servicio `user` implementa JWT con tokens de acceso y refresh:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          JWT Token Flow                                     │
└─────────────────────────────────────────────────────────────────────────────┘

  ┌────────┐                                    ┌────────────┐
  │ Client │                                    │   user     │
  └───┬────┘                                    │  service   │
      │                                         └─────┬──────┘
      │  POST /users/login                            │
      │  {email, password}                            │
      │──────────────────────────────────────────────>│
      │                                               │
      │  200 OK                                       │
      │  {                                            │
      │    access_token: "eyJ..." (TTL: 15min)       │
      │    refresh_token: "eyJ..." (TTL: 7 days)     │
      │    expires_in: 900                            │
      │  }                                            │
      │<──────────────────────────────────────────────│
      │                                               │
      │  GET /users/me                                │
      │  Authorization: Bearer {access_token}         │
      │──────────────────────────────────────────────>│
      │                                               │
      │  200 OK {user profile}                        │
      │<──────────────────────────────────────────────│
      │                                               │
      │  ... access_token expires ...                 │
      │                                               │
      │  POST /users/refresh                          │
      │  {refresh_token: "eyJ..."}                    │
      │──────────────────────────────────────────────>│
      │                                               │
      │  200 OK {new access_token, new refresh_token} │
      │<──────────────────────────────────────────────│
      │                                               │
      │  POST /users/logout                           │
      │  Authorization: Bearer {access_token}         │
      │──────────────────────────────────────────────>│
      │                                               │
      │  200 OK (token blacklisted in Redis)          │
      │<──────────────────────────────────────────────│
```

### 7.3 Validaciones de Input

| Servicio | Campo | Validación |
|----------|-------|------------|
| user | password | Mínimo 8 caracteres |
| user | email | Formato válido, único |
| seat | session_id | Mínimo 10 caracteres |
| seat | seat_ids | Máximo 10 asientos por hold |
| booking | hold_id | UUID válido, no expirado |

---

## 8. Validación del Sistema

### 8.1 Estado de Contenedores

```bash
# Vista rápida
task dev:status

# O manualmente
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps
```

**Estado esperado:**
- Todos los servicios: `healthy`
- `dev-mongo-init`: `Exited (0)` — es un init container

### 8.2 Health Checks Sistemáticos

```bash
# Script de validación completa
services=("booking:8001" "movie:8002" "cinema:8003" "user:8004" "seat:8005" "showtime:8006" "payment:8007" "notification:8008")

for svc in "${services[@]}"; do
  name="${svc%%:*}"; port="${svc##*:}"
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 http://$name:$port/health/live)
  printf "%-15s %s\n" "$name:" "$([[ $status == 200 ]] && echo '✓ healthy' || echo '✗ unhealthy')"
done
```

### 8.3 Validación de Infraestructura

**MongoDB Replica Set:**

```bash
# Estado del replica set
docker exec dev-mongo1 mongosh --quiet --eval "
  rs.status().members.forEach(m => 
    print(m.name + ' → ' + m.stateStr + ' (health: ' + m.health + ')')
  )
"

# Esperado:
# mongo1:27017 → PRIMARY (health: 1)
# mongo2:27017 → SECONDARY (health: 1)
# mongo3:27017 → SECONDARY (health: 1)
```

**Redis:**

```bash
docker exec dev-redis redis-cli ping
# Esperado: PONG

# Info de memoria
docker exec dev-redis redis-cli INFO memory | grep used_memory_human
```

### 8.4 Verificación de Seed Data

```bash
# Contar documentos por base de datos
for db in movie cinema showtime seat; do
  count=$(docker exec dev-mongo1 mongosh $db --quiet --eval "
    db.getCollectionNames().map(c => c + ':' + db.getCollection(c).countDocuments()).join(', ')
  ")
  echo "$db → $count"
done

# Esperado:
# movie → movies:2
# cinema → cinemas:1, rooms:2
# showtime → showtimes:2
# seat → room_layouts:1, showtimes:2
```

---

## 9. Flujos de Negocio

### 9.1 Catálogo de Películas

```bash
# Listar películas
curl -s http://movie:8002/movies | jq '.movies[] | {id, title, duration}'

# Detalle de película
curl -s http://movie:8002/movies/mov_shawshank | jq '{title, director, synopsis}'

# Películas en premiere
curl -s http://movie:8002/movies/premieres | jq '.movies'
```

### 9.2 Autenticación Completa

```bash
# 1. Registro (password mínimo 8 caracteres)
curl -s -X POST http://user:8004/users/register \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@test.com","name":"Demo User","password":"demo12345"}' | jq '.'

# 2. Login
TOKENS=$(curl -s -X POST http://user:8004/users/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@test.com","password":"demo12345"}')

ACCESS_TOKEN=$(echo $TOKENS | jq -r '.access_token')
REFRESH_TOKEN=$(echo $TOKENS | jq -r '.refresh_token')

echo "Access Token: ${ACCESS_TOKEN:0:50}..."
echo "Refresh Token: ${REFRESH_TOKEN:0:50}..."

# 3. Perfil autenticado
curl -s http://user:8004/users/me \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.user'

# 4. Actualizar perfil
curl -s -X PUT http://user:8004/users/me \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Updated Name"}' | jq '.'

# 5. Ver mis reservas
curl -s http://user:8004/users/me/bookings \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.'

# 6. Refresh token
curl -s -X POST http://user:8004/users/refresh \
  -H "Content-Type: application/json" \
  -d "{\"refresh_token\":\"$REFRESH_TOKEN\"}" | jq '.'

# 7. Logout (blacklist token)
curl -s -X POST http://user:8004/users/logout \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.'
```

### 9.3 Consulta de Funciones

```bash
# Listar showtimes
curl -s http://showtime:8006/showtimes | jq '.data[] | {id, movie_id, start_time, price}'

# Detalle de showtime
curl -s http://showtime:8006/showtimes/sht_001 | jq '.'
```

### 9.4 Disponibilidad de Asientos

```bash
# Ver mapa de asientos
curl -s "http://seat:8005/seats/availability?showtime_id=sht_001" | jq '{
  room: .room_id,
  layout: "\(.room_layout.rows)x\(.room_layout.columns)",
  summary: .summary
}'

# Esperado:
# {
#   "room": "room_001",
#   "layout": "10x10",
#   "summary": { "total": 100, "available": 100, "held": 0, "reserved": 0 }
# }
```

### 9.5 Flujo Completo de Reserva

```bash
#!/bin/bash
# E2E booking flow

echo "=== Step 1: Get showtime ==="
SHOWTIME_ID=$(curl -s http://showtime:8006/showtimes | jq -r '.data[0].id')
echo "Showtime: $SHOWTIME_ID"

echo -e "\n=== Step 2: Check availability ==="
curl -s "http://seat:8005/seats/availability?showtime_id=$SHOWTIME_ID" | jq '.summary'

echo -e "\n=== Step 3: Hold seats ==="
SESSION_ID="session_$(date +%s)_demo"
HOLD_RESPONSE=$(curl -s -X POST http://seat:8005/seats/hold \
  -H "Content-Type: application/json" \
  -d "{\"showtime_id\":\"$SHOWTIME_ID\",\"seat_ids\":[\"A1\",\"A2\"],\"session_id\":\"$SESSION_ID\"}")
HOLD_ID=$(echo $HOLD_RESPONSE | jq -r '.hold_id')
echo "Hold ID: $HOLD_ID"
echo "Expires: $(echo $HOLD_RESPONSE | jq -r '.expires_at')"
echo "TTL: $(echo $HOLD_RESPONSE | jq -r '.ttl_seconds')s"

echo -e "\n=== Step 4: Verify hold in Redis ==="
docker exec dev-redis redis-cli TTL "seat_hold:${SHOWTIME_ID}:A1"

echo -e "\n=== Step 5: Create booking ==="
BOOKING=$(curl -s -X POST http://booking:8001/booking \
  -H "Content-Type: application/json" \
  -d "{
    \"booking\": {
      \"showtime_id\": \"$SHOWTIME_ID\",
      \"hold_id\": \"$HOLD_ID\",
      \"session_id\": \"$SESSION_ID\",
      \"payment\": {
        \"card_number\": \"4242424242424242\",
        \"exp_month\": 12,
        \"exp_year\": 2027,
        \"cvv\": \"123\"
      }
    }
  }")
echo "$BOOKING" | jq '{msg, payment, ticket: .ticket.order_id}'

echo -e "\n=== Step 6: Verify seat reserved in MongoDB ==="
docker exec dev-mongo1 mongosh seat --quiet --eval "
  db.reservations.findOne({showtime_id: '$SHOWTIME_ID'}, {seat_ids: 1, booking_id: 1})
"
```

---

## 10. Troubleshooting Avanzado

### 10.1 Container en "Restarting" Loop

**Síntoma:** `docker ps` muestra estado `Restarting (1)`

**Diagnóstico:**

```bash
# Ver últimos logs
docker logs cinema-seat --tail 100

# Patrones comunes:
# "connection refused" → Dependencia no disponible
# "no reachable servers" → MongoDB replica set no inicializado
# "context deadline exceeded" → Timeout de conexión
```

**Solución típica (timing de MongoDB):**

```bash
# Esperar a que MongoDB esté ready
docker exec dev-mongo1 mongosh --quiet --eval "rs.status().ok"
# Debe retornar: 1

# Reiniciar servicios afectados
docker restart cinema-seat cinema-cinema

# Verificar recovery
docker logs cinema-seat --tail 20 --follow
```

### 10.2 Replica Set No Inicializado

**Síntoma:** Servicios fallan con "no reachable servers"

**Diagnóstico:**

```bash
# Verificar estado de mongo-init
docker logs dev-mongo-init

# Check si rs.initiate() ejecutó
docker exec dev-mongo1 mongosh --quiet --eval "rs.status().set"
# Si retorna null → no inicializado
```

**Solución:**

```bash
# Opción 1: Re-ejecutar init container
docker restart dev-mongo-init

# Opción 2: Inicializar manualmente
docker exec dev-mongo1 mongosh --eval "
  rs.initiate({
    _id: 'rs0',
    members: [
      {_id: 0, host: 'mongo1:27017', priority: 3},
      {_id: 1, host: 'mongo2:27017', priority: 2},
      {_id: 2, host: 'mongo3:27017', priority: 1}
    ]
  })
"

# Esperar election (10-30s)
sleep 15

# Verificar PRIMARY
docker exec dev-mongo1 mongosh --quiet --eval "rs.status().members.find(m => m.stateStr === 'PRIMARY').name"
```

### 10.3 Datos de Seed No Cargados

**Síntoma:** APIs retornan arrays vacíos

**Diagnóstico:**

```bash
# Verificar conteo de documentos
docker exec dev-mongo1 mongosh movie --quiet --eval "db.movies.countDocuments()"
# Si es 0 → seed no ejecutó
```

**Solución:**

```bash
# Re-ejecutar seed manualmente
docker exec dev-mongo1 mongosh < platform/docker/mongodb/seed/04-seed-test-data.js

# O reiniciar todo limpio
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down -v
task dev:up
```

### 10.4 Seat Hold Expirado Durante Booking

**Síntoma:** Booking falla con `HOLD_EXPIRED`

**Diagnóstico:**

```bash
# Verificar si hold existe en Redis
docker exec dev-redis redis-cli GET "hold:$HOLD_ID"
# Si retorna (nil) → expiró

# Ver TTL configurado
echo $HOLD_TTL_SECONDS  # Default: 300 (5 min)
```

**Root cause:** El hold tiene TTL de 5 minutos. Si el usuario tarda más, el hold expira automáticamente.

**Prevención en tests:**

```bash
# Para E2E tests, usar TTL corto
HOLD_TTL_SECONDS=30 docker compose --profile test up -d
```

### 10.5 Conflicto de Puertos

**Síntoma:** `bind: address already in use`

**Diagnóstico:**

```bash
# Identificar proceso usando el puerto
lsof -i :8002

# O con netstat
netstat -tlnp | grep 8002
```

**Solución:**

```bash
# Detener compose anterior
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down

# Matar proceso huérfano si es necesario
kill -9 $(lsof -t -i :8002)
```

### 10.6 Debugging con Logs Estructurados

**Habilitar debug logging:**

```bash
# Ver logs con contexto
docker logs cinema-booking 2>&1 | grep -E "(SAGA|error|Error)"

# Seguir logs en tiempo real
docker logs cinema-booking --follow | jq -R '. as $line | try (fromjson) catch $line'
```

**Tracing de una request:**

```bash
# Los servicios usan tracing spans
# Buscar por operación
docker logs cinema-booking 2>&1 | grep "make-booking-handler-saga"
```

### 10.7 MongoDB Query Debugging

```bash
# Habilitar profiling (nivel 2 = todas las queries)
docker exec dev-mongo1 mongosh movie --eval "db.setProfilingLevel(2)"

# Ejecutar operación...

# Ver queries lentas
docker exec dev-mongo1 mongosh movie --eval "
  db.system.profile.find().sort({millis: -1}).limit(5).forEach(printjson)
"

# Deshabilitar profiling
docker exec dev-mongo1 mongosh movie --eval "db.setProfilingLevel(0)"
```

### 10.8 Redis Lock Debugging

```bash
# Ver todos los holds activos
docker exec dev-redis redis-cli KEYS "hold:*" | while read key; do
  echo "=== $key ==="
  docker exec dev-redis redis-cli GET "$key" | jq .
done

# Ver seats held para un showtime
docker exec dev-redis redis-cli KEYS "seat_hold:sht_001:*"

# Limpiar holds manualmente (testing only)
docker exec dev-redis redis-cli KEYS "seat_hold:*" | xargs -r docker exec -i dev-redis redis-cli DEL
```

### 10.9 Network Debugging

```bash
# Verificar DNS resolution desde un servicio
docker exec cinema-movie ping -c 1 mongo1

# Verificar conectividad entre servicios
docker exec cinema-booking wget -qO- http://seat:8005/health/live

# Inspeccionar network
docker network inspect cinema-dev-network
```

### 10.10 Container Resource Issues

```bash
# Ver uso de recursos
docker stats --no-stream

# Límites configurados por servicio (platform/config/services.yaml)
# cpu_request: 50m-100m
# mem_request: 64Mi-128Mi
# cpu_limit: 250m-500m
# mem_limit: 256Mi-512Mi

# Si un container es OOMKilled
docker inspect cinema-seat | jq '.[0].State.OOMKilled'
```

---

## 11. Referencia Rápida

### 11.1 Task Commands

| Comando | Descripción |
|---------|-------------|
| `task dev:up` | Levantar entorno dev |
| `task dev:down` | Detener entorno |
| `task dev:status` | Ver estado de containers |
| `task dev:logs` | Ver logs agregados |
| `task config:generate` | Generar .env desde services.yaml |
| `task config:show` | Mostrar configuración actual |
| `task test:e2e` | Ejecutar tests E2E |

### 11.2 Endpoints por Servicio

| Servicio | Endpoints |
|----------|-----------|
| **movie** | `GET /movies`, `GET /movies/all`, `GET /movies/:id`, `GET /movies/premieres` |
| **user** | `POST /users/register`, `POST /users/login`, `POST /users/refresh`, `POST /users/logout`, `GET /users/me`, `PUT /users/me`, `GET /users/me/bookings` |
| **showtime** | `GET /showtimes`, `GET /showtimes/:id`, `POST /showtimes`, `PUT /showtimes/:id`, `DELETE /showtimes/:id` |
| **seat** | `GET /seats/availability?showtime_id=X`, `POST /seats/hold`, `GET /seats/hold/:hold_id`, `DELETE /seats/hold/:hold_id`, `POST /seats/reserve`, `POST /seats/layout`, `GET /seats/layout/:room_id` |
| **booking** | `POST /booking`, `GET /booking/:orderId` |
| **cinema** | `GET /cinemas`, `GET /cinemas/:id`, `POST /cinemas`, `GET /cinemas/:id/rooms`, `POST /cinemas/:id/rooms` |
| **payment** | `POST /payments/makePurchase`, `GET /payments/:id`, `POST /payments/:id/refund` |
| **notification** | `POST /notification/sendEmail`, `POST /notification/sendSMS` |
| **all** | `GET /health/live`, `GET /health/ready`, `GET /ping` |

### 11.3 Estructura de Archivos

```
platform/
├── config/
│   └── services.yaml              # Source of truth
├── deploy/
│   └── docker-compose/
│       ├── docker-compose.yml     # Definición de servicios
│       └── .env                   # Generado por config:generate
└── docker/
    ├── go-service/
    │   └── Dockerfile             # Multi-stage build para Go
    ├── mongodb/
    │   ├── Dockerfile             # Init container
    │   └── seed/*.js              # Scripts de inicialización
    └── e2e-runner/
        └── Dockerfile             # Test runner container

services/
├── booking/                       # SAGA orchestrator
│   └── contracts/consumer/        # Contract tests
├── movie/                         # Catálogo
├── cinema/                        # Cines y salas
├── user/                          # Auth + JWT
├── seat/                          # Locks y reservas
├── showtime/                      # Funciones
├── payment/                       # Mock payments
└── notification/                  # Mock notifications
```

### 11.4 Quick Diagnostic Commands

```bash
# Estado general
task dev:status && echo "---" && docker exec dev-redis redis-cli ping

# Verificar todo el stack
for svc in movie:8002 user:8004 booking:8001 seat:8005 showtime:8006; do
  curl -s -o /dev/null -w "${svc%%:*}: %{http_code}\n" http://${svc}/health/live
done

# MongoDB status
docker exec dev-mongo1 mongosh --quiet --eval "rs.status().members.map(m => m.name + ':' + m.stateStr)"

# Redis keys count
docker exec dev-redis redis-cli DBSIZE

# Logs recientes con errores
docker compose -f platform/deploy/docker-compose/docker-compose.yml logs --tail 50 2>&1 | grep -i error
```

### 11.5 Códigos de Error Comunes

| Código | HTTP | Servicio | Significado |
|--------|------|----------|-------------|
| `INVALID_REQUEST` | 400 | all | Campos requeridos faltantes o inválidos |
| `HOLD_EXPIRED` | 404 | seat/booking | El hold expiró (TTL 5min) |
| `HOLD_NOT_FOUND` | 404 | seat | Hold ID no existe |
| `SEATS_UNAVAILABLE` | 409 | seat | Asientos ya held/reserved |
| `SHOWTIME_NOT_FOUND` | 404 | showtime/booking | Showtime ID no existe |
| `SHOWTIME_UNAVAILABLE` | 409 | booking | Showtime cancelado o pasado |
| `PAYMENT_FAILED` | 500 | booking | Error en procesamiento de pago |
| `UNAUTHORIZED` | 401 | user | Token inválido o expirado |
| `EMAIL_EXISTS` | 409 | user | Email ya registrado |

---

## Documentación Relacionada

- [Development Guide](../development/README.md) — Setup de desarrollo local
- [API Reference](../api/) — OpenAPI specs por servicio
- [Contract Tests](../api/contracts.md) — Consumer-driven contracts
