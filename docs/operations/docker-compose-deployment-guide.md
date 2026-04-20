# Docker Compose Deployment Guide

Guia completa para desplegar Cinema Microservices en el entorno local con Docker Compose.
Disenada para todos los niveles: desde principiantes hasta expertos.

---

## Tabla de Contenidos

1. [Arquitectura del Sistema](#arquitectura-del-sistema)
2. [Prerequisitos](#prerequisitos)
3. [Fase 1: Configuracion Centralizada](#fase-1-configuracion-centralizada)
4. [Fase 2: Iniciar el Entorno](#fase-2-iniciar-el-entorno)
5. [Fase 3: Validacion de Servicios](#fase-3-validacion-de-servicios)
6. [Fase 4: Testing de APIs](#fase-4-testing-de-apis)
7. [Fase 5: Troubleshooting](#fase-5-troubleshooting)
8. [Fase 6: Cleanup](#fase-6-cleanup)
9. [Quick Reference](#quick-reference)

---

## Arquitectura del Sistema

### Microservicios de la Aplicacion

**Objetivo:** Entender que hace cada microservicio y como se relacionan entre si.

**Por que es importante:** Cada servicio tiene una responsabilidad especifica. Conocerlos te ayuda a debuggear problemas y entender el flujo de datos.

| Servicio | Puerto | Responsabilidad | Dependencias |
|----------|--------|-----------------|--------------|
| **booking** | 8001 | Orquestador SAGA - coordina el flujo completo de reserva | payment, seat, showtime, notification |
| **movie** | 8002 | Catalogo de peliculas - CRUD de peliculas disponibles | MongoDB |
| **cinema** | 8003 | Gestion de cines y salas - ubicaciones y capacidades | MongoDB |
| **user** | 8004 | Autenticacion y usuarios - registro, login, perfiles | MongoDB, Redis |
| **seat** | 8005 | Mapa de asientos - disponibilidad y holds temporales | MongoDB, Redis |
| **showtime** | 8006 | Funciones - horarios, precios, disponibilidad | MongoDB, movie |
| **payment** | 8007 | Procesamiento de pagos - integracion con Stripe (mock) | MongoDB |
| **notification** | 8008 | Notificaciones - emails de confirmacion (mock) | NATS |

**Diagrama de dependencias:**

```
                           ┌─────────────────────────────────────────┐
                           │           BOOKING SERVICE               │
                           │        (SAGA Orchestrator)              │
                           │    Coordina transacciones distribuidas  │
                           │              Puerto: 8001               │
                           └─────────────────┬───────────────────────┘
                                             │
            ┌────────────────┬───────────────┼───────────────┬────────────────┐
            │                │               │               │                │
            ▼                ▼               ▼               ▼                ▼
    ┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
    │    PAYMENT    │ │     SEAT      │ │   SHOWTIME    │ │ NOTIFICATION  │
    │ Procesa pagos │ │ Reserva seats │ │   Valida      │ │ Envia emails  │
    │    :8007      │ │    :8005      │ │  horarios     │ │    :8008      │
    └───────────────┘ └───────┬───────┘ │    :8006      │ └───────────────┘
                              │         └───────┬───────┘
                              │                 │
                              ▼                 ▼
                       ┌─────────────────────────────┐
                       │      MOVIE      │   CINEMA  │
                       │   Catalogo de   │  Cines y  │
                       │   peliculas     │   salas   │
                       │     :8002       │   :8003   │
                       └─────────────────────────────┘
                                    │
    ┌───────────────────────────────┼───────────────────────────────┐
    │                               │                               │
    ▼                               ▼                               ▼
┌─────────┐                   ┌─────────┐                     ┌─────────┐
│  USER   │                   │ MongoDB │                     │  Redis  │
│ :8004   │                   │         │                     │         │
└─────────┘                   └─────────┘                     └─────────┘
```

---

### Servicios de Infraestructura

**Objetivo:** Entender que infraestructura se requiere y por que cada componente es necesario.

**Por que es importante:** Sin la infraestructura correcta, los microservicios no pueden funcionar. Cada componente tiene un proposito especifico.

#### MongoDB (Base de datos)

| Aspecto | Descripcion |
|---------|-------------|
| **Que es** | Base de datos NoSQL orientada a documentos |
| **Por que se usa** | Flexibilidad de schema, buen rendimiento para lecturas, soporte nativo para replica sets |
| **Configuracion dev** | 3 nodos en replica set (mongo1, mongo2, mongo3) |
| **Configuracion test** | 1 nodo standalone con tmpfs |
| **Puertos** | 27017 (mongo1), 27018 (mongo2), 27019 (mongo3) |

**Por que replica set en dev:**
- Simula produccion (alta disponibilidad)
- Permite probar transacciones multi-documento
- El servicio `booking` usa transacciones ACID

```bash
# Verificar estado del replica set
docker exec dev-mongo1 mongosh --eval "rs.status().members.map(m => m.name + ' -> ' + m.stateStr)"
```

**Respuesta esperada:**
```
[ 'mongo1:27017 -> PRIMARY', 'mongo2:27017 -> SECONDARY', 'mongo3:27017 -> SECONDARY' ]
```

#### Redis (Cache y Locks)

| Aspecto | Descripcion |
|---------|-------------|
| **Que es** | Almacen de datos en memoria, key-value |
| **Por que se usa** | Cache de sesiones, locks distribuidos para seat holds |
| **Quien lo usa** | `user` (sesiones JWT), `seat` (holds temporales) |
| **Puerto** | 6379 |

**Caso de uso critico - Seat Holds:**

Cuando un usuario selecciona asientos, estos se "reservan temporalmente" por 5 minutos:

```
Usuario A selecciona A1, A2
    │
    ▼
seat-service crea lock en Redis:
  KEY: "hold:sht_001:A1" = "user_123"
  KEY: "hold:sht_001:A2" = "user_123"
  TTL: 300 segundos (5 min)
    │
    ▼
Usuario B intenta seleccionar A1
    │
    ▼
seat-service verifica Redis
  KEY existe → Asiento NO disponible
    │
    ▼
Respuesta: 409 Conflict
```

```bash
# Verificar Redis
docker exec dev-redis redis-cli ping
# Respuesta: PONG

# Ver keys activos (despues de un hold)
docker exec dev-redis redis-cli keys "hold:*"
```

#### NATS (Mensajeria)

| Aspecto | Descripcion |
|---------|-------------|
| **Que es** | Sistema de mensajeria pub/sub de alto rendimiento |
| **Por que se usa** | Comunicacion asincrona entre servicios |
| **Quien lo usa** | `booking` (publica eventos), `notification` (consume eventos) |
| **Puertos** | 4222 (cliente), 8222 (monitoring HTTP) |

**Flujo de notificacion:**

```
booking-service confirma reserva
    │
    ▼
Publica evento en NATS:
  Subject: "booking.confirmed"
  Data: {order_id, user_email, seats, showtime}
    │
    ▼
notification-service suscrito a "booking.*"
    │
    ▼
Recibe evento → Envia email de confirmacion
```

```bash
# Verificar NATS
curl -s http://localhost:8222/varz | jq '{server_id, version, connections}'
```

**Respuesta esperada:**
```json
{
  "server_id": "NXXXXXXXXXXXXXXXXXXXXXXXXX",
  "version": "2.10.x",
  "connections": 8
}
```

#### mongo-init (Contenedor de inicializacion)

| Aspecto | Descripcion |
|---------|-------------|
| **Que es** | Contenedor one-shot que configura MongoDB |
| **Que hace** | 1) Inicia replica set, 2) Crea bases de datos, 3) Carga datos de prueba |
| **Cuando corre** | Una vez al iniciar, luego termina (Exit 0) |
| **Ubicacion scripts** | `platform/docker/mongodb/seed/*.js` |

**Scripts de inicializacion (orden de ejecucion):**

| Script | Proposito |
|--------|-----------|
| `01-init-replica.js` | Configura el replica set rs0 |
| `02-create-databases.js` | Crea colecciones con schemas |
| `03-create-indexes.js` | Crea indices para rendimiento |
| `04-seed-test-data.js` | Inserta datos de prueba |

**Datos de prueba cargados:**

| Base de datos | Coleccion | Registros | Descripcion |
|---------------|-----------|-----------|-------------|
| `cinema` | movies | 2 | The Shawshank Redemption, Inception |
| `cinema` | cinemas | 1 | Cinema Downtown |
| `cinema` | rooms | 2 | Room 1 (100 seats), VIP Room (50 seats) |
| `cinema` | showtimes | 2 | Funciones para manana |
| `cinema` | users | 1 | test@example.com |
| `cinema_seats` | room_layouts | 1 | Layout de 100 asientos (10x10) |
| `cinema_seats` | showtimes | 2 | Mapeo showtime → room |

```bash
# Ver logs del init (deberia mostrar Exit 0)
docker logs dev-mongo-init

# Verificar datos cargados
docker exec dev-mongo1 mongosh --eval "
  db = db.getSiblingDB('cinema');
  print('Movies: ' + db.movies.countDocuments());
  print('Showtimes: ' + db.showtimes.countDocuments());
  db.movies.find({}, {title: 1, _id: 0}).forEach(m => print('  - ' + m.title));
"
```

**Respuesta esperada:**
```
Movies: 2
Showtimes: 2
  - The Shawshank Redemption
  - Inception
```

---

### Resumen de Contenedores

**Objetivo:** Tener una vista completa de todos los contenedores que se inician.

| Contenedor | Tipo | Puerto | Persistencia | Estado esperado |
|------------|------|--------|--------------|-----------------|
| dev-mongo1 | Infra | 27017 | Volume | healthy |
| dev-mongo2 | Infra | 27018 | Volume | healthy |
| dev-mongo3 | Infra | 27019 | Volume | healthy |
| dev-mongo-init | Infra | - | - | Exited (0) |
| dev-redis | Infra | 6379 | Volume | healthy |
| cinema-nats | Infra | 4222, 8222 | - | healthy |
| cinema-movie | App | 8002 | - | healthy |
| cinema-cinema | App | 8003 | - | healthy |
| cinema-user | App | 8004 | - | healthy |
| cinema-seat | App | 8005 | - | healthy |
| cinema-showtime | App | 8006 | - | healthy |
| cinema-payment | App | 8007 | - | healthy |
| cinema-notification | App | 8008 | - | healthy |
| cinema-booking | App | 8001 | - | healthy |

**Total:** 14 contenedores (6 infra + 8 app)

---

## Prerequisitos

### Herramientas requeridas

#### 1. Verificar Docker

**Objetivo:** Confirmar que tienes Docker instalado y funcionando.

**Por que es importante:** Docker es el runtime que ejecuta los contenedores. Sin Docker, nada funciona.

```bash
docker --version
```

**Respuesta esperada:**
```
Docker version 24.0.0, build XXXXXXX
```

**Si falla:** Instala Docker siguiendo la [guia oficial](https://docs.docker.com/get-docker/).

```bash
# Verificar que Docker daemon esta corriendo
docker info
```

**Respuesta esperada:**
```
Client: Docker Engine - Community
 Version:           24.0.0
Server: Docker Engine - Community
 Engine:
  Version:          24.0.0
...
```

**Si falla con "Cannot connect to Docker daemon":**
- Linux: `sudo systemctl start docker`
- macOS/Windows: Inicia Docker Desktop
- DevContainer: Docker se conecta al host automaticamente

---

#### 2. Verificar Docker Compose

**Objetivo:** Confirmar que Docker Compose v2 esta instalado.

**Por que es importante:** Docker Compose orquesta multiples contenedores como una unidad. Usamos Compose v2 (integrado en `docker compose`).

```bash
docker compose version
```

**Respuesta esperada:**
```
Docker Compose version v2.24.0
```

**Si falla o muestra v1:** Actualiza Docker Desktop o instala el plugin Compose v2.

---

#### 3. Verificar Task

**Objetivo:** Confirmar que el task runner esta instalado.

**Por que es importante:** `task` automatiza comandos complejos. Evita errores y asegura consistencia.

```bash
task --version
```

**Respuesta esperada:**
```
Task version: 3.x.x
```

**Si falla:**
```bash
# macOS
brew install go-task

# Linux
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# DevContainer: ya incluido
```

---

#### 4. Verificar yq (opcional, para config:generate)

**Objetivo:** Confirmar que yq esta instalado para generar configuracion.

**Por que es importante:** `yq` procesa YAML. Los scripts de generacion de config lo usan.

```bash
yq --version
```

**Respuesta esperada:**
```
yq (https://github.com/mikefarah/yq/) version v4.x.x
```

**Si falla:**
```bash
# macOS
brew install yq

# Linux
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
chmod +x /usr/local/bin/yq
```

---

### Requisitos de sistema

**Objetivo:** Asegurar que tu maquina tiene suficientes recursos.

**Por que es importante:** Docker Compose inicia 12+ contenedores. Sin recursos suficientes, los servicios fallan o son muy lentos.

| Recurso | Minimo | Recomendado |
|---------|--------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4GB | 8GB+ |
| Disco | 10GB | 20GB+ |

```bash
# Verificar recursos disponibles para Docker
docker info | grep -E "(CPUs|Memory)"
```

**Respuesta esperada:**
```
 CPUs: 4
 Total Memory: 7.775GiB
```

**Si tienes menos recursos:**
- Cierra otras aplicaciones
- Aumenta recursos en Docker Desktop settings
- Usa el profile `test` (single MongoDB, tmpfs)

---

## Fase 1: Configuracion Centralizada

### 1.1 Entender el sistema de configuracion

**Objetivo:** Comprender como la configuracion fluye desde el archivo central hasta Docker Compose.

**Por que es importante:** Toda la configuracion vive en un solo lugar (`platform/config/services.yaml`). Esto elimina inconsistencias entre local y remoto.

```
platform/config/services.yaml  <-- SINGLE SOURCE OF TRUTH
         |
         +--> task config:generate
         |
         v
platform/deploy/docker-compose/.env  <-- Variables para Docker Compose
```

---

### 1.2 Verificar configuracion central

**Objetivo:** Revisar que `platform/config/services.yaml` tiene la configuracion correcta.

**Por que es importante:** Este archivo define puertos, bases de datos e imagenes para TODOS los entornos.

```bash
cat platform/config/services.yaml
```

**Respuesta esperada:**
```yaml
services:
  booking:
    port: 8001
    dbName: booking
    image: crizstian/booking-service
    resources:
      cpu_request: 100m
      mem_request: 128Mi
      cpu_limit: 500m
      mem_limit: 512Mi
    dependencies:
      - seat-service
      - payment-service
      - showtime-service
      - notification-service

  movie:
    port: 8002
    dbName: movie
    image: crizstian/movie-service
    ...
```

**Que verificar:**
- Cada servicio tiene `port`, `dbName`, `image`
- Los puertos son unicos (8001-8008)
- Los nombres de imagen corresponden al Docker registry

---

### 1.3 Generar archivo .env

**Objetivo:** Generar las variables de entorno para Docker Compose.

**Por que es importante:** Docker Compose lee variables desde `.env`. Este paso transforma `services.yaml` en formato que Compose entiende.

```bash
task config:generate
```

**Respuesta esperada:**
```
=== Generating Docker Compose .env from services.yaml ===
Reading platform/config/services.yaml...
Generating platform/deploy/docker-compose/.env...
Generated environment variables:
  BOOKING_PORT=8001
  BOOKING_DB=booking
  BOOKING_IMAGE=crizstian/booking-service
  MOVIE_PORT=8002
  MOVIE_DB=movie
  MOVIE_IMAGE=crizstian/movie-service
  ...
=== Done ===
```

**Verificar contenido generado:**
```bash
cat platform/deploy/docker-compose/.env
```

**Respuesta esperada:**
```bash
# Generated from platform/config/services.yaml
# Do not edit manually - run 'task config:generate' to regenerate

# Service Ports
BOOKING_PORT=8001
MOVIE_PORT=8002
CINEMA_PORT=8003
USER_PORT=8004
SEAT_PORT=8005
SHOWTIME_PORT=8006
PAYMENT_PORT=8007
NOTIFICATION_PORT=8008

# Database Names
BOOKING_DB=booking
MOVIE_DB=movie
CINEMA_DB=cinema
USER_DB=user
SEAT_DB=seat
SHOWTIME_DB=showtime
PAYMENT_DB=payment
NOTIFICATION_DB=notification

# Images
BOOKING_IMAGE=crizstian/booking-service
MOVIE_IMAGE=crizstian/movie-service
...
```

**Si falla:**
- Verifica que `yq` esta instalado
- Verifica que `platform/config/services.yaml` existe y tiene formato valido

---

### 1.4 Ver configuracion actual

**Objetivo:** Verificar rapidamente los puertos configurados.

**Por que es importante:** Util para debugging y para saber a que puerto conectarte.

```bash
task config:show
```

**Respuesta esperada:**
```
=== Service Configuration ===
booking: port=8001
movie: port=8002
cinema: port=8003
user: port=8004
seat: port=8005
showtime: port=8006
payment: port=8007
notification: port=8008
```

---

## Fase 2: Iniciar el Entorno

### 2.1 Entender los perfiles

**Objetivo:** Conocer los diferentes modos de ejecucion disponibles.

**Por que es importante:** Cada perfil optimiza para un caso de uso diferente.

| Perfil | MongoDB | Storage | Caso de uso |
|--------|---------|---------|-------------|
| `dev` | 3 replicas | Volumes persistentes | Desarrollo diario |
| `test` | 1 nodo | tmpfs (RAM) | Tests rapidos |
| `debug` | 3 replicas | Volumes | Debugging con puertos extra |
| `perf` | 3 replicas | Volumes | Load testing |
| `e2e` | - | - | Solo runner de tests E2E |

**Arquitectura del perfil `dev`:**
```
                    ┌─────────────────────────────────────────────┐
                    │              Docker Network                  │
                    │            (cinema-dev-network)              │
                    └─────────────────────────────────────────────┘
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │                               │                               │
        ▼                               ▼                               ▼
┌───────────────┐              ┌───────────────┐              ┌───────────────┐
│    MongoDB    │              │     Redis     │              │     NATS      │
│  (3 replicas) │              │    (cache)    │              │  (messaging)  │
│ mongo1:27017  │              │   redis:6379  │              │   nats:4222   │
│ mongo2:27018  │              └───────────────┘              └───────────────┘
│ mongo3:27019  │
└───────────────┘
        │
        └──────────────────────────────────────────────────────────────┐
                                                                       │
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │
│  movie   │  │  cinema  │  │   user   │  │ showtime │  │   seat   │◄─┘
│  :8002   │  │  :8003   │  │  :8004   │  │  :8006   │  │  :8005   │
└──────────┘  └──────────┘  └──────────┘  └──────────┘  └──────────┘
                                                              │
        ┌─────────────────────────────────────────────────────┤
        │                                                     │
        ▼                                                     ▼
┌───────────────┐  ┌───────────────┐              ┌───────────────────┐
│    payment    │  │ notification  │              │      booking      │
│    :8007      │  │    :8008      │              │ (SAGA orchestrator)│
└───────────────┘  └───────────────┘              │      :8001        │
                                                  └───────────────────┘
```

---

### 2.2 Iniciar con task (recomendado)

**Objetivo:** Iniciar el entorno de desarrollo completo con un solo comando.

**Por que es importante:** `task dev:up` maneja todas las complejidades: variables de entorno, orden de inicio, espera de healthchecks.

```bash
task dev:up
```

**Respuesta esperada:**
```
[+] Building 45.2s (120/120) FINISHED
 => [movie internal] load build definition from Dockerfile
 => [cinema internal] load build definition from Dockerfile
 ...
[+] Running 14/14
 ✔ Network cinema-dev-network  Created
 ✔ Volume "mongo1_data"        Created
 ✔ Volume "mongo2_data"        Created
 ✔ Volume "mongo3_data"        Created
 ✔ Volume "redis_data"         Created
 ✔ Container dev-mongo1        Healthy
 ✔ Container dev-mongo2        Healthy
 ✔ Container dev-mongo3        Healthy
 ✔ Container dev-mongo-init    Exited
 ✔ Container cinema-nats       Healthy
 ✔ Container dev-redis         Healthy
 ✔ Container cinema-movie      Healthy
 ✔ Container cinema-booking    Healthy
 ...
Waiting for services...
NAME                   STATUS
dev-mongo1             healthy
dev-mongo2             healthy
dev-mongo3             healthy
cinema-movie           healthy
cinema-booking         healthy
...
```

**Tiempo esperado:** 2-5 minutos (primera vez, incluye build de imagenes)

**Si tarda mas de 10 minutos:**
- Verifica conexion a internet (descarga de imagenes base)
- Verifica espacio en disco: `docker system df`
- Considera usar imagenes pre-built con `VERSION=latest`

---

### 2.3 Que hace `task dev:up` (desmitificando la magia)

**Objetivo:** Entender exactamente que sucede cuando ejecutas `task dev:up` para poder debuggear problemas.

**Por que es importante:** Cuando algo falla, necesitas saber que archivos, variables y comandos estan involucrados. No es magia - es una secuencia de operaciones bien definida.

#### Archivos involucrados

```
/workspace/
├── Taskfile.yml                              # Define el task dev:up
│   └── calls: platform/scripts/taskfile/dev-up.sh
│
├── platform/scripts/taskfile/dev-up.sh       # Script que ejecuta el comando
│   └── calls: docker compose ... --profile dev up
│
├── platform/deploy/docker-compose/
│   ├── docker-compose.yml                    # Definicion de todos los servicios
│   └── .env                                  # Variables (generado por config:generate)
│
├── platform/config/services.yaml             # Source of truth para puertos/config
│
└── platform/docker/
    ├── go-service/Dockerfile                 # Dockerfile para microservicios Go
    └── mongodb/
        ├── Dockerfile                        # Init container de MongoDB
        └── seed/*.js                         # Scripts de inicializacion
```

#### Contenido del script dev-up.sh

```bash
#!/bin/bash
set -euo pipefail

COMPOSE_FILE="platform/deploy/docker-compose/docker-compose.yml"

# Variables de entorno que se exportan
export ENV_PREFIX=dev
export MONGO_SERVERS="mongo1:27017,mongo2:27017,mongo3:27017"

# Comando que se ejecuta
docker compose -f "$COMPOSE_FILE" --profile dev up -d --build

# Espera y muestra estado
echo "Waiting for services..."
sleep 10
docker compose -f "$COMPOSE_FILE" --profile dev ps
```

#### Variables de entorno en juego

| Variable | Valor | Definida en | Usada por |
|----------|-------|-------------|-----------|
| `ENV_PREFIX` | `dev` | dev-up.sh | docker-compose.yml (nombres de contenedores) |
| `MONGO_SERVERS` | `mongo1:27017,...` | dev-up.sh | Servicios Go (conexion a MongoDB) |
| `MOVIE_PORT` | `8002` | .env (generado) | docker-compose.yml |
| `MOVIE_DB` | `movie` | .env (generado) | docker-compose.yml |
| `MOVIE_IMAGE` | `crizstian/movie-service` | .env (generado) | docker-compose.yml |
| `VERSION` | `dev` (default) | No definida | docker-compose.yml (tag de imagen) |

**Como docker-compose.yml usa las variables:**

```yaml
# Ejemplo: servicio movie en docker-compose.yml
movie:
  image: ${MOVIE_IMAGE:-crizstian/movie-service}:${VERSION:-dev}
  container_name: ${ENV_PREFIX:-cinema}-movie
  ports:
    - "${MOVIE_PORT:-8002}:${MOVIE_PORT:-8002}"
  environment:
    DB_SERVERS: "${MONGO_SERVERS:-mongo:27017}"
    DB_NAME: "${MOVIE_DB:-movie}"
    SERVICE_PORT: "${MOVIE_PORT:-8002}"
```

#### Orden de operaciones

```
task dev:up
    │
    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  1. Taskfile.yml busca el task "dev:up"                             │
│     - Ubicacion: /workspace/Taskfile.yml                            │
│     - Linea: dev:up → calls platform/scripts/taskfile/dev-up.sh     │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. Script dev-up.sh se ejecuta                                     │
│     - Exporta ENV_PREFIX=dev                                        │
│     - Exporta MONGO_SERVERS=mongo1:27017,mongo2:27017,mongo3:27017  │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. Docker Compose lee configuracion                                │
│     - Lee docker-compose.yml                                        │
│     - Lee .env automaticamente (mismo directorio)                   │
│     - Combina variables de entorno exportadas + .env                │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. Docker Compose filtra por profile "dev"                         │
│     - Solo inicia servicios con "profiles: [dev, ...]"              │
│     - Excluye servicios con otros profiles (ej: test, e2e)          │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  5. Docker construye imagenes (--build)                             │
│     - Para cada servicio, lee el Dockerfile especificado            │
│     - Construye imagen con tag ${VERSION:-dev}                      │
│     - Cache de layers acelera rebuilds                              │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  6. Docker crea recursos                                            │
│     - Network: cinema-dev-network                                   │
│     - Volumes: mongo1_data, mongo2_data, mongo3_data, redis_data    │
└───────────────────────────────────┬─────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│  7. Docker inicia contenedores (respetando depends_on)              │
│                                                                     │
│     Orden de inicio:                                                │
│     ┌─────────────────────────────────────────────────────────────┐ │
│     │  Primero: mongo1, mongo2, mongo3 (en paralelo)              │ │
│     │  Esperan: healthcheck (mongosh ping)                        │ │
│     └───────────────────────────┬─────────────────────────────────┘ │
│                                 │                                   │
│     ┌───────────────────────────▼─────────────────────────────────┐ │
│     │  Segundo: mongo-init (depends_on: mongo1,2,3 healthy)       │ │
│     │  Ejecuta: /init.sh (rs.initiate + seed scripts)             │ │
│     │  Termina: Exit 0                                            │ │
│     └───────────────────────────┬─────────────────────────────────┘ │
│                                 │                                   │
│     ┌───────────────────────────▼─────────────────────────────────┐ │
│     │  Tercero: redis, nats (en paralelo, sin dependencias)       │ │
│     │  Esperan: healthcheck propio                                │ │
│     └───────────────────────────┬─────────────────────────────────┘ │
│                                 │                                   │
│     ┌───────────────────────────▼─────────────────────────────────┐ │
│     │  Cuarto: Todos los microservicios Go (en paralelo)          │ │
│     │  Esperan: healthcheck /health/live                          │ │
│     └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

#### Troubleshooting de `task dev:up`

**Problema: "task: command not found"**

```bash
# Verificar instalacion
which task

# Si no existe, instalar
brew install go-task  # macOS
# o
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin  # Linux
```

**Problema: "No such file: platform/scripts/taskfile/dev-up.sh"**

```bash
# Verificar que existe el script
ls -la platform/scripts/taskfile/dev-up.sh

# Si no existe, verificar la rama
git status
```

**Problema: ".env file not found" o variables vacias**

```bash
# Verificar que .env existe
ls -la platform/deploy/docker-compose/.env

# Si no existe, generarlo
task config:generate

# Verificar contenido
cat platform/deploy/docker-compose/.env | head -20
```

**Problema: "port is already allocated"**

```bash
# Ver que usa el puerto
lsof -i :8002

# Detener compose anterior
docker compose -f platform/deploy/docker-compose/docker-compose.yml down

# O matar el proceso
kill -9 <PID>
```

**Problema: "network not found" o "volume not found"**

```bash
# Limpiar recursos huerfanos
docker network prune -f
docker volume prune -f

# Reintentar
task dev:up
```

**Problema: Servicios nunca llegan a "healthy"**

```bash
# Ver logs del servicio que falla
docker logs cinema-booking --tail 100

# Ver eventos de Docker
docker events --filter container=cinema-booking &

# Ver healthcheck especifico
docker inspect cinema-booking | jq '.[0].State.Health'
```

#### Ejecutar pasos individualmente (debug avanzado)

Si `task dev:up` falla, puedes ejecutar cada paso manualmente:

```bash
# Paso 1: Exportar variables manualmente
export ENV_PREFIX=dev
export MONGO_SERVERS="mongo1:27017,mongo2:27017,mongo3:27017"

# Paso 2: Iniciar solo infraestructura primero
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile dev up -d mongo1 mongo2 mongo3

# Paso 3: Esperar a que MongoDB este healthy
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile dev ps mongo1 mongo2 mongo3

# Paso 4: Ejecutar init manualmente
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile dev up mongo-init-dev

# Paso 5: Iniciar Redis y NATS
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile dev up -d redis-dev nats

# Paso 6: Iniciar un servicio a la vez
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile dev up -d --build movie

# Paso 7: Verificar logs
docker logs cinema-movie

# Paso 8: Si funciona, iniciar el resto
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  --profile dev up -d --build
```

---

### 2.4 Iniciar manualmente (avanzado)

**Objetivo:** Entender el comando subyacente para casos especiales.

**Por que es importante:** Util cuando necesitas personalizar el inicio o debuggear problemas.

```bash
# Paso 1: Definir variables de entorno
export ENV_PREFIX=dev
export MONGO_SERVERS="mongo1:27017,mongo2:27017,mongo3:27017"

# Paso 2: Iniciar con el perfil dev
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d --build
```

**Explicacion de flags:**
- `-f ...`: Especifica ubicacion del docker-compose.yml
- `--profile dev`: Activa solo contenedores del perfil dev
- `up`: Crea e inicia contenedores
- `-d`: Detached mode (background)
- `--build`: Reconstruye imagenes si hay cambios

**Para iniciar SIN rebuild (mas rapido):**
```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d
```

---

### 2.5 Ver estado de contenedores

**Objetivo:** Verificar que todos los contenedores estan corriendo.

**Por que es importante:** Un contenedor caido significa que ese servicio no esta disponible.

```bash
task dev:status
```

**O directamente:**
```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps -a
```

**Respuesta esperada:**
```
NAME                   IMAGE                              STATUS                   PORTS
dev-mongo1             mongo:8.0                          healthy                  0.0.0.0:27017->27017/tcp
dev-mongo2             mongo:8.0                          healthy                  0.0.0.0:27018->27017/tcp
dev-mongo3             mongo:8.0                          healthy                  0.0.0.0:27019->27017/tcp
dev-mongo-init         docker-compose-mongo-init-dev      Exited (0)
dev-redis              redis:7-alpine                     healthy                  0.0.0.0:6379->6379/tcp
cinema-nats            nats:2.10-alpine                   healthy                  0.0.0.0:4222->4222/tcp
cinema-movie           crizstian/movie-service:dev        healthy                  0.0.0.0:8002->8002/tcp
cinema-cinema          crizstian/cinema-service:dev       healthy                  0.0.0.0:8003->8003/tcp
cinema-user            crizstian/user-service:dev         healthy                  0.0.0.0:8004->8004/tcp
cinema-seat            crizstian/seat-service:dev         healthy                  0.0.0.0:8005->8005/tcp
cinema-showtime        crizstian/showtime-service:dev     healthy                  0.0.0.0:8006->8006/tcp
cinema-payment         crizstian/payment-service:dev      healthy                  0.0.0.0:8007->8007/tcp
cinema-notification    crizstian/notification-service:dev healthy                  0.0.0.0:8008->8008/tcp
cinema-booking         crizstian/booking-service:dev      healthy                  0.0.0.0:8001->8001/tcp
```

**Que verificar:**
- Todos los servicios muestran `healthy`
- `mongo-init` muestra `Exited (0)` (es un job one-shot, debe terminar)
- Los puertos coinciden con `config:show`

**Si un servicio muestra `unhealthy` o `restarting`:**
```bash
# Ver logs del servicio problematico
docker logs cinema-booking --tail 50
```

---

## Fase 3: Validacion de Servicios

### 3.1 Health Checks basicos

**Objetivo:** Verificar que cada servicio responde a su endpoint de salud.

**Por que es importante:** Un contenedor `healthy` no garantiza que la aplicacion funcione. Los health checks verifican la aplicacion real.

```bash
echo "=== Health Checks ==="

for port in 8001 8002 8003 8004 8005 8006 8007 8008; do
  response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/health/live)
  if [ "$response" = "200" ]; then
    echo "Port $port: OK"
  else
    echo "Port $port: FAIL (HTTP $response)"
  fi
done
```

**Respuesta esperada:**
```
=== Health Checks ===
Port 8001: OK
Port 8002: OK
Port 8003: OK
Port 8004: OK
Port 8005: OK
Port 8006: OK
Port 8007: OK
Port 8008: OK
```

**Health endpoints disponibles:**

| Endpoint | Proposito | Cuando falla |
|----------|-----------|--------------|
| `/health/live` | Proceso vivo | Contenedor crasheado |
| `/health/ready` | Listo para trafico | Dependencias caidas |
| `/ping` | Legacy | Deprecado |

---

### 3.2 Verificar MongoDB Replica Set

**Objetivo:** Confirmar que MongoDB esta funcionando como replica set.

**Por que es importante:** Los microservicios usan transacciones que requieren replica set. Sin el, las operaciones de booking fallaran.

```bash
docker exec dev-mongo1 mongosh --eval "rs.status()" | grep -E "(name|stateStr)"
```

**Respuesta esperada:**
```
name: 'rs0',
      name: 'mongo1:27017',
      stateStr: 'PRIMARY',
      name: 'mongo2:27017',
      stateStr: 'SECONDARY',
      name: 'mongo3:27017',
      stateStr: 'SECONDARY',
```

**Que verificar:**
- Un nodo es `PRIMARY`
- Dos nodos son `SECONDARY`
- El replica set se llama `rs0`

**Si falla:**
```bash
# Reiniciar el init container
docker restart dev-mongo-init

# Ver logs del init
docker logs dev-mongo-init
```

---

### 3.3 Verificar Redis

**Objetivo:** Confirmar que Redis esta disponible para cache de sesiones.

**Por que es importante:** El servicio `seat` usa Redis para locks temporales de asientos. Sin Redis, los holds de asientos no funcionan.

```bash
docker exec dev-redis redis-cli ping
```

**Respuesta esperada:**
```
PONG
```

```bash
# Ver informacion del servidor
docker exec dev-redis redis-cli info server | head -5
```

**Respuesta esperada:**
```
# Server
redis_version:7.2.4
redis_git_sha1:00000000
redis_git_dirty:0
redis_build_id:...
```

---

### 3.4 Verificar NATS

**Objetivo:** Confirmar que NATS esta disponible para mensajeria.

**Por que es importante:** Los servicios usan NATS para eventos asincronos (notificaciones, actualizaciones).

```bash
curl -s http://localhost:8222/healthz
```

**Respuesta esperada:**
```
ok
```

```bash
# Ver estado del servidor
curl -s http://localhost:8222/varz | head -10
```

**Respuesta esperada:**
```json
{
  "server_id": "XXXXXXXXXXXXXXXXXXXXXXXX",
  "server_name": "XXXXXXXXXXXXXXXXXXXXXXXX",
  "version": "2.10.x",
  "proto": 1,
  "go": "go1.21.x",
  ...
}
```

---

### 3.5 Verificar conectividad entre servicios

**Objetivo:** Confirmar que los servicios pueden comunicarse entre si.

**Por que es importante:** Los servicios se comunican via la red Docker. Si la red falla, las llamadas inter-servicio fallan.

```bash
# Desde booking, verificar que puede alcanzar payment
docker exec cinema-booking wget -qO- --timeout=5 http://payment:8007/health/ready
```

**Respuesta esperada:**
```
pong
```

```bash
# Verificar todas las dependencias de booking
echo "=== Conectividad desde booking ==="
for svc in payment seat showtime notification; do
  docker exec cinema-booking wget -qO- --timeout=3 http://$svc:80${svc:0:1}0${svc:4:1}/health/live 2>/dev/null \
    && echo "  $svc: OK" || echo "  $svc: FAIL"
done
```

**Nota:** El hostname dentro de Docker es el nombre del servicio (`payment`, `seat`, etc.), no `localhost`.

---

## Fase 4: Testing de APIs

### 4.1 Listar peliculas

**Objetivo:** Verificar que el servicio movie responde con datos.

**Por que es importante:** Este es el flujo mas simple. Si falla, hay un problema fundamental.

```bash
curl -s http://localhost:8002/api/movies | jq '.'
```

**Respuesta esperada (con datos de seed):**
```json
[
  {
    "id": "mov_shawshank",
    "title": "The Shawshank Redemption",
    "director": "Frank Darabont",
    "duration": 142,
    "rating": "R",
    "year": 1994
  },
  {
    "id": "mov_inception",
    "title": "Inception",
    "director": "Christopher Nolan",
    "duration": 148,
    "rating": "PG-13",
    "year": 2010
  }
]
```

**Si responde `[]` (vacio):**
- Los datos de seed no se cargaron
- Verifica logs: `docker logs dev-mongo-init`
- Re-ejecuta seed: `docker restart dev-mongo-init`

**Si responde error 500:**
- El servicio no puede conectar a MongoDB
- Verifica logs: `docker logs cinema-movie`

---

### 4.2 Crear usuario

**Objetivo:** Verificar el flujo de creacion de usuarios.

```bash
curl -s -X POST http://localhost:8004/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "password": "test123"
  }' | jq '.'
```

**Respuesta esperada:**
```json
{
  "id": "usr_xxxxxxxx",
  "email": "test@example.com",
  "name": "Test User",
  "created_at": "2024-04-20T10:30:00Z"
}
```

---

### 4.3 Obtener showtimes

**Objetivo:** Verificar que showtimes devuelve funciones disponibles.

```bash
curl -s http://localhost:8006/api/showtimes | jq '.'
```

**Respuesta esperada:**
```json
[
  {
    "id": "sht_001",
    "movie_id": "mov_shawshank",
    "cinema_id": "cin_downtown",
    "room_id": "room_1",
    "start_time": "2024-04-21T19:00:00Z",
    "price": 150
  }
]
```

---

### 4.4 Ver mapa de asientos

**Objetivo:** Verificar que el servicio seat devuelve disponibilidad.

```bash
# Obtener showtime ID primero
SHOWTIME_ID=$(curl -s http://localhost:8006/api/showtimes | jq -r '.[0].id')

# Ver asientos disponibles
curl -s "http://localhost:8005/api/showtimes/${SHOWTIME_ID}/seats" | jq '.'
```

**Respuesta esperada:**
```json
{
  "showtime_id": "sht_001",
  "total_seats": 100,
  "available": 98,
  "seats": [
    {"id": "A1", "row": "A", "number": 1, "type": "VIP", "status": "available"},
    {"id": "A2", "row": "A", "number": 2, "type": "VIP", "status": "available"},
    ...
  ]
}
```

---

### 4.5 Flujo completo de booking

**Objetivo:** Ejecutar el flujo end-to-end de reserva.

**Por que es importante:** Este flujo involucra todos los servicios (SAGA pattern). Si funciona, todo el sistema esta correcto.

```bash
# Paso 1: Crear usuario
USER=$(curl -s -X POST http://localhost:8004/api/users \
  -H "Content-Type: application/json" \
  -d '{"email": "booking-test@example.com", "name": "Booking Test", "password": "test123"}')
USER_ID=$(echo $USER | jq -r '.id')
echo "Created user: $USER_ID"

# Paso 2: Obtener showtime
SHOWTIME=$(curl -s http://localhost:8006/api/showtimes | jq '.[0]')
SHOWTIME_ID=$(echo $SHOWTIME | jq -r '.id')
echo "Using showtime: $SHOWTIME_ID"

# Paso 3: Hold seats
HOLD=$(curl -s -X POST "http://localhost:8005/api/showtimes/${SHOWTIME_ID}/hold" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "'$USER_ID'", "seats": ["A1", "A2"]}')
HOLD_ID=$(echo $HOLD | jq -r '.hold_id')
echo "Hold created: $HOLD_ID"

# Paso 4: Create booking
BOOKING=$(curl -s -X POST http://localhost:8001/api/bookings \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "'$USER_ID'",
    "showtime_id": "'$SHOWTIME_ID'",
    "hold_id": "'$HOLD_ID'",
    "seats": ["A1", "A2"],
    "payment": {
      "method": "card",
      "token": "tok_mock_visa"
    }
  }')
echo "Booking result:"
echo $BOOKING | jq '.'
```

**Respuesta esperada:**
```json
{
  "order_id": "ORD-20240420-XXXXX",
  "status": "confirmed",
  "user_id": "usr_xxxxxxxx",
  "showtime_id": "sht_001",
  "seats": ["A1", "A2"],
  "total": 300,
  "payment_id": "pay_xxxxxxxx",
  "created_at": "2024-04-20T10:35:00Z"
}
```

---

### 4.6 Ver logs en tiempo real

**Objetivo:** Monitorear la actividad de los servicios durante testing.

```bash
# Logs de todos los servicios
task dev:logs

# Logs de un servicio especifico
task dev:logs SERVICE=booking

# O directamente
docker logs cinema-booking -f --tail 50
```

**Respuesta esperada:**
```
time="2024-04-20T10:30:00Z" level=info msg="--- Booking Service ---"
time="2024-04-20T10:30:01Z" level=info msg="Connected to MongoDB"
time="2024-04-20T10:30:01Z" level=info msg="Server started on :8001"
time="2024-04-20T10:35:00Z" level=info msg="POST /api/bookings" user_id=usr_xxx
time="2024-04-20T10:35:01Z" level=info msg="SAGA: Validating showtime"
time="2024-04-20T10:35:01Z" level=info msg="SAGA: Processing payment"
time="2024-04-20T10:35:02Z" level=info msg="SAGA: Confirming seats"
time="2024-04-20T10:35:02Z" level=info msg="SAGA: Sending notification"
time="2024-04-20T10:35:02Z" level=info msg="Booking confirmed" order_id=ORD-xxx
```

---

## Fase 5: Troubleshooting

### 5.1 Contenedor en estado "Restarting"

**Objetivo:** Diagnosticar por que un contenedor se reinicia constantemente.

**Por que ocurre:** La aplicacion falla al iniciar, generalmente por dependencias no disponibles.

```bash
# Ver estado actual
docker ps -a | grep -E "(Restarting|unhealthy)"

# Ver logs del contenedor
docker logs cinema-booking --tail 100
```

**Errores comunes y soluciones:**

| Error en logs | Causa | Solucion |
|---------------|-------|----------|
| `connection refused` | MongoDB no disponible | Esperar a que mongo1 este healthy |
| `no reachable servers` | Replica set no iniciado | Reiniciar `mongo-init` |
| `dial tcp: lookup` | DNS no resuelve | Verificar red Docker |
| `context deadline exceeded` | Timeout de conexion | Aumentar timeouts |

```bash
# Reiniciar un servicio especifico
docker compose -f platform/deploy/docker-compose/docker-compose.yml restart booking

# Reiniciar solo los servicios (sin infra)
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev restart movie cinema user showtime seat payment notification booking
```

---

### 5.2 MongoDB no inicia replica set

**Objetivo:** Solucionar problemas con la inicializacion del replica set.

**Por que ocurre:** Los nodos MongoDB necesitan estar healthy antes de configurar el replica set.

```bash
# Ver estado de los nodos
docker ps | grep mongo

# Ver logs del init container
docker logs dev-mongo-init

# Ver logs de mongo1
docker logs dev-mongo1 --tail 50
```

**Errores comunes:**

| Error | Causa | Solucion |
|-------|-------|----------|
| `NotYetInitialized` | rs.initiate no ejecutado | Reiniciar mongo-init |
| `already initialized` | Ya existe el replica set | Ignorar, es normal |
| `no host described` | Hostnames incorrectos | Verificar docker-compose.yml |

```bash
# Forzar reinicializacion del replica set
docker exec dev-mongo1 mongosh --eval "
  rs.initiate({
    _id: 'rs0',
    members: [
      { _id: 0, host: 'mongo1:27017', priority: 2 },
      { _id: 1, host: 'mongo2:27017', priority: 1 },
      { _id: 2, host: 'mongo3:27017', priority: 1 }
    ]
  })
"
```

---

### 5.3 Puerto ya en uso

**Objetivo:** Resolver conflictos de puertos.

**Por que ocurre:** Otra aplicacion (o ejecucion anterior) esta usando el puerto.

```bash
# Ver que esta usando el puerto 8002
lsof -i :8002

# O en Linux
ss -tlnp | grep 8002
```

**Soluciones:**

```bash
# Opcion 1: Detener el proceso que usa el puerto
kill -9 <PID>

# Opcion 2: Detener Docker Compose anterior
docker compose -f platform/deploy/docker-compose/docker-compose.yml down

# Opcion 3: Usar puertos diferentes en .env
# Editar platform/deploy/docker-compose/.env (no recomendado, regenerar mejor)
```

---

### 5.4 Sin espacio en disco

**Objetivo:** Liberar espacio usado por Docker.

**Por que ocurre:** Imagenes, contenedores y volumes se acumulan.

```bash
# Ver uso de disco por Docker
docker system df
```

**Respuesta esperada:**
```
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          25        12        8.5GB     4.2GB (49%)
Containers      15        12        250MB     50MB (20%)
Local Volumes   10        6         2GB       500MB (25%)
Build Cache     100       0         3GB       3GB
```

```bash
# Limpiar recursos no usados (seguro)
docker system prune -f

# Limpiar TODO (peligroso - borra imagenes no usadas)
docker system prune -a -f

# Limpiar volumes no usados (BORRA DATOS!)
docker volume prune -f
```

---

### 5.5 Build falla

**Objetivo:** Solucionar errores durante la construccion de imagenes.

```bash
# Ver el error completo
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev build movie 2>&1 | tail -50
```

**Errores comunes:**

| Error | Causa | Solucion |
|-------|-------|----------|
| `go: module not found` | Dependencias Go no descargadas | `go mod tidy` en el servicio |
| `COPY failed` | Archivo no existe | Verificar paths en Dockerfile |
| `permission denied` | Permisos de archivos | `chmod +x scripts/*.sh` |
| `no space left` | Sin espacio disco | `docker system prune` |

```bash
# Rebuild sin cache
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev build --no-cache movie

# Rebuild un solo servicio
docker compose -f platform/deploy/docker-compose/docker-compose.yml up -d --build movie
```

---

### 5.6 Servicio no responde pero container esta healthy

**Objetivo:** Diagnosticar cuando el healthcheck pasa pero la API no funciona.

**Por que ocurre:** El healthcheck verifica `/health/live` pero la logica de negocio tiene errores.

```bash
# Verificar que el servicio responde
curl -v http://localhost:8002/api/movies

# Entrar al contenedor para debug
docker exec -it cinema-movie sh

# Dentro del contenedor:
wget -qO- http://localhost:8002/health/ready
wget -qO- http://localhost:8002/api/movies
```

```bash
# Ver variables de entorno del contenedor
docker exec cinema-movie env | sort
```

---

## Fase 6: Cleanup

### 6.1 Detener el entorno

**Objetivo:** Detener todos los contenedores pero mantener los datos.

**Por que es importante:** Libera recursos pero permite reiniciar rapido.

```bash
task dev:down
```

**O manualmente:**
```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down
```

**Respuesta esperada:**
```
[+] Running 14/14
 ✔ Container cinema-booking       Removed
 ✔ Container cinema-notification  Removed
 ✔ Container cinema-payment       Removed
 ✔ Container cinema-seat          Removed
 ✔ Container cinema-showtime      Removed
 ✔ Container cinema-user          Removed
 ✔ Container cinema-cinema        Removed
 ✔ Container cinema-movie         Removed
 ✔ Container cinema-nats          Removed
 ✔ Container dev-redis            Removed
 ✔ Container dev-mongo-init       Removed
 ✔ Container dev-mongo1           Removed
 ✔ Container dev-mongo2           Removed
 ✔ Container dev-mongo3           Removed
 ✔ Network cinema-dev-network     Removed
```

**Nota:** Los volumes persisten. Los datos de MongoDB siguen disponibles.

---

### 6.2 Limpiar todo (incluyendo datos)

**Objetivo:** Eliminar completamente el entorno, incluyendo datos.

**Por que es importante:** Util para empezar de cero o liberar todo el espacio.

```bash
# Detener Y eliminar volumes
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down -v
```

**Respuesta esperada:**
```
[+] Running 18/18
 ...
 ✔ Volume "mongo1_data"  Removed
 ✔ Volume "mongo2_data"  Removed
 ✔ Volume "mongo3_data"  Removed
 ✔ Volume "redis_data"   Removed
```

**ADVERTENCIA:** Esto elimina TODOS los datos de MongoDB y Redis.

---

### 6.3 Limpiar imagenes

**Objetivo:** Eliminar imagenes Docker locales.

**Por que es importante:** Las imagenes ocupan espacio significativo (varios GB).

```bash
# Ver imagenes del proyecto
docker images | grep crizstian

# Eliminar imagenes del proyecto
docker images | grep crizstian | awk '{print $3}' | xargs docker rmi -f

# Eliminar imagenes dangling (sin tag)
docker image prune -f
```

---

### 6.4 Reset completo

**Objetivo:** Volver al estado inicial limpio.

```bash
# Paso 1: Detener todo y eliminar volumes
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down -v

# Paso 2: Eliminar imagenes del proyecto
docker images | grep -E "(crizstian|cinema)" | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true

# Paso 3: Limpiar build cache
docker builder prune -f

# Paso 4: Regenerar configuracion
task config:generate

# Paso 5: Reiniciar
task dev:up
```

---

## Quick Reference

### Comandos Frecuentes

```bash
# === CONFIGURACION ===
task config:generate              # Genera .env desde services.yaml
task config:show                  # Muestra puertos configurados
task config:all                   # Genera .env + Harness services

# === DESARROLLO ===
task dev:up                       # Iniciar entorno completo
task dev:down                     # Detener y limpiar
task dev:status                   # Ver estado de contenedores
task dev:logs                     # Ver logs de todos los servicios
task dev:logs SERVICE=booking     # Ver logs de un servicio

# === TESTING ===
task test:e2e                     # Ejecutar tests E2E
task test SERVICE=booking         # Tests unitarios de un servicio
task test:all                     # Tests unitarios de todos

# === DOCKER COMPOSE DIRECTO ===
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev logs -f
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps

# === DEBUG ===
docker logs cinema-booking --tail 100
docker exec -it cinema-booking sh
docker exec dev-mongo1 mongosh
docker exec dev-redis redis-cli

# === CLEANUP ===
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev down -v  # Con datos
docker system prune -f            # Limpiar recursos no usados
```

### URLs de Acceso

| Servicio | Puerto | URL | Health Check |
|----------|--------|-----|--------------|
| booking | 8001 | http://localhost:8001 | /health/live |
| movie | 8002 | http://localhost:8002 | /health/live |
| cinema | 8003 | http://localhost:8003 | /health/live |
| user | 8004 | http://localhost:8004 | /health/live |
| seat | 8005 | http://localhost:8005 | /health/live |
| showtime | 8006 | http://localhost:8006 | /health/live |
| payment | 8007 | http://localhost:8007 | /health/live |
| notification | 8008 | http://localhost:8008 | /health/live |
| MongoDB | 27017-27019 | mongodb://localhost:27017 | - |
| Redis | 6379 | redis://localhost:6379 | - |
| NATS | 4222 | nats://localhost:4222 | http://localhost:8222/healthz |

### Estructura de Archivos

```
platform/
├── config/
│   └── services.yaml              # ← SINGLE SOURCE OF TRUTH
├── deploy/
│   └── docker-compose/
│       ├── docker-compose.yml     # Definicion de servicios
│       └── .env                   # ← GENERADO (gitignored)
├── docker/
│   ├── go-service/
│   │   └── Dockerfile             # Dockerfile para servicios Go
│   ├── mongodb/
│   │   ├── Dockerfile             # Init container
│   │   └── seed/                  # Scripts de seed
│   └── e2e-runner/
│       └── Dockerfile             # Runner de tests E2E
└── scripts/
    └── taskfile/
        ├── dev-up.sh              # Script para task dev:up
        ├── dev-down.sh            # Script para task dev:down
        └── config-generate.sh     # Generador de .env
```

### Flujo de Configuracion

```
┌─────────────────────────────────────────────────────────────┐
│  platform/config/services.yaml                              │
│  (SINGLE SOURCE OF TRUTH)                                   │
│                                                             │
│  services:                                                  │
│    movie:                                                   │
│      port: 8002                                             │
│      dbName: movie                                          │
│      image: crizstian/movie-service                         │
└─────────────────────────────────────────────────────────────┘
                          │
                 task config:generate
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  platform/deploy/docker-compose/.env                        │
│  (GENERATED - DO NOT EDIT)                                  │
│                                                             │
│  MOVIE_PORT=8002                                            │
│  MOVIE_DB=movie                                             │
│  MOVIE_IMAGE=crizstian/movie-service                        │
└─────────────────────────────────────────────────────────────┘
                          │
               docker compose reads
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  docker-compose.yml                                         │
│                                                             │
│  movie:                                                     │
│    image: ${MOVIE_IMAGE}:${VERSION:-dev}                    │
│    ports:                                                   │
│      - "${MOVIE_PORT}:${MOVIE_PORT}"                        │
│    environment:                                             │
│      DB_NAME: "${MOVIE_DB}"                                 │
└─────────────────────────────────────────────────────────────┘
```

### Checklist de Inicio

**Prerequisitos:**
- [ ] Docker instalado y running
- [ ] Docker Compose v2 instalado
- [ ] Task instalado (opcional pero recomendado)
- [ ] yq instalado (para config:generate)

**Configuracion:**
- [ ] `task config:generate` ejecutado
- [ ] `platform/deploy/docker-compose/.env` existe
- [ ] `task config:show` muestra puertos correctos

**Inicio:**
- [ ] `task dev:up` completa sin errores
- [ ] `task dev:status` muestra todos los servicios healthy
- [ ] MongoDB replica set iniciado (1 PRIMARY, 2 SECONDARY)

**Validacion:**
- [ ] Health checks OK (todos los puertos 8001-8008)
- [ ] API /api/movies devuelve datos
- [ ] Logs sin errores criticos

### Comparacion: Dev vs Test Profile

| Aspecto | Profile: dev | Profile: test |
|---------|--------------|---------------|
| MongoDB | 3 replicas | 1 nodo |
| Storage | Volumes persistentes | tmpfs (RAM) |
| Seed data | Persiste entre reinicios | Se pierde al parar |
| Velocidad inicio | ~2-3 min | ~30 seg |
| Caso de uso | Desarrollo diario | CI/CD, tests rapidos |
| Comando | `task dev:up` | `docker compose --profile test up` |

---

## Documentacion Relacionada

- [Development Guide](../development/README.md) - Guia general de desarrollo
- [Configuration Guide](./configuration-guide.md) - Sistema de configuracion centralizada
- [Kubernetes Deployment Guide](./kubernetes-deployment-guide.md) - Despliegue en Kubernetes
- [Debugging Runbook](./debugging-runbook.md) - Troubleshooting avanzado
