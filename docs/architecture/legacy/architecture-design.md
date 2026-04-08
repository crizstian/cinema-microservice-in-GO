# Diseño de Arquitectura - Cinema Ticketing System
## Spec Driven Development

**Fecha:** 2026-04-07  
**Versión:** 1.0  
**Estado:** Propuesta

---

## 1. Arquitectura de Microservicios Completa

### 1.1 Vista General (C4 - System Context)

```
                                    ┌─────────────────────────────────────┐
                                    │         External Systems            │
                                    │  ┌─────────┐  ┌─────────┐  ┌──────┐│
                                    │  │ Stripe  │  │  Gmail  │  │Twilio││
                                    │  │   API   │  │  SMTP   │  │ SMS  ││
                                    │  └────┬────┘  └────┬────┘  └──┬───┘│
                                    └───────┼────────────┼──────────┼────┘
                                            │            │          │
┌──────────────────┐                ┌───────┴────────────┴──────────┴────┐
│                  │    HTTPS       │                                    │
│   Web Client     │───────────────▶│         Cinema Ticketing           │
│   (Future SPA)   │◀───────────────│            System                  │
│                  │                │                                    │
└──────────────────┘                └────────────────────────────────────┘
                                                    ▲
┌──────────────────┐                                │
│                  │    HTTPS                       │
│  Mobile Client   │────────────────────────────────┘
│  (Future App)    │
│                  │
└──────────────────┘
```

### 1.2 Vista de Contenedores (C4 - Container Level)

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                 CINEMA TICKETING SYSTEM                                  │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                              EDGE LAYER                                          │   │
│  │  ┌───────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │                         API Gateway (Kong)                                 │  │   │
│  │  │  • JWT Validation    • Rate Limiting    • Request Routing                 │  │   │
│  │  │  • CORS              • Load Balancing   • API Versioning                  │  │   │
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
│  │  │ • Register  │  │ • List all  │  │ • List      │  │ • List by   │             │   │
│  │  │ • Login     │  │ • Premieres │  │ • Rooms     │  │   movie     │             │   │
│  │  │ • Profile   │  │ • By ID     │  │ • Details   │  │ • By cinema │             │   │
│  │  │ • JWT       │  │             │  │             │  │ • CRUD      │             │   │
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
│  │  │ • Availab.  │  │ • Create    │  │ • Charge    │                              │   │
│  │  │ • Hold      │  │ • Get       │  │ • Refund    │                              │   │
│  │  │ • Reserve   │  │ • Cancel    │  │ • Get       │                              │   │
│  │  │ • Layout    │  │ • History   │  │             │                              │   │
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
│  │  │   • Email (Gmail SMTP)   • SMS (Twilio)   • Push (future)                   ││  │
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

## 2. Interacciones entre Servicios (Sync vs Async)

### 2.1 Matriz de Comunicación

| Origen | Destino | Tipo | Protocolo | Timeout | Retry | Propósito |
|--------|---------|------|-----------|---------|-------|-----------|
| Gateway | user | **SYNC** | HTTP/REST | 5s | 3 | Auth, perfil |
| Gateway | movie | **SYNC** | HTTP/REST | 5s | 3 | Catálogo películas |
| Gateway | cinema | **SYNC** | HTTP/REST | 5s | 3 | Catálogo cines |
| Gateway | showtime | **SYNC** | HTTP/REST | 5s | 3 | Horarios |
| Gateway | seat | **SYNC** | HTTP/REST | 3s | 2 | Disponibilidad, holds |
| Gateway | booking | **SYNC** | HTTP/REST | 30s | 1 | Crear reserva |
| booking | showtime | **SYNC** | HTTP/REST | 3s | 2 | Validar horario |
| booking | seat | **SYNC** | HTTP/REST | 3s | 2 | Validar/confirmar asientos |
| booking | payment | **SYNC** | HTTP/REST | 30s | 1 | Procesar pago |
| booking | notification | **ASYNC** | RabbitMQ | - | 5 | Enviar confirmación |
| seat | seat-expiry-worker | **ASYNC** | Redis PubSub | - | - | Liberar holds expirados |
| showtime | movie | **SYNC** | HTTP/REST | 3s | 2 | Validar película existe |
| showtime | cinema | **SYNC** | HTTP/REST | 3s | 2 | Validar sala existe |

### 2.2 Diagrama de Flujo de Comunicación

```
┌──────────────────────────────────────────────────────────────────────────────────────┐
│                           FLUJO DE COMPRA DE TICKET                                   │
└──────────────────────────────────────────────────────────────────────────────────────┘

 SYNC (HTTP)                                              ASYNC (RabbitMQ)
 ─────────────                                            ──────────────────

 ┌────────┐     ┌────────┐     ┌──────────┐     ┌────────┐
 │ Client │────▶│Gateway │────▶│  user    │     │        │
 │        │◀────│        │◀────│ (login)  │     │        │
 └────────┘     └────────┘     └──────────┘     │        │
      │              │                          │        │
      │              │         ┌──────────┐     │        │
      │              │────────▶│ showtime │     │        │
      │              │◀────────│ (list)   │     │        │
      │              │         └──────────┘     │        │
      │              │                          │        │
      │              │         ┌──────────┐     │        │
      │              │────────▶│   seat   │     │        │
      │              │◀────────│(availab.)│     │        │
      │              │         └──────────┘     │        │
      │              │                          │        │
      │              │         ┌──────────┐     │        │
      │              │────────▶│   seat   │     │        │
      │              │◀────────│  (hold)  │     │        │
      │              │         └────┬─────┘     │        │
      │              │              │           │        │
      │              │              │ Redis     │        │
      │              │              │ SET+TTL   │        │
      │              │              ▼           │        │
      │              │         ┌──────────┐     │        │
      │              │         │  Redis   │     │        │
      │              │         │  (holds) │     │        │
      │              │         └──────────┘     │        │
      │              │                          │        │
      │              │         ┌──────────┐     │        │
      │              │────────▶│ booking  │     │RabbitMQ│
      │              │         │ (create) │     │        │
      │              │         └────┬─────┘     │        │
      │              │              │           │        │
      │              │    ┌─────────┼─────────┐ │        │
      │              │    │         │         │ │        │
      │              │    ▼         ▼         ▼ │        │
      │              │ ┌──────┐ ┌──────┐ ┌──────┐        │
      │              │ │seat  │ │payment│ │seat  │        │
      │              │ │valid.│ │charge │ │confm.│        │
      │              │ └──────┘ └──────┘ └──────┘        │
      │              │              │                    │
      │              │              │         ┌──────────┤
      │              │              │         │          │
      │              │              │         ▼          │
      │              │              │    ┌──────────┐    │
      │              │              │    │  Queue   │    │
      │              │              │────▶│booking. │    │
      │              │              │    │ created │    │
      │              │              │    └────┬─────┘    │
      │              │              │         │          │
      │              │◀─────────────│         │          │
      │◀─────────────│              │         ▼          │
      │   Ticket     │              │   ┌───────────┐    │
      │              │              │   │notification    │
      │              │              │   │  (email)  │    │
      │              │              │   └───────────┘    │
      │              │              │         │          │
      │              │              │         ▼          │
      │              │              │   ┌───────────┐    │
      │              │              │   │   Gmail   │    │
      │              │              │   │   SMTP    │    │
      │              │              │   └───────────┘    │
```

---

## 3. Servicios con Comunicación Event-Driven

### 3.1 Eventos del Sistema

| Evento | Producer | Consumer(s) | Queue/Topic | Prioridad |
|--------|----------|-------------|-------------|-----------|
| `booking.created` | booking | notification | booking.created.queue | Alta |
| `booking.cancelled` | booking | notification, payment | booking.cancelled.queue | Alta |
| `payment.failed` | payment | seat | payment.failed.queue | Alta |
| `seat.hold.expired` | Redis (TTL) | seat | seat.expired.queue | Media |
| `showtime.cancelled` | showtime | booking, notification | showtime.cancelled.queue | Alta |

### 3.2 Arquitectura de Mensajería

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              RABBITMQ EXCHANGES                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                    cinema.events (Topic Exchange)                        │   │
│  │                                                                          │   │
│  │   Routing Keys:                                                          │   │
│  │   • booking.created     → notification.queue                            │   │
│  │   • booking.cancelled   → notification.queue, payment.refund.queue      │   │
│  │   • payment.failed      → seat.release.queue                            │   │
│  │   • showtime.cancelled  → booking.notify.queue, notification.queue      │   │
│  │                                                                          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                    │
│  │ notification   │  │ payment.refund │  │  seat.release  │                    │
│  │    .queue      │  │    .queue      │  │    .queue      │                    │
│  │                │  │                │  │                │                    │
│  │ Consumer:      │  │ Consumer:      │  │ Consumer:      │                    │
│  │ notification   │  │ payment        │  │ seat           │                    │
│  │ service        │  │ service        │  │ service        │                    │
│  └────────────────┘  └────────────────┘  └────────────────┘                    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.3 Patrón SAGA para Booking (Compensaciones)

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        BOOKING SAGA - CHOREOGRAPHY                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   HAPPY PATH:                                                                    │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐                 │
│   │ Validate │───▶│  Process │───▶│ Confirm  │───▶│  Send    │                 │
│   │   Hold   │    │  Payment │    │  Seats   │    │  Email   │                 │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘                 │
│                                                                                  │
│   COMPENSATION (Payment Failed):                                                 │
│   ┌──────────┐    ┌──────────┐                                                  │
│   │ Validate │───▶│  Process │──X (FAIL)                                        │
│   │   Hold   │    │  Payment │                                                  │
│   └────┬─────┘    └──────────┘                                                  │
│        │                                                                         │
│        │ COMPENSATE                                                              │
│        ▼                                                                         │
│   ┌──────────┐                                                                  │
│   │ Release  │◀─── Event: payment.failed                                        │
│   │   Hold   │                                                                  │
│   └──────────┘                                                                  │
│                                                                                  │
│   COMPENSATION (Seat Confirm Failed):                                            │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐                                 │
│   │ Validate │───▶│  Process │───▶│ Confirm  │──X (FAIL)                        │
│   │   Hold   │    │  Payment │    │  Seats   │                                  │
│   └──────────┘    └────┬─────┘    └──────────┘                                  │
│                        │                                                         │
│                        │ COMPENSATE                                              │
│                        ▼                                                         │
│                   ┌──────────┐                                                  │
│                   │  Refund  │◀─── Event: seat.confirm.failed                   │
│                   │  Payment │                                                  │
│                   └──────────┘                                                  │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Stack Tecnológico por Servicio

### 4.1 Servicios Existentes (Mantener)

| Servicio | Runtime | Framework | DB | Observabilidad |
|----------|---------|-----------|-----|----------------|
| movie | Go 1.21 | Echo v4 | MongoDB | Logrus, Jaeger |
| booking | Go 1.21 | Echo v4 | MongoDB | Logrus, Jaeger |
| payment | Go 1.21 | Echo v4 | MongoDB | Logrus, Jaeger |
| notification | Go 1.21 | Echo v4 | - | Logrus |

### 4.2 Servicios Nuevos

| Servicio | Runtime | Framework | DB | Cache | Queue | Extras |
|----------|---------|-----------|-----|-------|-------|--------|
| **user** | Go 1.21 | Echo v4 | MongoDB | Redis (sessions) | - | JWT (golang-jwt), bcrypt |
| **cinema** | Go 1.21 | Echo v4 | MongoDB | Redis (read cache) | - | - |
| **showtime** | Go 1.21 | Echo v4 | MongoDB | Redis (read cache) | RabbitMQ | - |
| **seat** | Go 1.21 | Echo v4 | MongoDB | Redis (holds) | RabbitMQ | Distributed locks |

### 4.3 Infraestructura

| Componente | Tecnología | Propósito |
|------------|------------|-----------|
| API Gateway | Kong 3.x | Routing, auth, rate limiting |
| Message Broker | RabbitMQ 3.12 | Event-driven communication |
| Cache/Locks | Redis 7.x | Session storage, holds, distributed locks |
| Database | MongoDB 7.x | Persistent storage |
| Tracing | Jaeger | Distributed tracing |
| Metrics | Prometheus + Grafana | Monitoring, alerting |
| Logs | ELK Stack | Centralized logging |
| Container | Docker + K8s | Orchestration |

### 4.4 Dependencias Go Comunes

```go
// go.mod (shared dependencies)
require (
    github.com/labstack/echo/v4 v4.11.0      // Web framework
    go.mongodb.org/mongo-driver v1.13.0      // MongoDB driver
    github.com/redis/go-redis/v9 v9.3.0      // Redis client
    github.com/rabbitmq/amqp091-go v1.9.0    // RabbitMQ client
    github.com/golang-jwt/jwt/v5 v5.2.0      // JWT
    github.com/sirupsen/logrus v1.9.3        // Logging
    go.opentelemetry.io/otel v1.21.0         // OpenTelemetry
    github.com/stretchr/testify v1.8.4       // Testing
)
```

---

## 5. Architecture Decision Records (ADRs)

### ADR-001: Comunicación Síncrona para Flujo de Pago

**Contexto:** El flujo de booking involucra validación de asientos, procesamiento de pago, y confirmación.

**Decisión:** Usar comunicación **síncrona (HTTP)** para el flujo crítico de pago.

**Razón:**
- El usuario espera respuesta inmediata de su compra
- Necesitamos garantía de consistencia en el momento del pago
- Simplifica manejo de errores y rollback
- El flujo es corto (< 30 segundos)

**Consecuencias:**
- Mayor acoplamiento temporal entre servicios
- Requiere circuit breakers para resiliencia
- Necesita timeouts bien configurados

**Alternativas consideradas:**
- Async con polling: Descartado por complejidad en UX
- Async con webhooks: Viable para futuro (ej: pagos lentos como OXXO)

---

### ADR-002: Redis para Hold de Asientos

**Contexto:** Necesitamos bloquear asientos temporalmente mientras el usuario completa el pago.

**Decisión:** Usar **Redis con TTL** para holds temporales de asientos.

**Razón:**
- TTL nativo permite expiración automática
- Alto rendimiento para operaciones frecuentes
- Operaciones atómicas (SETNX) para evitar race conditions
- Pub/Sub para notificar expiración

**Consecuencias:**
- Añade Redis como dependencia de infraestructura
- Holds se pierden si Redis falla (aceptable - usuario puede reintentar)
- Necesita sincronización con MongoDB para estado final

**Implementación:**
```
Key: seat:hold:{showtime_id}:{seat_id}
Value: {session_id, user_id, created_at}
TTL: 300 seconds (5 min)
```

---

### ADR-003: RabbitMQ para Notificaciones

**Contexto:** El envío de emails/SMS no debe bloquear la respuesta al usuario.

**Decisión:** Usar **RabbitMQ** para comunicación async con notification-service.

**Razón:**
- Desacopla booking de notification
- Permite reintentos automáticos si SMTP falla
- Escalable - múltiples consumers
- Dead letter queue para mensajes fallidos

**Consecuencias:**
- Usuario recibe ticket antes que email (UX aceptable)
- Añade RabbitMQ como dependencia
- Necesita monitoreo de colas

**Alternativas consideradas:**
- Kafka: Overkill para volumen esperado
- Redis Streams: Menos features de mensajería
- SQS: Vendor lock-in con AWS

---

### ADR-004: Kong como API Gateway

**Contexto:** Necesitamos un punto de entrada único para todos los servicios.

**Decisión:** Usar **Kong** como API Gateway.

**Razón:**
- Open source con soporte enterprise
- Plugins nativos para JWT, rate limiting, CORS
- Integración con Prometheus para métricas
- Soporta service discovery con Kubernetes

**Consecuencias:**
- Punto único de fallo (mitigar con HA)
- Añade latencia (~1-5ms)
- Curva de aprendizaje para configuración

**Alternativas consideradas:**
- Traefik: Más simple pero menos plugins
- NGINX: Requiere más configuración manual
- AWS API Gateway: Vendor lock-in

---

### ADR-005: Spec Driven Development (OpenAPI First)

**Contexto:** Necesitamos consistencia entre documentación, implementación y tests.

**Decisión:** Adoptar **Spec Driven Development** con OpenAPI 3.0.

**Razón:**
- Contrato antes de código
- Genera documentación automática
- Permite contract testing
- Facilita code generation (stubs, clients)

**Proceso:**
1. Diseñar OpenAPI spec
2. Validar con Spectral
3. Generar modelos Go
4. Implementar handlers
5. Contract tests con spec

**Consecuencias:**
- Mayor tiempo inicial de diseño
- Specs deben mantenerse actualizadas
- Requiere disciplina del equipo

---

### ADR-006: Patrón SAGA con Coreografía

**Contexto:** El booking involucra múltiples servicios que deben compensarse si algo falla.

**Decisión:** Implementar **SAGA con coreografía** (event-driven).

**Razón:**
- Menor acoplamiento que orquestación
- Cada servicio maneja su compensación
- Escalable independientemente
- Más resiliente a fallos

**Consecuencias:**
- Más difícil de debuggear (distributed tracing obligatorio)
- Eventual consistency (no immediate)
- Requiere idempotencia en todos los handlers

**Alternativas consideradas:**
- Orquestación (saga orchestrator): Más simple de entender pero punto único de fallo
- 2PC: No viable en microservicios distribuidos

---

## 6. Lista de Especificaciones OpenAPI a Crear

### 6.1 Servicios Existentes (Documentar)

| Servicio | Archivo | Prioridad | Estado |
|----------|---------|-----------|--------|
| movie | `/services/movie/api/openapi.yaml` | Alta | Pendiente |
| booking | `/services/booking/api/openapi.yaml` | Alta | Pendiente |
| payment | `/services/payment/api/openapi.yaml` | Alta | Pendiente |
| notification | `/services/notification/api/openapi.yaml` | Media | Pendiente |

### 6.2 Servicios Nuevos (Diseñar + Implementar)

| Servicio | Archivo | Prioridad | Dependencias |
|----------|---------|-----------|--------------|
| user | `/services/user/api/openapi.yaml` | Alta | Ninguna |
| cinema | `/services/cinema/api/openapi.yaml` | Alta | Ninguna |
| showtime | `/services/showtime/api/openapi.yaml` | Alta | movie, cinema |
| seat | `/services/seat/api/openapi.yaml` | Crítica | showtime, cinema |

### 6.3 Resumen de Endpoints por Spec

```yaml
# user-service (8 endpoints)
POST   /users/register
POST   /users/login
POST   /users/refresh
POST   /users/logout
GET    /users/me
PUT    /users/me
GET    /users/me/bookings
DELETE /users/me

# cinema-service (6 endpoints)
GET    /cinemas
GET    /cinemas/{id}
GET    /cinemas/{id}/rooms
POST   /cinemas           # admin
POST   /cinemas/{id}/rooms # admin
PUT    /cinemas/{id}      # admin

# showtime-service (6 endpoints)
GET    /showtimes
GET    /showtimes/{id}
POST   /showtimes         # admin
PUT    /showtimes/{id}    # admin
DELETE /showtimes/{id}    # admin
GET    /showtimes/{id}/seats # → redirects to seat-service

# seat-service (6 endpoints)
GET    /seats/availability
POST   /seats/hold
DELETE /seats/hold/{holdId}
POST   /seats/reserve
GET    /seats/layout/{roomId}
POST   /seats/layout      # admin

# Total: 26 nuevos endpoints + 9 existentes = 35 endpoints
```

---

## 7. Orden de Implementación Recomendado

```
SPRINT 1-2: Fundaciones
├── OpenAPI specs para servicios existentes (movie, booking, payment, notification)
├── Configurar Kong API Gateway
└── Configurar RabbitMQ

SPRINT 3: Servicios Base
├── cinema-service (OpenAPI → Implement → Test)
└── user-service (OpenAPI → Implement → Test)

SPRINT 4-5: Servicios Core
├── showtime-service (OpenAPI → Implement → Test)
└── seat-service (OpenAPI → Implement → Test)

SPRINT 6: Integración
├── Refactorizar booking-service
├── Añadir refunds a payment-service
└── Migrar notification a async (RabbitMQ)

SPRINT 7: Testing & Hardening
├── Contract tests
├── E2E tests
├── Load testing
└── Chaos engineering
```

---

## Apéndice: Checklist de Validación

- [ ] Cada servicio tiene OpenAPI spec validada con Spectral
- [ ] Todos los endpoints tienen ejemplos de request/response
- [ ] Schemas reutilizados vía $ref
- [ ] Códigos de error documentados (400, 401, 404, 500)
- [ ] Timeouts configurados en cada cliente HTTP
- [ ] Circuit breakers implementados
- [ ] Dead letter queues configuradas
- [ ] Tracing distribuido funcionando
- [ ] Métricas exportadas a Prometheus
- [ ] Contract tests pasando
- [ ] E2E tests pasando
