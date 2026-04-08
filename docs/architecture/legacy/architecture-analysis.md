# Análisis de Arquitectura - Cinema Ticketing System

**Fecha:** 2026-04-07  
**Versión:** 1.0

---

## 1. Tabla Comparativa: Funcionalidad Actual vs Requerida

| Funcionalidad | Requerida | Actual | Gap | Severidad |
|---------------|-----------|--------|-----|-----------|
| **Catálogo de películas** | Ver películas, estrenos, detalles | GET /movies/all, /premieres, /:id | Parcial - Solo lectura, sin CRUD admin | Baja |
| **Registro de usuarios** | Crear cuenta, perfil, historial | No existe | Total | Alta |
| **Autenticación** | Login, JWT, sesiones | No existe | Total | Alta |
| **Catálogo de cines** | Listar cines por ciudad, salas | No existe | Total | Alta |
| **Horarios (Showtimes)** | Ver horarios por película/fecha | Solo string en booking, sin validación | Total | Alta |
| **Mapa de asientos** | Ver disponibilidad visual | No existe | Total | Crítica |
| **Bloqueo temporal de asientos** | Hold 5-10 min mientras paga | No existe | Total | Crítica |
| **Validación de disponibilidad** | Evitar doble reserva | No existe - acepta cualquier asiento | Total | Crítica |
| **Reserva de asientos** | Confirmar después de pago | Solo guarda strings sin validar | Total | Crítica |
| **Procesamiento de pagos** | Tarjeta de crédito | Stripe integrado | Completo | - |
| **Reembolsos** | Cancelar y devolver dinero | No implementado | Total | Media |
| **Notificación por email** | Confirmación de compra | SMTP Gmail funcionando | Completo | - |
| **Notificación por SMS** | Recordatorio de función | Stub - no implementado | Total | Baja |
| **Historial de compras** | Ver tickets anteriores | Solo GET por orderId específico | Parcial | Media |

---

## 2. Lista Priorizada de Gaps

### Prioridad CRÍTICA (Bloquean el flujo de compra)

| # | Gap | Impacto | Servicio Afectado |
|---|-----|---------|-------------------|
| 1 | **Sin gestión de asientos** | Permite vender el mismo asiento múltiples veces | booking |
| 2 | **Sin bloqueo temporal (hold)** | Usuario puede perder asiento mientras paga | booking |
| 3 | **Sin validación de horarios** | Acepta horarios inválidos o pasados | booking |
| 4 | **Sin catálogo de salas** | No sabe qué asientos existen en cada sala | - |

### Prioridad ALTA (Funcionalidad core incompleta)

| # | Gap | Impacto | Servicio Afectado |
|---|-----|---------|-------------------|
| 5 | **Sin autenticación** | No identifica al comprador, no hay historial | todos |
| 6 | **Sin catálogo de cines** | No sabe en qué cine está cada sala | booking |
| 7 | **Sin horarios estructurados** | Schedule es solo un string libre | booking |
| 8 | **Sin reembolsos** | No puede cancelar ni devolver dinero | payment |

### Prioridad MEDIA (Mejoras importantes)

| # | Gap | Impacto | Servicio Afectado |
|---|-----|---------|-------------------|
| 9 | **Historial de usuario incompleto** | Solo busca por orderId, no por usuario | booking |
| 10 | **Sin compensaciones (SAGA)** | Si falla después del pago, no hay rollback | booking |
| 11 | **Notificaciones síncronas** | Bloquea respuesta si SMTP es lento | notification |

### Prioridad BAJA (Nice to have)

| # | Gap | Impacto | Servicio Afectado |
|---|-----|---------|-------------------|
| 12 | **SMS no implementado** | Solo email disponible | notification |
| 13 | **Sin paginación en movies** | Problemas con catálogos grandes | movie |
| 14 | **Sin CRUD de películas** | Solo lectura, admin manual en DB | movie |

---

## 3. Propuesta de Nuevos Microservicios

### 3.1 user-service (NUEVO)

**Justificación:** Sin usuarios identificados no hay historial, membresías, ni seguridad.

```
Responsabilidades:
- Registro y login (JWT)
- Gestión de perfiles
- Membresías (normal, loyal, vip)
- Historial de compras (referencia a bookings)

Endpoints:
POST   /users/register
POST   /users/login
GET    /users/me
PUT    /users/me
GET    /users/me/bookings
POST   /users/logout

Dependencias: ninguna (servicio base)
Base de datos: MongoDB (colección users)
```

### 3.2 cinema-service (NUEVO)

**Justificación:** Necesario para saber qué cines existen, dónde están, y qué salas tienen.

```
Responsabilidades:
- Catálogo de cines por ciudad
- Salas por cine
- Información de ubicación y amenidades

Endpoints:
GET    /cinemas
GET    /cinemas/:id
GET    /cinemas/:id/rooms
POST   /cinemas (admin)
POST   /cinemas/:id/rooms (admin)

Dependencias: ninguna
Base de datos: MongoDB (colecciones cinemas, rooms)
```

### 3.3 showtime-service (NUEVO)

**Justificación:** Los horarios actualmente son strings sin estructura. Se necesita gestionar qué película se proyecta, en qué sala, a qué hora, con qué precio.

```
Responsabilidades:
- CRUD de horarios
- Precios por tipo (regular, VIP, niño)
- Estado de funciones (scheduled, cancelled, completed)
- Validación de conflictos de sala

Endpoints:
GET    /showtimes?movie_id=&date=&cinema_id=
GET    /showtimes/:id
POST   /showtimes (admin)
PUT    /showtimes/:id (admin)
DELETE /showtimes/:id (admin)

Dependencias: movie-service, cinema-service
Base de datos: MongoDB (colección showtimes)
```

### 3.4 seat-service (NUEVO) - EL MÁS CRÍTICO

**Justificación:** SIN ESTE SERVICIO EL SISTEMA PUEDE VENDER EL MISMO ASIENTO A MÚLTIPLES PERSONAS.

```
Responsabilidades:
- Layout de asientos por sala
- Disponibilidad en tiempo real por showtime
- Hold temporal (bloqueo de 5-10 min)
- Confirmación de reserva
- Liberación automática de holds expirados

Endpoints:
GET    /seats/availability?showtime_id=
POST   /seats/hold
DELETE /seats/hold/:hold_id
POST   /seats/reserve
GET    /seats/layout/:room_id (admin)
POST   /seats/layout (admin)

Dependencias: showtime-service, cinema-service
Base de datos: 
- Redis (holds temporales con TTL)
- MongoDB (reservas confirmadas, layouts)

Consideraciones de concurrencia:
- Operaciones atómicas para evitar race conditions
- Distributed locks para holds simultáneos
- TTL automático en Redis para expiración de holds
```

---

## 4. Diagrama de Arquitectura

### 4.1 Arquitectura ACTUAL (C4 - Container Level)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SISTEMA ACTUAL                                  │
│                         (Sin API Gateway, Sin Auth)                         │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌─────────────┐
    │   Cliente   │  (No existe frontend)
    │   (API)     │
    └──────┬──────┘
           │ HTTP directo a cada servicio
           │
    ┌──────┴──────────────────────────────────────────────────────┐
    │                                                              │
    ▼                    ▼                    ▼                    ▼
┌─────────┐        ┌─────────┐        ┌─────────┐        ┌─────────────┐
│  movie  │        │ booking │───────▶│ payment │        │notification │
│ :8001   │        │  :8000  │        │  :8002  │        │   :8003     │
└────┬────┘        └────┬────┘        └────┬────┘        └──────┬──────┘
     │                  │                  │                    │
     │                  │                  │                    │
     ▼                  ▼                  ▼                    ▼
┌─────────┐        ┌─────────┐        ┌─────────┐        ┌─────────────┐
│MongoDB  │        │MongoDB  │        │MongoDB  │        │  Gmail SMTP │
│ movies  │        │ booking │        │ payment │        │             │
└─────────┘        └─────────┘        └─────────┘        └─────────────┘
                                           │
                                           ▼
                                      ┌─────────┐
                                      │ Stripe  │
                                      │   API   │
                                      └─────────┘

Flujo actual de booking:
1. Cliente envía booking request (sin validación de asientos)
2. Booking llama a Payment (síncrono)
3. Booking guarda ticket en MongoDB
4. Booking llama a Notification (async en goroutine)

PROBLEMAS:
❌ Sin validación de asientos disponibles
❌ Sin autenticación
❌ Sin gestión de horarios
❌ Sin catálogo de cines
```

### 4.2 Arquitectura OBJETIVO (C4 - Container Level)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           SISTEMA OBJETIVO                                   │
│                    (Con API Gateway, Auth, Seat Management)                  │
└─────────────────────────────────────────────────────────────────────────────┘

                              ┌─────────────┐
                              │   Cliente   │
                              │ (Web/Mobile)│
                              └──────┬──────┘
                                     │ HTTPS
                                     ▼
                           ┌─────────────────┐
                           │   API Gateway   │
                           │  (Kong/Traefik) │
                           │   - JWT Valid   │
                           │   - Rate Limit  │
                           │   - Routing     │
                           └────────┬────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
   ┌─────────┐               ┌─────────┐               ┌─────────────┐
   │  user   │               │  movie  │               │   cinema    │
   │ :8004   │               │ :8001   │               │   :8005     │
   │  NEW    │               │(existing)│              │    NEW      │
   └────┬────┘               └────┬────┘               └──────┬──────┘
        │                         │                           │
        ▼                         ▼                           ▼
   ┌─────────┐               ┌─────────┐               ┌─────────────┐
   │MongoDB  │               │MongoDB  │               │  MongoDB    │
   │  users  │               │ movies  │               │cinemas/rooms│
   └─────────┘               └─────────┘               └─────────────┘


        ┌───────────────────────────┬───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
   ┌──────────┐              ┌─────────┐               ┌─────────────┐
   │ showtime │◀─────────────│ booking │──────────────▶│    seat     │
   │  :8006   │   validate   │  :8000  │   hold/reserve│   :8007     │
   │   NEW    │              │(refactor)│              │    NEW      │
   └────┬─────┘              └────┬────┘               └──────┬──────┘
        │                         │                           │
        ▼                         │                      ┌────┴────┐
   ┌─────────┐                    │                      ▼         ▼
   │MongoDB  │                    │                 ┌───────┐ ┌───────┐
   │showtimes│                    │                 │ Redis │ │MongoDB│
   └─────────┘                    │                 │(holds)│ │(seats)│
                                  │                 └───────┘ └───────┘
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
        ▼                         ▼                         ▼
   ┌─────────┐              ┌───────────┐            ┌─────────────┐
   │ payment │              │  Message  │            │notification │
   │  :8002  │              │   Queue   │            │   :8003     │
   │(+refund)│              │ (RabbitMQ)│───────────▶│  (async)    │
   └────┬────┘              └───────────┘            └──────┬──────┘
        │                                                   │
   ┌────┴────┐                                        ┌─────┴─────┐
   ▼         ▼                                        ▼           ▼
┌───────┐ ┌───────┐                              ┌───────┐   ┌───────┐
│MongoDB│ │Stripe │                              │ Gmail │   │Twilio │
│payment│ │  API  │                              │ SMTP  │   │  SMS  │
└───────┘ └───────┘                              └───────┘   └───────┘
```

### 4.3 Flujo de Compra OBJETIVO (Sequence)

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
   │ hold_id     │           │           │  expires_at          │           │           │
   │             │           │           │           │           │           │           │
   │ 5. Create Booking (with hold_id, payment info)  │           │           │           │
   │────────────▶│───────────────────────────────────────────────▶           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │    ┌──────┴──────┐    │           │           │
   │             │           │           │    │5a.Validate  │    │           │           │
   │             │           │           │◀───│   Hold      │    │           │           │
   │             │           │           │───▶│   exists    │    │           │           │
   │             │           │           │    └─────────────┘    │           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │           │    ┌──────┴──────┐    │           │
   │             │           │           │           │    │5b. Process  │    │           │
   │             │           │           │           │    │   Payment   │───▶│           │
   │             │           │           │           │    │             │◀───│           │
   │             │           │           │           │    └─────────────┘    │           │
   │             │           │           │           │           │           │           │
   │             │           │           │    ┌──────┴──────┐    │           │           │
   │             │           │           │    │5c. Confirm  │    │           │           │
   │             │           │           │◀───│  Seats      │    │           │           │
   │             │           │           │───▶│ (permanent) │    │           │           │
   │             │           │           │    └─────────────┘    │           │           │
   │             │           │           │           │           │           │           │
   │             │           │           │           │    ┌──────┴──────┐    │           │
   │             │           │           │           │    │5d. Save     │    │           │
   │             │           │           │           │    │   Ticket    │    │           │
   │             │           │           │           │    └──────┬──────┘    │           │
   │             │           │           │           │           │           │           │
   │             │           │           │           │           │──────────────────────▶│
   │             │           │           │           │           │    5e. Send Email     │
   │             │           │           │           │           │◀──────────────────────│
   │             │           │           │           │           │           │           │
   │◀────────────│◀───────────────────────────────────────────────           │           │
   │  Ticket +   │           │           │           │           │           │           │
   │  Receipt    │           │           │           │           │           │           │
   │             │           │           │           │           │           │           │
```

---

## 5. Matriz de Comunicación entre Servicios

| Origen | Destino | Tipo | Protocolo | Propósito |
|--------|---------|------|-----------|-----------|
| Gateway | user | Sync | HTTP/REST | Auth, perfil |
| Gateway | movie | Sync | HTTP/REST | Catálogo |
| Gateway | cinema | Sync | HTTP/REST | Cines y salas |
| Gateway | showtime | Sync | HTTP/REST | Horarios |
| Gateway | seat | Sync | HTTP/REST | Disponibilidad, holds |
| Gateway | booking | Sync | HTTP/REST | Crear reserva |
| booking | showtime | Sync | HTTP/REST | Validar horario |
| booking | seat | Sync | HTTP/REST | Validar hold, confirmar |
| booking | payment | Sync | HTTP/REST | Procesar pago |
| booking | notification | **Async** | RabbitMQ | Enviar confirmación |
| showtime | movie | Sync | HTTP/REST | Validar película |
| showtime | cinema | Sync | HTTP/REST | Validar sala |
| seat | showtime | Sync | HTTP/REST | Validar showtime_id |

---

## 6. Resumen Ejecutivo

### Estado Actual
- 4 microservicios funcionales pero **incompletos**
- **Falla crítica**: No hay validación de disponibilidad de asientos
- Sin autenticación ni gestión de usuarios
- Sin estructura de horarios ni cines

### Recomendación
Implementar **4 nuevos microservicios** en este orden:

1. **cinema-service** (base, sin dependencias)
2. **showtime-service** (depende de cinema + movie)
3. **seat-service** (depende de showtime + cinema) - **EL MÁS CRÍTICO**
4. **user-service** (independiente, puede ir en paralelo)

### Esfuerzo Estimado
- Phase 1 (cinema + user): 1-2 sprints
- Phase 2 (showtime): 1 sprint
- Phase 3 (seat): 2 sprints (complejidad de concurrencia)
- Phase 4 (refactor booking): 1 sprint
- Phase 5 (testing E2E): 1 sprint

**Total: 6-8 sprints para sistema completo**
