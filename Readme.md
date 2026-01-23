# Cinemas Microservices - Go Monorepo

Monorepo de microservicios para gestión de cines, construido con Go 1.21 y arquitectura de servicios distribuidos.

## 📁 Estructura del Monorepo

```
.
├── go.work                       # Go workspace (monorepo)
│
├── services/                     # 🚀 SERVICIOS / APLICACIONES
│   ├── booking/                 # Servicio de reservas
│   │   ├── cmd/booking/         # Punto de entrada
│   │   ├── internal/            # Código privado del servicio
│   │   ├── go.mod
│   │   └── README.md
│   ├── movie/                   # Servicio de películas
│   ├── payment/                 # Servicio de pagos
│   └── notification/            # Servicio de notificaciones
│
├── platform/                     # 🏗️ INFRAESTRUCTURA Y TOOLING
│   ├── docker/
│   │   ├── base/               # Alpine base image
│   │   ├── mongodb/            # MongoDB replica set
│   │   └── webserver/          # Nginx
│   ├── deploy/
│   │   ├── docker-compose/     # Configuración local
│   │   └── hashicorp/          # Nomad + Consul + Vault
│   └── scripts/                # Build scripts, validation
│
├── docs/                         # 📖 DOCUMENTACIÓN
│   ├── DOCKER-BUILD.md
│   ├── MONGODB-VALIDATION.md
│   └── REFACTOR-ANALYSIS.md
│
├── Makefile                      # Targets de alto nivel
└── README.md                     # Este archivo
```

## 🚀 Servicios

| Servicio | Puerto | Descripción | Path |
|----------|--------|-------------|------|
| **booking** | 8300 | Reservas (orquesta payment + notification) | `services/booking/` |
| **movie** | 8000 | Gestión de películas y carteleras | `services/movie/` |
| **payment** | 8100 | Procesamiento de pagos (Stripe) | `services/payment/` |
| **notification** | 8200 | Envío de notificaciones por email | `services/notification/` |
| **mongodb** | 27017-27019 | MongoDB replica set (3 nodos) | `platform/docker/mongodb/` |

## 📋 Requisitos

- **Go 1.21+** (para desarrollo local)
- **Docker** y **Docker Compose** (para deployment)
- **Make** (opcional, para comandos de build)

## 🛠️ Comandos Principales

### Desarrollo Local (sin Docker)

```bash
# Sincronizar dependencias del workspace
go work sync

# Ejecutar un servicio específico
cd services/booking
go run ./cmd/booking

# Ejecutar tests unitarios
go test ./services/booking/internal/...
go test ./services/movie/internal/...

# Ejecutar tests de integración (requiere MongoDB en docker-compose)
docker compose -f platform/deploy/docker-compose/docker-compose.yml up -d mongo1 mongo2 mongo3
go test -tags=integration ./...

# Build de un servicio
cd services/booking
go build -o booking ./cmd/booking
```

### Build de Imágenes Docker

```bash
# ✅ Usando script optimizado (recomendado)
SERVICE=booking VERSION=v1.0.0 platform/scripts/build-go-service.sh

# Alternativa: Docker directo con Dockerfile genérico
docker build -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg VERSION=v1.0.0 \
  -t crizstian/cinema/booking:v1.0.0 \
  services/booking/

# Usando Makefile (legacy)
make build SERVICE=booking VERSION=v1.0.0
```

📖 **Ver documentación completa**:
- Dockerfiles: [platform/docker/README.md](./platform/docker/README.md)
- MongoDB Replica Set: [docs/MONGODB-VALIDATION.md](./docs/MONGODB-VALIDATION.md)
- Análisis de Refactor: [docs/REFACTOR-ANALYSIS.md](./docs/REFACTOR-ANALYSIS.md)
- DevContainer: [platform/docker/devcontainer/README.md](./platform/docker/devcontainer/README.md)

### Deployment con Docker Compose

```bash
# Levantar todos los servicios
cd platform/deploy/docker-compose
docker compose up -d

# Ver logs
docker compose logs -f booking

# Detener servicios
docker compose down

# Rebuild y restart
docker compose up -d --build
```

### Deployment con Hashicorp Stack

Para entorno simulado con Nomad, Consul y Vault:

```bash
cd platform/deploy/hashicorp
vagrant up
# Ver platform/deploy/hashicorp/readme.md para detalles
```

## 🔧 Variables de Entorno

### booking service
```env
DB_USER=cristian
DB_PASS=cristianPassword2017
DB_SERVERS=10.7.0.3:27017,10.7.0.4:27017,10.7.0.5:27017
DB_NAME=booking
DB_REPLICA=rs1
SERVICE_PORT=8000
PAYMENT_URL=http://10.7.0.7:8000
NOTIFICATION_URL=http://10.7.0.8:8000
```

### notification service
```env
SERVICE_PORT=8000
EMAIL=your-email@gmail.com
EMAIL_PASS=your-app-password
```

### movie / payment services
```env
DB_USER=cristian
DB_PASS=cristianPassword2017
DB_SERVERS=10.7.0.3:27017,10.7.0.4:27017,10.7.0.5:27017
DB_NAME=movies  # o "payment"
DB_REPLICA=rs1
SERVICE_PORT=8000
```

## 🏗️ Arquitectura

- **Framework Web**: Echo v3/v4
- **Base de datos**: MongoDB (replica set de 3 nodos)
- **Logging**: Logrus (structured logging)
- **Tracing**: OpenTracing + Jaeger (opcional)
- **Deployment**: Docker multi-stage builds
- **Orquestación**: Docker Compose / Nomad

## 📝 Convenciones del Monorepo

### Estructura de Servicios

Cada servicio sigue la estructura estándar de Go:

```
services/<service-name>/
├── cmd/
│   └── <service-name>/
│       └── main.go        # Punto de entrada
├── internal/              # Código privado del servicio
│   ├── api/              # HTTP handlers
│   ├── models/           # Estructuras de datos
│   ├── db/               # Acceso a datos
│   ├── routes/           # Definición de rutas
│   └── server/           # Setup del servidor
├── go.mod                # Módulo Go independiente
├── Dockerfile
└── README.md
```

### Agregar un Nuevo Servicio

1. Crear estructura en `services/<new-service>/`:
   ```bash
   mkdir -p services/newservice/cmd/newservice
   mkdir -p services/newservice/internal/{api,models,db,routes,server}
   ```

2. Crear `go.mod`:
   ```bash
   cd services/newservice
   go mod init cinemas/services/newservice
   ```

3. Crear `main.go` en `cmd/newservice/`

4. Añadir al workspace:
   ```bash
   # Editar go.work en la raíz
   use (
       ./services/booking
       ./services/movie
       ./services/payment
       ./services/notification
       ./services/newservice  # <- Añadir aquí
   )
   ```

5. Crear Dockerfile siguiendo el patrón de otros servicios

6. Sincronizar:
   ```bash
   go work sync
   ```

## 🧪 Testing

### Tests Unitarios
Los tests unitarios NO requieren MongoDB ni servicios externos:
```bash
# Ejecutar solo tests unitarios de un servicio
go test ./services/booking/internal/service/...
go test ./services/payment/internal/models/...

# Todos los servicios
go test ./services/*/internal/...
```

### Tests de Integración
Los tests de integración están marcados con build tag `integration`:
```bash
# Primero levantar MongoDB
cd platform/deploy/docker-compose
docker compose up -d mongo1 mongo2 mongo3

# Ejecutar tests de integración
go test -tags=integration ./services/booking/internal/db/...
go test -tags=integration ./services/movie/internal/db/...
```

### Cobertura
```bash
go test -cover ./...
```

## 🔒 Seguridad

- **NO commitear** credenciales reales en docker-compose.yml
- Usar variables de entorno o secrets management (Vault) en producción
- El notification-service requiere contraseñas de aplicación (no contraseñas de cuenta)

## 🚀 Mejoras Recientes

- ✅ Refactor a estructura monorepo moderna (services / platform)
- ✅ Convenciones Go estándar (cmd/ + internal/)
- ✅ Dockerfiles centralizados y optimizados en platform/docker/
- ✅ Dockerfile genérico para todos los servicios Go
- ✅ DevContainer para desarrollo local en VS Code
- ✅ Context timeouts en HTTP clients (previene bloqueos)
- ✅ Service layer en booking-service (mejor arquitectura)
- ✅ Logging estructurado (compatible con ELK/Datadog)
- ✅ Tests unitarios separados de integración
- ✅ Go 1.21 con workspace multi-módulo
- ✅ MongoDB Replica Set validado y optimizado

## 📚 Documentación

### Docker
- [Platform Docker - README](./platform/docker/README.md) - Índice de Dockerfiles
- [Go Service Dockerfile](./platform/docker/go-service/README.md) - Dockerfile genérico
- [DevContainer](./platform/docker/devcontainer/README.md) - Desarrollo local
- [Análisis de Dockerfiles](./docs/DOCKERFILE-ANALYSIS.md)
- [Mejoras de Dockerfiles](./docs/DOCKERFILE-IMPROVEMENTS.md)
- [Centralización Docker](./docs/DOCKER-CENTRALIZATION.md)
- [⚠️ Cleanup Checklist](./docs/CLEANUP-CHECKLIST.md) - Archivos pendientes de eliminación

### Monorepo
- [Análisis de Refactor](./docs/REFACTOR-ANALYSIS.md)
- [MongoDB Replica Set](./docs/MONGODB-VALIDATION.md)

## 🤝 Contribuir

1. Sigue las convenciones de estructura documentadas arriba
2. Ejecuta tests antes de commit: `go test ./...`
3. Documenta cambios significativos en `docs/`
4. Usa conventional commits para mensajes de commit

## 📄 Licencia

[Definir licencia del proyecto]

---

**Versión**: 2.0 (Refactorizado 2026-01)
**Arquitectura**: Monorepo moderno con Go Workspaces
**Mantenedor**: [Nombre/Organización]
