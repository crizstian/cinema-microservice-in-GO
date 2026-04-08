# Prompts Estructurados para Sesiones de Claude Code

## Sistema de Microservicios - Cinema Ticketing

Este documento contiene prompts diseñados para ejecutarse en **sesiones independientes de Claude Code**, siguiendo la metodología **Spec Driven Development (SDD)**.

---

## Resumen del Sistema Actual

### Microservicios Existentes (4)

| Servicio         | Funcionalidad                        | Endpoints                             | Base de Datos |
| ---------------- | ------------------------------------ | ------------------------------------- | ------------- |
| **movie**        | Catálogo de películas (solo lectura) | GET /movies/all, /premieres, /:id     | MongoDB       |
| **booking**      | Orquestación de reservas             | POST /booking/, GET /booking/:orderId | MongoDB       |
| **payment**      | Procesamiento de pagos (Stripe)      | POST /payment/makePurchase, GET /:id  | MongoDB       |
| **notification** | Envío de emails (SMS stub)           | POST /notification/sendEmail          | -             |

### Gaps Identificados

1. **Sin gestión de usuarios/autenticación** - No hay registro, login, ni perfiles
2. **Sin gestión de salas y horarios (showtimes)** - Los horarios se envían como strings sin validación
3. **Sin gestión de asientos** - No hay disponibilidad, bloqueo temporal, ni validación de doble reserva
4. **Sin especificaciones OpenAPI** - No hay contratos API definidos
5. **Sin servicio de cines/ubicaciones** - No hay catálogo de cines y salas
6. **Booking no valida disponibilidad** - Acepta cualquier asiento sin verificar

---

## Metodología: Spec Driven Development (SDD)

Cada prompt sigue este flujo:

```
1. Diseñar OpenAPI Spec primero
2. Validar spec con herramientas (spectral, openapi-generator)
3. Generar stubs/modelos desde spec
4. Implementar lógica de negocio
5. Escribir tests de contrato
6. Documentar integraciones
```

---

## FASE 1: Análisis y Diseño de Arquitectura

### Prompt 1.1: Análisis de Completitud del Sistema

```
Contexto: Tengo un sistema de microservicios para un cine con 4 servicios backend:
- movie: catálogo de películas (GET only)
- booking: orquestación de reservas
- payment: procesamiento de pagos con Stripe
- notification: envío de emails

Objetivo del sistema: Permitir a usuarios comprar tickets de cine, seleccionar horarios,
elegir asientos y pagar con tarjeta de crédito.

TAREA:
1. Lee el código de cada microservicio en /workspace/services/
2. Analiza los modelos de datos, endpoints y flujos de comunicación
3. Identifica qué funcionalidades FALTAN para completar el flujo de compra de tickets
4. Genera un diagrama de arquitectura actual vs arquitectura objetivo
5. Lista los microservicios adicionales necesarios con justificación

OUTPUT esperado:
- Tabla comparativa: funcionalidad actual vs requerida
- Lista priorizada de gaps
- Propuesta de nuevos microservicios (si aplica)
- Diagrama C4 o similar de la arquitectura objetivo
```

---

### Prompt 1.2: Diseño de Arquitectura Objetivo

```
Contexto: Sistema de cinema ticketing con gaps identificados en gestión de usuarios,
salas/horarios, y disponibilidad de asientos.

TAREA siguiendo Spec Driven Development:
1. Diseña la arquitectura de microservicios completa para soportar:
   - Registro y autenticación de usuarios
   - Catálogo de cines y salas
   - Gestión de horarios (showtimes) por película
   - Disponibilidad y reserva de asientos en tiempo real
   - Flujo completo de compra

2. Define las interacciones entre servicios (sync vs async)
3. Identifica qué servicios necesitan comunicación event-driven (colas)
4. Propón el stack tecnológico para cada nuevo servicio

OUTPUT esperado:
- Documento de arquitectura con diagramas
- Matriz de comunicación entre servicios
- Decisiones de diseño documentadas (ADRs)
- Lista de especificaciones OpenAPI a crear
```

---

## FASE 2: Especificaciones OpenAPI (Spec First)

### Prompt 2.1: OpenAPI para Movie Service (Existente)

```
TAREA: Crear especificación OpenAPI 3.0 para el servicio movie existente.

Siguiendo Spec Driven Development:
1. Lee el código en /workspace/services/movie/
2. Documenta los endpoints existentes en formato OpenAPI 3.0
3. Define schemas para todos los modelos (Movie, etc.)
4. Incluye ejemplos de request/response
5. Añade códigos de error y descripciones
6. Guarda el archivo en /workspace/services/movie/api/openapi.yaml

Validación requerida:
- Instala spectral si no existe: npm install -g @stoplight/spectral-cli
- Ejecuta: spectral lint openapi.yaml
- Corrige cualquier warning o error

OUTPUT: Archivo openapi.yaml validado sin errores
```

---

### Prompt 2.2: OpenAPI para Booking Service (Existente)

```
TAREA: Crear especificación OpenAPI 3.0 para el servicio booking existente.

Siguiendo Spec Driven Development:
1. Lee el código en /workspace/services/booking/
2. Documenta endpoints: POST /booking/, GET /booking/:orderId
3. Define schemas completos: BookingRequest, Ticket, Booking, Movie, UserMember, CreditCard
4. Documenta integraciones con payment-service y notification-service
5. Incluye ejemplos realistas de tickets de cine
6. Guarda en /workspace/services/booking/api/openapi.yaml

Validación:
- spectral lint openapi.yaml
- Verificar que los schemas coincidan con los modelos Go

OUTPUT: Archivo openapi.yaml validado
```

---

### Prompt 2.3: OpenAPI para Payment Service (Existente)

```
TAREA: Crear especificación OpenAPI 3.0 para el servicio payment.

Siguiendo Spec Driven Development:
1. Lee /workspace/services/payment/
2. Documenta: POST /payment/makePurchase, GET /payment/:id
3. Define schemas: Payment (request), PaymentResponse (con charge de Stripe)
4. Documenta campos sensibles (número de tarjeta) con formato adecuado
5. Incluir securitySchemes si aplica
6. Guarda en /workspace/services/payment/api/openapi.yaml

Consideraciones de seguridad:
- Marcar campos sensibles con x-sensitive: true
- Documentar que en producción debe usarse tokenización

OUTPUT: Archivo openapi.yaml validado
```

---

### Prompt 2.4: OpenAPI para Notification Service (Existente)

```
TAREA: Crear especificación OpenAPI 3.0 para notification service.

1. Lee /workspace/services/notification/
2. Documenta: POST /notification/sendEmail, POST /notification/sendSMS (stub)
3. Define schema Ticket reutilizable
4. Marcar sendSMS como deprecated o stub en la spec
5. Guarda en /workspace/services/notification/api/openapi.yaml

OUTPUT: Archivo openapi.yaml validado
```

---

## FASE 3: Nuevos Microservicios (Spec First)

### Prompt 3.1: Diseño y Spec de User Service (Nuevo)

```
TAREA: Diseñar e implementar user-service siguiendo Spec Driven Development.

PASO 1 - Spec First:
Crear /workspace/services/user/api/openapi.yaml con:
- POST /users/register - Registro de usuario
- POST /users/login - Autenticación (JWT)
- GET /users/me - Perfil del usuario autenticado
- PUT /users/me - Actualizar perfil
- POST /users/logout - Invalidar token

Schemas requeridos:
- UserRegistration (name, email, password, phone)
- UserLogin (email, password)
- UserProfile (id, name, email, phone, membership_type, created_at)
- AuthToken (access_token, refresh_token, expires_in)

Security:
- Bearer JWT authentication
- Password hashing (bcrypt)

PASO 2 - Validar spec:
spectral lint openapi.yaml

PASO 3 - Generar estructura Go:
Crear estructura de directorios siguiendo el patrón de /workspace/services/movie/:
- cmd/user/main.go
- internal/api/, models/, routes/, db/, server/
- go.mod con dependencias

PASO 4 - Implementar:
- Modelos Go que coincidan exactamente con OpenAPI schemas
- Handlers para cada endpoint
- Middleware JWT
- Tests unitarios

OUTPUT: Servicio user completo con spec OpenAPI y tests
```

---

### Prompt 3.2: Diseño y Spec de Showtime Service (Nuevo)

```
TAREA: Diseñar showtime-service para gestionar horarios de películas.

PASO 1 - Spec First:
Crear /workspace/services/showtime/api/openapi.yaml con:
- GET /showtimes?movie_id=&date=&cinema_id= - Listar horarios con filtros
- GET /showtimes/:id - Detalle de un horario
- POST /showtimes - Crear horario (admin)
- PUT /showtimes/:id - Actualizar horario (admin)
- DELETE /showtimes/:id - Cancelar horario (admin)

Schemas:
- Showtime:
  - id: string
  - movie_id: string (referencia a movie service)
  - cinema_id: string
  - room_number: int
  - start_time: datetime
  - end_time: datetime
  - price: object (regular, vip, child)
  - available_seats: int
  - status: enum (scheduled, cancelled, completed)

- ShowtimeList: array con paginación

Integraciones:
- Debe consultar movie-service para validar movie_id
- Debe exponer webhook/evento cuando se crea/cancela showtime

PASO 2 - Validar y generar código Go
PASO 3 - Implementar con tests

OUTPUT: Servicio showtime completo con spec y tests
```

---

### Prompt 3.3: Diseño y Spec de Seat Service (Nuevo)

```
TAREA: Diseñar seat-service para gestión de asientos y disponibilidad.

Este es el servicio MÁS CRÍTICO para evitar doble reserva de asientos.

PASO 1 - Spec First:
Crear /workspace/services/seat/api/openapi.yaml con:

Endpoints públicos:
- GET /seats/availability?showtime_id= - Mapa de asientos disponibles
- POST /seats/hold - Bloqueo temporal de asientos (5 min)
- DELETE /seats/hold/:hold_id - Liberar bloqueo
- POST /seats/reserve - Confirmar reserva (después de pago)

Endpoints admin:
- POST /seats/layout - Definir layout de sala (filas, columnas, tipos)
- GET /seats/layout/:room_id - Obtener layout de sala

Schemas:
- SeatMap:
  - showtime_id: string
  - room_layout: matrix de asientos
  - seats: array de Seat

- Seat:
  - id: string (ej: "A1", "B5")
  - row: string
  - number: int
  - type: enum (regular, vip, wheelchair, unavailable)
  - status: enum (available, held, reserved, occupied)
  - held_until: datetime (si está en hold)
  - held_by: string (session_id)

- HoldRequest:
  - showtime_id: string
  - seat_ids: array de strings
  - session_id: string (para identificar al usuario)

- HoldResponse:
  - hold_id: string
  - seats: array
  - expires_at: datetime

- ReserveRequest:
  - hold_id: string
  - booking_id: string (del booking-service)

Consideraciones de concurrencia:
- Usar transacciones MongoDB o Redis para evitar race conditions
- TTL en holds (auto-expire en 5 minutos)
- Documentar en spec el comportamiento de concurrencia

PASO 2 - Validar spec
PASO 3 - Implementar con Redis para holds y MongoDB para reservas confirmadas
PASO 4 - Tests de concurrencia

OUTPUT: Servicio seat con manejo de concurrencia y tests
```

---

### Prompt 3.4: Diseño y Spec de Cinema Service (Nuevo)

```
TAREA: Diseñar cinema-service para catálogo de cines y salas.

PASO 1 - Spec First:
Crear /workspace/services/cinema/api/openapi.yaml con:
- GET /cinemas - Listar cines (con filtro por ciudad)
- GET /cinemas/:id - Detalle de cine
- GET /cinemas/:id/rooms - Salas del cine
- POST /cinemas - Crear cine (admin)
- POST /cinemas/:id/rooms - Crear sala (admin)

Schemas:
- Cinema:
  - id, name, address, city, country
  - location: {lat, lng}
  - amenities: array (parking, food_court, 3d, imax)
  - rooms: array de Room references

- Room:
  - id, cinema_id, name, room_number
  - capacity: int
  - type: enum (standard, vip, imax, 4dx)
  - seat_layout: reference a seat-service

PASO 2 - Implementar servicio Go
OUTPUT: Servicio cinema con spec y tests
```

---

## FASE 4: Refactoring de Servicios Existentes

### Prompt 4.1: Refactorizar Booking Service

```
TAREA: Refactorizar booking-service para integrar con nuevos servicios.

Contexto: Booking actualmente NO valida disponibilidad de asientos ni horarios.
Necesita integrarse con seat-service y showtime-service.

Cambios requeridos:

1. ACTUALIZAR OpenAPI spec:
   - Modificar BookingRequest para incluir showtime_id en lugar de schedule string
   - Añadir integración con seat-service

2. NUEVO FLUJO de POST /booking/:
   a. Validar showtime_id con showtime-service
   b. Verificar que los asientos están en HOLD para este session_id (seat-service)
   c. Procesar pago (payment-service) - sin cambios
   d. Confirmar reserva de asientos (seat-service POST /seats/reserve)
   e. Crear ticket en DB
   f. Enviar notificación (notification-service) - sin cambios

3. MANEJO DE ERRORES:
   - Si pago falla → liberar hold de asientos
   - Si confirmación de asientos falla → hacer refund (nuevo endpoint en payment)

4. Implementar patrón SAGA para compensaciones

5. ACTUALIZAR TESTS para nuevo flujo

OUTPUT: Booking service refactorizado con nuevas integraciones
```

---

### Prompt 4.2: Añadir Refunds a Payment Service

```
TAREA: Extender payment-service con funcionalidad de reembolsos.

PASO 1 - Actualizar OpenAPI spec:
Añadir endpoint:
- POST /payment/:id/refund - Procesar reembolso

Schema RefundRequest:
- reason: string
- amount: int (opcional, para reembolso parcial)

Schema RefundResponse:
- refund_id: string
- status: enum (pending, succeeded, failed)
- amount_refunded: int

PASO 2 - Implementar usando Stripe Refunds API

PASO 3 - Tests

OUTPUT: Payment service con refunds
```

---

## FASE 5: Testing y Contratos

### Prompt 5.1: Contract Tests entre Servicios

```
TAREA: Implementar contract tests para validar integraciones.

Usar Pact o similar para Go:
1. Definir contratos booking → payment
2. Definir contratos booking → notification
3. Definir contratos booking → seat
4. Definir contratos booking → showtime

Para cada contrato:
- Consumer test (booking como consumer)
- Provider verification (cada servicio verifica que cumple el contrato)

Guardar contratos en /workspace/contracts/

OUTPUT: Suite de contract tests ejecutables
```

---

### Prompt 5.2: Integration Tests End-to-End

```
TAREA: Crear tests de integración para el flujo completo de compra.

Flujo a testear:
1. Usuario se registra (user-service)
2. Usuario busca películas en cartelera (movie-service)
3. Usuario selecciona horario (showtime-service)
4. Usuario ve mapa de asientos (seat-service)
5. Usuario hace hold de asientos (seat-service)
6. Usuario crea booking con pago (booking-service → payment)
7. Sistema confirma asientos (seat-service)
8. Sistema envía email (notification-service)

Usar docker-compose para levantar todos los servicios
Implementar en /workspace/tests/integration/

OUTPUT: Tests E2E ejecutables con docker-compose
```

---

### Prompt 5.3: Dockerfile Común y Taskfile para Microservicios

```
TAREA: Adaptar todos los microservicios para usar el Dockerfile común existente
en /workspace/platform/docker/go-service/Dockerfile y automatizar builds con Taskfile.

Contexto: Existe un Dockerfile común en platform/docker/go-service/ que todos los
microservicios deben utilizar. Se requiere eliminar los Dockerfiles individuales
y crear un Taskfile para automatizar la compilación con semantic versioning.

PASO 1 - Verificar Dockerfile común:
Verificar que existe /workspace/platform/docker/go-service/Dockerfile
Si no existe o requiere ajustes, debe tener:
- Multi-stage build (builder + runtime)
- Base image: golang:1.22-alpine para builder
- Runtime image: alpine:3.19 (mínimo footprint)
- ARGs parametrizables: SERVICE_NAME, SERVICE_PATH, PORT, VERSION
- Labels OCI estándar (org.opencontainers.image.*)
- Non-root user para seguridad
- Health check genérico

PASO 2 - Eliminar Dockerfiles individuales:
Eliminar TODOS los Dockerfiles de cada microservicio:
- /workspace/services/movie/Dockerfile
- /workspace/services/booking/Dockerfile
- /workspace/services/payment/Dockerfile
- /workspace/services/notification/Dockerfile
- /workspace/services/user/Dockerfile (si existe)
- /workspace/services/showtime/Dockerfile (si existe)
- /workspace/services/seat/Dockerfile (si existe)
- /workspace/services/cinema/Dockerfile (si existe)

PASO 3 - Instalar Taskfile:
Referencia: https://taskfile.dev
Verificar instalación disponible:
- brew install go-task (macOS)
- go install github.com/go-task/task/v3/cmd/task@latest (Go)
- sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d (Linux)

PASO 4 - Crear Taskfile.yml en /workspace/:
```yaml
version: '3'

vars:
  REGISTRY: '{{.REGISTRY | default "ghcr.io/cinema-app"}}'
  VERSION:
    sh: cat VERSION 2>/dev/null || echo "0.0.0-dev"
  COMMIT_SHA:
    sh: git rev-parse --short HEAD 2>/dev/null || echo "unknown"
  BUILD_DATE:
    sh: date -u +"%Y-%m-%dT%H:%M:%SZ"
  SERVICES: "movie booking payment notification user showtime seat cinema"

tasks:
  default:
    desc: "Mostrar tareas disponibles"
    cmds:
      - task --list

  # ========== VERSION MANAGEMENT (Semantic Versioning) ==========
  version:
    desc: "Mostrar versión actual"
    cmds:
      - echo "Current version: {{.VERSION}}"

  version:bump-patch:
    desc: "Incrementar PATCH (x.x.X) - bug fixes"
    cmds:
      - |
        current=$(cat VERSION 2>/dev/null || echo "0.0.0")
        IFS='.' read -r major minor patch <<< "$current"
        echo "$major.$minor.$((patch + 1))" > VERSION
        echo "Bumped to $(cat VERSION)"

  version:bump-minor:
    desc: "Incrementar MINOR (x.X.0) - new features"
    cmds:
      - |
        current=$(cat VERSION 2>/dev/null || echo "0.0.0")
        IFS='.' read -r major minor patch <<< "$current"
        echo "$major.$((minor + 1)).0" > VERSION
        echo "Bumped to $(cat VERSION)"

  version:bump-major:
    desc: "Incrementar MAJOR (X.0.0) - breaking changes"
    cmds:
      - |
        current=$(cat VERSION 2>/dev/null || echo "0.0.0")
        IFS='.' read -r major minor patch <<< "$current"
        echo "$((major + 1)).0.0" > VERSION
        echo "Bumped to $(cat VERSION)"

  version:set:
    desc: "Establecer versión manualmente (task version:set -- 1.2.3)"
    cmds:
      - echo "{{.CLI_ARGS}}" > VERSION
      - echo "Version set to {{.CLI_ARGS}}"

  # ========== BUILD COMMANDS ==========
  build:
    desc: "Build imagen de un servicio (task build SERVICE=movie)"
    vars:
      SERVICE: '{{.SERVICE | default "movie"}}'
      TAG: '{{.TAG | default .VERSION}}'
    cmds:
      - |
        echo "🔨 Building {{.SERVICE}}:{{.TAG}}..."
        docker build \
          --file platform/docker/go-service/Dockerfile \
          --build-arg SERVICE_NAME={{.SERVICE}} \
          --build-arg SERVICE_PATH=services/{{.SERVICE}} \
          --build-arg VERSION={{.TAG}} \
          --build-arg BUILD_DATE={{.BUILD_DATE}} \
          --build-arg COMMIT_SHA={{.COMMIT_SHA}} \
          --tag {{.REGISTRY}}/{{.SERVICE}}:{{.TAG}} \
          --tag {{.REGISTRY}}/{{.SERVICE}}:latest \
          .
        echo "✅ Built {{.REGISTRY}}/{{.SERVICE}}:{{.TAG}}"

  build:all:
    desc: "Build todas las imágenes"
    cmds:
      - for: { var: SERVICES, split: ' ' }
        task: build
        vars:
          SERVICE: '{{.ITEM}}'

  # ========== PUSH COMMANDS ==========
  push:
    desc: "Push imagen al registry (task push SERVICE=movie)"
    vars:
      SERVICE: '{{.SERVICE | default "movie"}}'
      TAG: '{{.TAG | default .VERSION}}'
    cmds:
      - docker push {{.REGISTRY}}/{{.SERVICE}}:{{.TAG}}
      - docker push {{.REGISTRY}}/{{.SERVICE}}:latest
      - echo "✅ Pushed {{.REGISTRY}}/{{.SERVICE}}:{{.TAG}}"

  push:all:
    desc: "Push todas las imágenes al registry"
    cmds:
      - for: { var: SERVICES, split: ' ' }
        task: push
        vars:
          SERVICE: '{{.ITEM}}'

  # ========== DOCKER COMPOSE UPDATE ==========
  compose:update:
    desc: "Actualizar imagen en docker-compose.yml (task compose:update SERVICE=movie)"
    vars:
      SERVICE: '{{.SERVICE}}'
    requires:
      vars: [SERVICE]
    cmds:
      - |
        echo "📝 Updating docker-compose.yml: {{.SERVICE}} → v{{.VERSION}}"
        yq -i '.services.{{.SERVICE}}.image = "{{.REGISTRY}}/{{.SERVICE}}:{{.VERSION}}"' docker-compose.yml
        echo "✅ Updated {{.SERVICE}} to v{{.VERSION}}"

  compose:update-all:
    desc: "Actualizar todas las imágenes en docker-compose.yml"
    cmds:
      - for: { var: SERVICES, split: ' ' }
        task: compose:update
        vars:
          SERVICE: '{{.ITEM}}'
      - echo "✅ All services updated to v{{.VERSION}}"

  # ========== RELEASE WORKFLOW ==========
  release:patch:
    desc: "Release PATCH: bump version, build all, update compose"
    cmds:
      - task: version:bump-patch
      - task: build:all
      - task: compose:update-all
      - echo "🚀 Release v$(cat VERSION) ready! Run 'task push:all' to publish"

  release:minor:
    desc: "Release MINOR: bump version, build all, update compose"
    cmds:
      - task: version:bump-minor
      - task: build:all
      - task: compose:update-all
      - echo "🚀 Release v$(cat VERSION) ready! Run 'task push:all' to publish"

  release:major:
    desc: "Release MAJOR: bump version, build all, update compose"
    cmds:
      - task: version:bump-major
      - task: build:all
      - task: compose:update-all
      - echo "🚀 Release v$(cat VERSION) ready! Run 'task push:all' to publish"

  # ========== UTILITIES ==========
  images:
    desc: "Listar imágenes construidas"
    cmds:
      - docker images --filter "reference={{.REGISTRY}}/*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

  clean:
    desc: "Limpiar imágenes locales del proyecto"
    cmds:
      - docker images --filter "reference={{.REGISTRY}}/*" -q | xargs -r docker rmi -f
      - docker builder prune -f
      - echo "✅ Cleaned up local images"
```

PASO 5 - Crear archivo VERSION:
Crear /workspace/VERSION con versión inicial:
```
0.1.0
```

PASO 6 - Actualizar docker-compose.yml:
Modificar /workspace/docker-compose.yml para usar el Dockerfile común:
```yaml
version: '3.8'

x-common-build: &common-build
  context: .
  dockerfile: platform/docker/go-service/Dockerfile

services:
  movie:
    build:
      <<: *common-build
      args:
        SERVICE_NAME: movie
        PORT: 8081
    image: ${REGISTRY:-ghcr.io/cinema-app}/movie:${VERSION:-latest}
    ports:
      - "8081:8081"

  booking:
    build:
      <<: *common-build
      args:
        SERVICE_NAME: booking
        PORT: 8082
    image: ${REGISTRY:-ghcr.io/cinema-app}/booking:${VERSION:-latest}
    ports:
      - "8082:8082"

  # ... repetir patrón para cada servicio
```

PASO 7 - Validar setup:
```bash
# Verificar instalación de task
task --version

# Ver comandos disponibles
task

# Build de un servicio
task build SERVICE=movie

# Build de todos
task build:all

# Release patch (bump + build + update compose)
task release:patch

# Ver imágenes construidas
task images
```

OUTPUT:
- Dockerfile común verificado en platform/docker/go-service/Dockerfile
- Dockerfiles individuales eliminados de todos los microservicios
- Taskfile.yml con semantic versioning (MAJOR.MINOR.PATCH)
- Archivo VERSION para control de versiones
- docker-compose.yml actualizado con build común
- Comandos: build, build:all, release:patch/minor/major, compose:update-all
```

---

### Prompt 5.4: Automatización de Testing con Taskfile y Docker Compose

```
TAREA: Configurar Taskfile y Docker Compose para automatizar la secuencia completa
de pruebas del proyecto, desde unit tests hasta E2E tests.

Contexto: El proyecto requiere una pipeline de testing automatizada que ejecute
todas las pruebas en orden, preparando la infraestructura necesaria con Docker Compose.

SECUENCIA DE TESTING:
1. Lint & Format (código y OpenAPI specs)
2. Unit Tests (por servicio, sin dependencias externas)
3. OpenAPI Validation (specs con Spectral)
4. Contract Tests (Pact o similar)
5. Integration Tests (servicios + DB)
6. E2E Tests (sistema completo)

# ============================================================
PASO 1 - Crear docker-compose.test.yml
# ============================================================

Crear /workspace/tests/docker-compose.test.yml:
```yaml
version: "3.8"

# Infraestructura de testing
services:
  # MongoDB para tests de integración y E2E
  mongo-test:
    image: mongo:8.0
    container_name: mongo-test
    ports:
      - "27018:27017"
    environment:
      MONGO_INITDB_DATABASE: cinema_test
    volumes:
      - ./fixtures/mongo-init:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
      interval: 5s
      timeout: 5s
      retries: 10
    tmpfs:
      - /data/db  # RAM para velocidad

  # Redis para holds y caché
  redis-test:
    image: redis:7-alpine
    container_name: redis-test
    ports:
      - "6380:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    tmpfs:
      - /data

  # Servicio para correr tests dentro de contenedor
  test-runner:
    build:
      context: ..
      dockerfile: platform/docker/go-service/Dockerfile
      target: builder
      args:
        SERVICE_NAME: movie  # cualquier servicio para tener Go
    working_dir: /workspace
    volumes:
      - ..:/workspace
      - go-cache:/go/pkg/mod
    environment:
      MONGO_URI: mongodb://mongo-test:27017
      REDIS_URI: redis://redis-test:6379
      TEST_ENV: "true"
    depends_on:
      mongo-test:
        condition: service_healthy
      redis-test:
        condition: service_healthy

volumes:
  go-cache:

networks:
  default:
    name: cinema-test-network
```

# ============================================================
PASO 2 - Extender Taskfile.yml con tareas de testing
# ============================================================

Agregar al Taskfile.yml existente las siguientes tareas:

```yaml
  # ============================================================
  # TESTING PIPELINE
  # ============================================================

  # --- LINT & FORMAT ---
  lint:all:
    desc: "Run all linters (Go + OpenAPI)"
    cmds:
      - task: lint:go
      - task: lint:openapi

  lint:go:
    desc: "Lint all Go services"
    vars:
      EXISTING_SERVICES: "movie booking payment notification"
    cmds:
      - |
        echo "Running Go linter..."
        for svc in {{.EXISTING_SERVICES}}; do
          echo "Linting $svc..."
          cd services/$svc && golangci-lint run ./... && cd ../..
        done

  lint:openapi:
    desc: "Validate all OpenAPI specs with Spectral"
    cmds:
      - |
        echo "Validating OpenAPI specs..."
        find services -name "openapi.yaml" -exec spectral lint {} \;

  fmt:all:
    desc: "Format all Go code"
    vars:
      EXISTING_SERVICES: "movie booking payment notification"
    cmds:
      - |
        for svc in {{.EXISTING_SERVICES}}; do
          echo "Formatting $svc..."
          cd services/$svc && go fmt ./... && cd ../..
        done

  # --- UNIT TESTS ---
  test:unit:
    desc: "Run unit tests for a service (task test:unit SERVICE=movie)"
    vars:
      SERVICE: '{{.SERVICE | default "movie"}}'
    dir: services/{{.SERVICE}}
    cmds:
      - |
        echo "Running unit tests for {{.SERVICE}}..."
        go test -v -race -short -cover -coverprofile=coverage-unit.out ./...

  test:unit:all:
    desc: "Run unit tests for all services"
    vars:
      EXISTING_SERVICES: "movie booking payment notification"
    cmds:
      - |
        echo "Running all unit tests..."
        for svc in {{.EXISTING_SERVICES}}; do
          echo "=== Unit tests: $svc ==="
          cd services/$svc && go test -v -race -short -cover ./... && cd ../..
        done

  # --- OPENAPI TESTS ---
  test:openapi:
    desc: "Run OpenAPI contract validation tests"
    cmds:
      - |
        echo "Validating OpenAPI specs..."
        spectral lint services/*/api/openapi.yaml --format junit > test-results/openapi-results.xml || true
        spectral lint services/*/api/openapi.yaml

  # --- CONTRACT TESTS ---
  test:contract:
    desc: "Run contract tests (Pact)"
    cmds:
      - |
        echo "Running contract tests..."
        cd tests/contract && go test -v -tags=contract ./...

  # --- INTEGRATION TESTS ---
  test:integration:
    desc: "Run integration tests (requires infra)"
    deps: [infra:up]
    cmds:
      - |
        echo "Running integration tests..."
        cd tests/integration && go test -v -tags=integration ./...

  test:integration:service:
    desc: "Run integration tests for a specific service"
    vars:
      SERVICE: '{{.SERVICE | default "movie"}}'
    deps: [infra:up]
    dir: services/{{.SERVICE}}
    cmds:
      - go test -v -race -tags=integration ./...

  # --- E2E TESTS ---
  test:e2e:
    desc: "Run E2E tests (full system)"
    deps: [infra:up, services:up]
    cmds:
      - |
        echo "Waiting for services to be ready..."
        sleep 5
        echo "Running E2E tests..."
        cd tests/e2e && go test -v -tags=e2e ./...

  # --- FULL PIPELINE ---
  test:all:
    desc: "Run complete test pipeline (lint -> unit -> contract -> integration -> e2e)"
    cmds:
      - task: test:pipeline

  test:pipeline:
    desc: "Execute full testing pipeline in sequence"
    cmds:
      - echo "=========================================="
      - echo "STEP 1/6 - Lint & Format"
      - echo "=========================================="
      - task: lint:all
      - echo ""
      - echo "=========================================="
      - echo "STEP 2/6 - Unit Tests"
      - echo "=========================================="
      - task: test:unit:all
      - echo ""
      - echo "=========================================="
      - echo "STEP 3/6 - OpenAPI Validation"
      - echo "=========================================="
      - task: test:openapi
      - echo ""
      - echo "=========================================="
      - echo "STEP 4/6 - Contract Tests"
      - echo "=========================================="
      - task: test:contract
      - echo ""
      - echo "=========================================="
      - echo "STEP 5/6 - Integration Tests"
      - echo "=========================================="
      - task: test:integration
      - echo ""
      - echo "=========================================="
      - echo "STEP 6/6 - E2E Tests"
      - echo "=========================================="
      - task: test:e2e
      - echo ""
      - echo "=========================================="
      - echo "ALL TESTS PASSED!"
      - echo "=========================================="

  test:ci:
    desc: "Run tests suitable for CI (with JUnit output)"
    cmds:
      - mkdir -p test-results
      - task: lint:all
      - |
        for svc in movie booking payment notification; do
          cd services/$svc
          go test -v -race -cover -coverprofile=coverage.out ./... 2>&1 | \
            go-junit-report > ../../test-results/${svc}-unit.xml
          cd ../..
        done
      - task: test:openapi
      - task: infra:up
      - |
        cd tests/integration
        go test -v -tags=integration ./... 2>&1 | \
          go-junit-report > ../../test-results/integration.xml
      - task: infra:down

  # ============================================================
  # INFRASTRUCTURE MANAGEMENT
  # ============================================================
  infra:up:
    desc: "Start test infrastructure (MongoDB, Redis)"
    cmds:
      - |
        echo "Starting test infrastructure..."
        docker compose -f tests/docker-compose.test.yml up -d mongo-test redis-test
        echo "Waiting for services to be healthy..."
        docker compose -f tests/docker-compose.test.yml exec -T mongo-test mongosh --eval "db.adminCommand('ping')" --quiet
        docker compose -f tests/docker-compose.test.yml exec -T redis-test redis-cli ping
        echo "Infrastructure ready!"

  infra:down:
    desc: "Stop test infrastructure"
    cmds:
      - docker compose -f tests/docker-compose.test.yml down -v

  infra:logs:
    desc: "Show infrastructure logs"
    cmds:
      - docker compose -f tests/docker-compose.test.yml logs -f

  infra:reset:
    desc: "Reset test infrastructure (stop + start)"
    cmds:
      - task: infra:down
      - task: infra:up

  # ============================================================
  # SERVICES FOR E2E
  # ============================================================
  services:up:
    desc: "Start all microservices for E2E testing"
    deps: [build:existing]
    cmds:
      - |
        echo "Starting microservices..."
        docker compose -f tests/docker-compose.test.yml up -d
        echo "Services started!"

  services:down:
    desc: "Stop all microservices"
    cmds:
      - docker compose -f tests/docker-compose.test.yml down

  # ============================================================
  # COVERAGE REPORTS
  # ============================================================
  coverage:
    desc: "Generate combined coverage report"
    cmds:
      - |
        echo "Generating coverage reports..."
        mkdir -p coverage
        for svc in movie booking payment notification; do
          cd services/$svc
          go test -coverprofile=../../coverage/${svc}.out ./...
          cd ../..
        done
        echo "mode: set" > coverage/combined.out
        tail -n +2 coverage/*.out >> coverage/combined.out
        go tool cover -html=coverage/combined.out -o coverage/coverage.html
        echo "Coverage report: coverage/coverage.html"

  coverage:view:
    desc: "Open coverage report in browser"
    cmds:
      - open coverage/coverage.html || xdg-open coverage/coverage.html
```

# ============================================================
PASO 3 - Crear estructura de directorios de tests
# ============================================================

```bash
mkdir -p tests/{fixtures/mongo-init,integration,e2e,contract,helpers}
mkdir -p test-results
mkdir -p coverage
```

Crear /workspace/tests/fixtures/mongo-init/01-init.js:
```javascript
// Initialize test databases
print("Initializing test databases...");

const databases = [
  { name: "cinema_movies", collections: ["movies"] },
  { name: "cinema_bookings", collections: ["bookings"] },
  { name: "cinema_payments", collections: ["payments"] },
  { name: "cinema_users", collections: ["users"] }
];

databases.forEach(function(dbConfig) {
  db = db.getSiblingDB(dbConfig.name);
  dbConfig.collections.forEach(function(coll) {
    db.createCollection(coll);
    print("Created " + dbConfig.name + "." + coll);
  });
});

print("Test databases initialized!");
```

# ============================================================
PASO 4 - Crear test helpers
# ============================================================

Crear /workspace/tests/helpers/testenv.go:
```go
package helpers

import (
    "context"
    "os"
    "time"
)

type TestEnv struct {
    MongoURI string
    RedisURI string
}

func NewTestEnv() *TestEnv {
    return &TestEnv{
        MongoURI: getEnv("MONGO_URI", "mongodb://localhost:27018"),
        RedisURI: getEnv("REDIS_URI", "redis://localhost:6380"),
    }
}

func getEnv(key, fallback string) string {
    if val := os.Getenv(key); val != "" {
        return val
    }
    return fallback
}

func WaitForReady(ctx context.Context, check func() error) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        default:
            if err := check(); err == nil {
                return nil
            }
            time.Sleep(500 * time.Millisecond)
        }
    }
}
```

# ============================================================
PASO 5 - Validar setup
# ============================================================

Ejecutar los siguientes comandos para validar:
```bash
# Ver todas las tareas de testing disponibles
task --list | grep test

# Ejecutar solo unit tests (rápido, sin infraestructura)
task test:unit:all

# Levantar infraestructura de test
task infra:up

# Ejecutar integration tests
task test:integration

# Ejecutar pipeline completo
task test:pipeline

# Limpiar infraestructura
task infra:down
```

OUTPUT:
- docker-compose.test.yml configurado en tests/
- Taskfile.yml extendido con tareas de testing completas
- Estructura de directorios tests/ creada
- Test helpers en Go
- Comandos disponibles:
  - task test:unit:all (unit tests sin dependencias)
  - task test:integration (con MongoDB/Redis)
  - task test:e2e (sistema completo)
  - task test:pipeline (secuencia completa)
  - task test:ci (para CI/CD con JUnit output)
  - task infra:up/down (gestión de infraestructura)
  - task coverage (reportes de cobertura)
```

---

## FASE 6: Consolidación, Documentación y DevOps

### Prompt 6.0: Consolidación de Configuración y Documentación del Sistema

```
TAREA: Consolidar configuración dispersa, eliminar duplicados y generar
documentación completa del sistema de testing.

PROBLEMAS A RESOLVER:
1. 8 archivos .spectral.yaml dispersos en el repositorio
2. 2 docker-compose para testing (docker-compose.test.yml y docker-compose.e2e.yml)
3. 2 Makefiles legacy (contracts/ y tests/integration/)
4. Scripts de seed/init dispersos sin nomenclatura consistente
5. Falta documentación completa del flujo de testing

# ============================================================
# ACCIONES
# ============================================================

PASO 1 - Consolidar .spectral.yaml:
- Fusionar todos los .spectral.yaml en único archivo /.spectral.yaml
- Eliminar archivos individuales en services/*/
- Actualizar task lint:openapi para usar --ruleset .spectral.yaml

PASO 2 - Unificar Docker Compose:
- Fusionar tests/docker-compose.test.yml y tests/integration/docker-compose.e2e.yml
- Crear único tests/docker-compose.yml con profiles:
  - profile: infra (MongoDB + Redis)
  - profile: services (microservicios)
  - profile: full (todo)
- Eliminar docker-compose duplicados

PASO 3 - Consolidar Seeds e Init Scripts:
- Crear estructura tests/data/mongo-init/ con scripts numerados:
  - 01-init-replica.js
  - 02-create-databases.js
  - 03-create-indexes.js
  - 04-seed-test-data.js
- Mover tests/fixtures/* y tests/integration/testdata/* a tests/data/
- Eliminar carpetas vacías

PASO 4 - Eliminar Makefiles:
- Revisar contracts/Makefile y tests/integration/Makefile
- Migrar comandos útiles a Taskfile.yml (contract:generate, contract:verify)
- Eliminar ambos Makefiles

PASO 5 - Actualizar Taskfile:
- Actualizar rutas en infra:up, infra:down, test:e2e
- Usar nuevo tests/docker-compose.yml con profiles
- Agregar tareas contract:* migradas de Makefiles

PASO 6 - Generar README de Testing:
Crear tests/README.md con secciones:
1. Visión General (objetivo, criterios de éxito, pirámide de testing)
2. Requisitos Previos (software, versiones, instalación)
3. Estructura de Directorios
4. Setup del Ambiente (instrucciones paso a paso)
5. Compilación de Imágenes (comandos, resultados esperados)
6. Preparación de Infraestructura (task infra:up, verificación)
7. Ejecución de Tests (unit, integration, e2e, pipeline completo)
8. Datos de Prueba (IDs, credenciales de test)
9. Troubleshooting (problemas comunes y soluciones)

PASO 7 - Validar:
- Ejecutar task lint:openapi con nuevo .spectral.yaml
- Ejecutar task infra:up/down con nuevo docker-compose
- Ejecutar task test:pipeline completo

# ============================================================
# OUTPUT ESPERADO
# ============================================================

Estructura final:
```
/.spectral.yaml                    # Único archivo Spectral
/tests/
├── docker-compose.yml             # Único compose con profiles
├── README.md                      # Documentación completa
├── data/
│   └── mongo-init/
│       ├── 01-init-replica.js
│       ├── 02-create-databases.js
│       ├── 03-create-indexes.js
│       └── 04-seed-test-data.js
├── integration/
├── e2e/
├── contract/
└── helpers/
```

Archivos eliminados:
- services/*/.spectral.yaml (8 archivos)
- tests/docker-compose.test.yml
- tests/integration/docker-compose.e2e.yml
- contracts/Makefile
- tests/integration/Makefile
- tests/fixtures/ (movido a tests/data/)

Comandos funcionando:
- task lint:openapi (usa .spectral.yaml raíz)
- task infra:up (usa profiles)
- task test:pipeline (flujo completo)
```

---

### Prompt 6.1: Documentación de API Gateway

```

TAREA: Diseñar configuración de API Gateway para exponer los servicios.

Opciones a evaluar:

- Kong
- Traefik
- NGINX

Requisitos:

1. Ruteo a cada microservicio
2. Rate limiting
3. JWT validation en gateway
4. CORS configuración
5. Health checks
6. Debe utilizar componentes open-source y compatibles tanto con docker-compose y posteriormente con kubernetes
7. Generar documentacion del sistema completo desarrollado

OUTPUT: Configuración de API Gateway y documentación

```

---

### Prompt 6.2: CI/CD Pipeline para Nuevos Servicios

```

TAREA: Crear pipeline de CI/CD para todos los microservicios.

Usar Harness CI (ya configurado en el proyecto).

Pipeline stages:

1. Lint OpenAPI specs (spectral)
2. Generate code from specs (validación)
3. Build Go services
4. Run unit tests
5. Run contract tests
6. Build Docker images
7. Push to registry
8. Deploy to staging
9. Run E2E tests
10. Deploy to production (manual approval)

OUTPUT: Pipeline YAML en /workspace/.harness/

```

---

## Orden de Ejecución Recomendado

```
SESIÓN 1:  Prompt 1.1 + 1.2 (Análisis completo)
SESIÓN 2:  Prompts 2.1-2.4 (OpenAPI specs existentes)
SESIÓN 3:  Prompt 3.4 (Cinema service - dependencia base)
SESIÓN 4:  Prompt 3.2 (Showtime service)
SESIÓN 5:  Prompt 3.3 (Seat service - el más complejo)
SESIÓN 6:  Prompt 3.1 (User service)
SESIÓN 7:  Prompts 4.1 + 4.2 (Refactoring)
SESIÓN 8:  Prompt 5.1 (Contract tests)
SESIÓN 9:  Prompt 5.2 (E2E tests)
SESIÓN 10: Prompt 5.3 (Dockerfile común - unificar builds)
SESIÓN 11: Prompt 5.4 (Automatización testing con Taskfile)
SESIÓN 12: Prompt 6.0 (Consolidación y documentación) ← IMPORTANTE
SESIÓN 13: Prompts 6.1 + 6.2 (API Gateway y CI/CD)
```

---

## Notas para Claude Code

- Cada prompt está diseñado para una sesión independiente (~30-60 min)
- Seguir estrictamente el orden Spec → Validate → Implement → Test
- Guardar specs OpenAPI en `/services/{name}/api/openapi.yaml`
- Usar el patrón de estructura existente en `/services/movie/` como referencia
- Ejecutar tests antes de marcar cualquier tarea como completada
```
