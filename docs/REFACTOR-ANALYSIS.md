# Análisis de Refactor - Monorepo Go Cinemas

## 🔍 Estructura Actual (Problemas Identificados)

### 1. Servicios en Raíz del Repositorio

**Problema**: Los 4 servicios están mezclados en la raíz con infraestructura y tooling:

```
/workspace/
├── booking-service/          # Servicio
├── movie-service/            # Servicio
├── payment-service/          # Servicio
├── notification-service/     # Servicio
├── base_docker_image/        # Infraestructura
├── cinemas-db/               # Infraestructura
├── webserver/                # Infraestructura
├── deploy/                   # Infraestructura
├── scripts/                  # Tooling
├── docs/                     # Documentación
└── contrib/                  # ???
```

**Impacto**: Dificulta escalar el monorepo. Al agregar más servicios, la raíz se vuelve inmanejable.

---

### 2. Estructura Interna Inconsistente

**Problema**: Cada servicio tiene `src/` como directorio intermedio, pero no sigue convenciones Go estándar:

```
booking-service/
├── src/                    # ❌ Nivel innecesario
│   ├── main.go            # ❌ Debería estar en cmd/
│   ├── api/
│   ├── db/
│   ├── models/
│   ├── config/
│   └── ...
├── go.mod
└── Dockerfile
```

**Convención Go moderna esperada**:
```
booking-service/
├── cmd/
│   └── booking/
│       └── main.go        # ✅ Punto de entrada claro
├── internal/              # ✅ Código privado del servicio
│   ├── api/
│   ├── db/
│   ├── models/
│   └── ...
├── go.mod
└── Dockerfile
```

---

### 3. Código Potencialmente Compartible No Extraído

Patrones duplicados encontrados entre servicios:

| Código | Servicios que lo tienen | Tamaño aprox | Candidato para `libs/` |
|--------|-------------------------|--------------|------------------------|
| **config** (DI, env loading) | booking, payment, notification | ~200 líneas c/u | ✅ Alta prioridad |
| **server** (Echo setup) | Todos (4) | ~100 líneas c/u | ✅ Alta prioridad |
| **db/mgo.go** (MongoDB conn) | booking, movie, payment | ~50 líneas c/u | ✅ Media prioridad |
| **errors** (custom errors) | Todos (4) | ~30 líneas c/u | ⚠️ Revisar duplicidad |
| **tracing** (Jaeger) | Solo booking | ~130 líneas | ⚠️ Podría generalizarse |
| **client** (HTTP client) | Solo booking | ~100 líneas | ⚠️ Podría generalizarse |

**Nota**: No todo debe compartirse. Solo extraer si:
1. El código es **idéntico** o **casi idéntico** entre servicios
2. Hay **beneficio claro** en centralizar mantenimiento
3. **No acopla** servicios innecesariamente

---

### 4. Infraestructura Mezclada con Servicios

**Problema**: Archivos de infra distribuidos sin organización clara:

```
├── base_docker_image/          # Base Alpine
├── cinemas-db/                 # MongoDB replica set
├── webserver/                  # Nginx
├── deploy/
│   ├── docker-compose/
│   ├── hashicorp/              # Nomad, Consul, Vault
│   └── images/
├── scripts/                    # Build scripts
└── Makefile                    # Build targets
```

**Debería estar en**:
```
platform/
├── docker/
│   ├── base/                   # base_docker_image
│   ├── mongodb/                # cinemas-db
│   └── webserver/              # nginx
├── deploy/
│   ├── compose/                # docker-compose
│   └── hashicorp/              # nomad/consul/vault
└── scripts/                    # build-image.sh, validate-mongodb.sh
```

---

### 5. Go Modules Path Hardcodeado

**Problema**: Todos los servicios usan module path `cinemas-microservices/<service>`:

```go
// booking-service/src/main.go
import (
    "cinemas-microservices/booking-service/src/api"
    "cinemas-microservices/booking-service/src/config"
    // ...
)
```

**Después del refactor**: Debemos actualizar a la nueva estructura de paths.

---

## 🎯 Estructura Objetivo (Diseño)

### Principios de Diseño

1. **Separación clara** de servicios, librerías e infraestructura
2. **Convenciones Go estándar** (`cmd/`, `internal/`, `pkg/`)
3. **Agnóstico de proveedor** (no acoplar a AWS, GCP, Nomad, etc.)
4. **Simplicidad** (no sobre-ingeniería, solo lo necesario)
5. **Escalable** (fácil agregar nuevos servicios)

---

### Nueva Estructura

```
.
├── go.work                          # Workspace con todos los módulos
│
├── services/                        # 🚀 SERVICIOS / APLICACIONES
│   ├── booking/
│   │   ├── cmd/
│   │   │   └── booking/
│   │   │       └── main.go         # Punto de entrada
│   │   ├── internal/                # Código privado del servicio
│   │   │   ├── api/                # HTTP handlers
│   │   │   ├── service/            # Lógica de negocio
│   │   │   ├── models/             # Estructuras de datos
│   │   │   └── db/                 # Acceso a datos
│   │   ├── go.mod
│   │   ├── Dockerfile
│   │   └── README.md
│   │
│   ├── movie/
│   │   └── (misma estructura)
│   │
│   ├── payment/
│   │   └── (misma estructura)
│   │
│   └── notification/
│       └── (misma estructura)
│
├── libs/                            # 📚 LIBRERÍAS COMPARTIDAS
│   ├── config/                     # Configuración y DI genérico
│   │   ├── env.go
│   │   ├── di.go
│   │   └── go.mod
│   │
│   ├── httpserver/                 # Setup Echo genérico
│   │   ├── server.go
│   │   └── go.mod
│   │
│   ├── mongodb/                    # Cliente MongoDB genérico
│   │   ├── connection.go
│   │   └── go.mod
│   │
│   └── tracing/                    # (Opcional) Jaeger tracing
│       ├── tracer.go
│       └── go.mod
│
├── platform/                        # 🏗️ INFRAESTRUCTURA Y TOOLING
│   ├── docker/
│   │   ├── base/                   # Alpine base image
│   │   ├── mongodb/                # MongoDB replica set
│   │   └── webserver/              # Nginx
│   │
│   ├── deploy/
│   │   ├── compose/                # docker-compose.yml
│   │   └── hashicorp/              # Nomad/Consul/Vault
│   │
│   └── scripts/                    # build-image.sh, validate-*.sh
│
├── docs/                            # 📖 DOCUMENTACIÓN
│   ├── DOCKER-BUILD.md
│   ├── MONGODB-VALIDATION.md
│   └── ARCHITECTURE.md (nuevo)
│
├── Makefile                         # Targets de alto nivel
└── README.md                        # Documentación principal
```

---

## 🔄 Plan de Migración

### Fase 1: Crear Estructura Base
- ✅ Crear directorios `services/`, `libs/`, `platform/`
- ✅ Mover infraestructura a `platform/`

### Fase 2: Refactor Servicios (uno por uno)
Para cada servicio:
1. Mover a `services/<name>/`
2. Crear `cmd/<name>/main.go`
3. Mover código de negocio a `internal/`
4. Actualizar `go.mod` con nuevo module path
5. Actualizar imports

### Fase 3: Extraer Librerías Compartidas
1. Crear `libs/httpserver/` con código Echo común
2. Crear `libs/mongodb/` con cliente MongoDB
3. Crear `libs/config/` (evaluar si realmente se comparte)

### Fase 4: Actualizar go.work
- Enumerar todos los módulos nuevos

### Fase 5: Validación
- `go work sync`
- `go build` por servicio
- `go test ./...`

---

## ⚠️ Decisiones Clave

### 1. ¿Mantener `src/` o eliminarlo?

**Decisión**: ❌ **Eliminar `src/`**

**Razón**: No es convención Go estándar. Go workspace ya maneja múltiples módulos sin necesidad de niveles intermedios.

---

### 2. ¿Qué extraer a `libs/`?

**Decisión**: Solo extraer si hay **duplicidad real** y **beneficio claro**.

| Candidato | Decisión | Razón |
|-----------|----------|-------|
| **httpserver** | ✅ Extraer | Código idéntico en 4 servicios (Echo setup) |
| **mongodb** | ✅ Extraer | Lógica de conexión duplicada en 3 servicios |
| **config/DI** | ⚠️ Revisar primero | Puede tener lógica específica por servicio |
| **errors** | ❌ No extraer aún | Muy pequeño (~30 líneas), puede ser específico |
| **tracing** | ⚠️ Opcional | Solo booking lo usa, generalizar si otros lo necesitan |

---

### 3. ¿Un solo go.mod o múltiples?

**Decisión**: ✅ **Múltiples módulos Go** (ya existente, mantener)

**Razón**:
- Ya hay 4 `go.mod` independientes
- Permite versionar servicios independientemente
- Permite desplegar servicios por separado
- `go.work` maneja la coordinación

---

### 4. ¿Cómo nombrar los módulos?

**Antes**:
```
cinemas-microservices/booking-service
```

**Después** (opción 1 - path corto):
```
cinemas/services/booking
cinemas/libs/httpserver
```

**Después** (opción 2 - mantener compatibilidad):
```
github.com/crizstian/cinemas-monorepo/services/booking
github.com/crizstian/cinemas-monorepo/libs/httpserver
```

**Decisión**: Usar **opción 1** (paths cortos) dado que es un monorepo local con `go.work`.

---

## 📋 Checklist de Ejecución

### Servicios
- [ ] Mover `booking-service/` → `services/booking/`
- [ ] Mover `movie-service/` → `services/movie/`
- [ ] Mover `payment-service/` → `services/payment/`
- [ ] Mover `notification-service/` → `services/notification/`
- [ ] Crear estructura `cmd/` + `internal/` en cada uno
- [ ] Actualizar imports en todos los archivos `.go`

### Librerías
- [ ] Crear `libs/httpserver/` (extraer de `*/src/server/`)
- [ ] Crear `libs/mongodb/` (extraer de `*/src/db/mgo.go`)
- [ ] (Opcional) Crear `libs/config/`
- [ ] (Opcional) Crear `libs/tracing/`

### Infraestructura
- [ ] Mover `base_docker_image/` → `platform/docker/base/`
- [ ] Mover `cinemas-db/` → `platform/docker/mongodb/`
- [ ] Mover `webserver/` → `platform/docker/webserver/`
- [ ] Mover `deploy/` → `platform/deploy/`
- [ ] Mover `scripts/` → `platform/scripts/`

### Configuración
- [ ] Actualizar `go.work` con nuevos paths
- [ ] Actualizar `Makefile` con nuevos targets
- [ ] Actualizar `README.md` con nueva estructura

### Validación
- [ ] `go work sync`
- [ ] `go build ./services/booking/cmd/booking`
- [ ] `go build ./services/movie/cmd/movie`
- [ ] `go build ./services/payment/cmd/payment`
- [ ] `go build ./services/notification/cmd/notification`
- [ ] `go test ./...` (si aplica)

---

## 🚀 Próximos Pasos

1. Revisar y aprobar este análisis
2. Ejecutar refactor por fases
3. Validar cada fase antes de continuar
4. Documentar cambios en README.md

---

**Nota**: Este refactor **NO** cambia lógica de negocio, solo reorganiza archivos y directorios.
