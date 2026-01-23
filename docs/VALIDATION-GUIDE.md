# Guía de Validación Automatizada del Monorepo

## Descripción General

Este sistema de validación proporciona una manera automatizada y completa de verificar que el monorepo de Cinema Microservices funciona correctamente después de cambios estructurales, refactorizaciones o nuevas implementaciones.

La validación se ejecuta en **7 etapas progresivas**, desde lo más básico (estructura de archivos) hasta lo más complejo (integración end-to-end).

> **Nota**: Para validación manual paso a paso del refactor, consulta [REFACTOR-VALIDATION-GUIDE.md](./REFACTOR-VALIDATION-GUIDE.md)

## Tabla de Contenidos

- [Etapas de Validación](#etapas-de-validación)
- [Prerrequisitos](#prerrequisitos)
- [Uso Rápido](#uso-rápido)
- [Uso Avanzado](#uso-avanzado)
- [Interpretación de Resultados](#interpretación-de-resultados)
- [Troubleshooting](#troubleshooting)
- [Variables de Ambiente](#variables-de-ambiente)
- [Integración CI/CD](#integración-con-cicd)

## Etapas de Validación

### Etapa 1: Validación de Estructura

**Script**: `platform/scripts/validation/01-validate-structure.sh`

**Propósito**: Verificar que la estructura del monorepo es correcta.

**Verificaciones**:
- ✅ Estructura de directorios (`services/`, `platform/`, `docs/`)
- ✅ `go.work` contiene los 4 servicios
- ✅ Cada servicio tiene `cmd/`, `internal/`, `go.mod`
- ✅ Dockerfiles centralizados existen
- ✅ No hay archivos duplicados

**Tiempo**: ~2 segundos

### Etapa 2: Validación de Go Workspace

**Script**: `platform/scripts/validation/02-validate-workspace.sh`

**Verificaciones**:
- ✅ `go work sync` sin errores
- ✅ `go mod verify` para cada servicio
- ✅ Dependencias descargadas
- ✅ Servicios compilan

**Tiempo**: ~5-10 segundos

### Etapa 3: Validación de Tests Unitarios

**Script**: `platform/scripts/validation/03-validate-unit-tests.sh`

**Verificaciones**:
- ✅ Tests unitarios pasan
- ✅ Cobertura de código
- ✅ No hay tests ignorados

**Tiempo**: ~15-30 segundos

### Etapa 4: Validación de Builds Docker

**Script**: `platform/scripts/validation/04-validate-builds.sh`

**Verificaciones**:
- ✅ Construcción de imágenes exitosa
- ✅ Tamaño de imágenes apropiado
- ✅ Metadata OCI presente

**Tiempo**: ~60-90 segundos

### Etapa 5: Validación de MongoDB

**Script**: `platform/scripts/validation/05-validate-mongodb.sh`

**Verificaciones**:
- ✅ Replica set funcional
- ✅ 1 PRIMARY + 2 SECONDARY
- ✅ Datos de prueba cargados
- ✅ Escritura y lectura funcionan

**Tiempo**: ~90-120 segundos

### Etapa 6: Validación de Servicios

**Script**: `platform/scripts/validation/06-validate-services.sh`

**Verificaciones**:
- ✅ Servicios responden en `/ping`
- ✅ Healthchecks pasan
- ✅ Sin errores críticos en logs
- ✅ Conexiones a MongoDB OK

**Tiempo**: ~60-90 segundos

### Etapa 7: Validación de Integración

**Script**: `platform/scripts/validation/07-validate-integration.sh`

**Verificaciones**:
- ✅ `GET /movies/all` funciona
- ✅ `POST /booking/` funciona
- ✅ Comunicación inter-servicio
- ✅ Tests de integración pasan

**Tiempo**: ~30-60 segundos

## Prerrequisitos

### Software Requerido

```bash
# Verificar Go 1.21+
go version

# Verificar Docker
docker --version
docker-compose --version

# Verificar curl
curl --version
```

## Uso Rápido

### Validación Completa

```bash
make validate
```

### Validación Rápida (Sin Docker)

```bash
make validate-quick
```

### Validación Solo Docker

```bash
make validate-docker
```

### Etapas Individuales

```bash
make validate-structure     # Etapa 1
make validate-workspace     # Etapa 2
make validate-tests         # Etapa 3
make validate-builds        # Etapa 4
make validate-mongodb       # Etapa 5
make validate-services      # Etapa 6
make validate-integration   # Etapa 7
```

## Uso Avanzado

### Opciones Disponibles

```bash
# Ver ayuda
./platform/scripts/validate-monorepo.sh --help

# Ejecutar etapas específicas
./platform/scripts/validate-monorepo.sh --stages 1,2,3

# Modo verbose
./platform/scripts/validate-monorepo.sh --verbose

# Continuar después de errores
./platform/scripts/validate-monorepo.sh --continue-on-error

# Guardar resultados en JSON
./platform/scripts/validate-monorepo.sh --output-json results.json
```

### Ejemplos de Uso

**Durante desarrollo** (verificar cambios):
```bash
make validate-quick
```

**Antes de commit**:
```bash
./platform/scripts/validate-monorepo.sh --stages 1,2,3
```

**Antes de deploy**:
```bash
make validate
```

**Debug de MongoDB**:
```bash
make validate-mongodb
```

**En CI/CD**:
```bash
./platform/scripts/validate-monorepo.sh --output-json results.json --continue-on-error
```

## Interpretación de Resultados

### Salida Exitosa

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Resumen Final
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Etapas ejecutadas: 7
  Etapas exitosas:   7
  Etapas fallidas:   0
  Tiempo total:      3m 25s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ MONOREPO VALIDADO CORRECTAMENTE
```

### Códigos de Salida

- **0**: Éxito
- **1**: Error

### Símbolos

- ✅ Verificación exitosa
- ❌ Error crítico
- ⚠️ Advertencia
- ℹ️ Información
- ⏱ Tiempo

## Troubleshooting

### Error: "go work sync falló"

```bash
cd /workspace
go work sync
go mod tidy -C services/booking
```

### Error: "Tests fallan"

```bash
cd services/booking
go test -v ./internal/...
```

### Error: "Build Docker falla"

```bash
# Ver logs
docker build -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE=booking \
  -t test .
```

### Error: "MongoDB no inicializa"

```bash
# Ver logs
docker-compose -f platform/deploy/docker-compose/docker-compose.yml logs mongo1

# Limpiar y reintentar
docker-compose -f platform/deploy/docker-compose/docker-compose.yml down -v
make validate-mongodb
```

### Error: "Servicios no responden"

```bash
# Ver logs
docker-compose logs movie-service

# Verificar estado
docker-compose ps

# Probar manualmente
curl http://localhost:8000/ping
```

## Variables de Ambiente

### Control de Limpieza

```bash
# No eliminar imágenes de test
KEEP_TEST_IMAGES=true make validate-builds

# No detener MongoDB
KEEP_MONGODB_RUNNING=true make validate-mongodb

# No detener servicios
KEEP_SERVICES_RUNNING=true make validate-integration
```

### Opciones de Testing

```bash
# Race detector
RUN_RACE_DETECTOR=true make validate-tests

# Test de carga
RUN_LOAD_TEST=true make validate-integration
```

## Integración con CI/CD

### GitHub Actions

```yaml
name: Validate

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      - run: make validate
```

### GitLab CI

```yaml
validate:
  stage: test
  image: golang:1.21
  services:
    - docker:dind
  script:
    - make validate
```

## Estructura de Archivos

```
platform/scripts/
├── validate-monorepo.sh              # Script maestro
└── validation/
    ├── common.sh                     # Funciones compartidas
    ├── 01-validate-structure.sh      # Etapa 1
    ├── 02-validate-workspace.sh      # Etapa 2
    ├── 03-validate-unit-tests.sh     # Etapa 3
    ├── 04-validate-builds.sh         # Etapa 4
    ├── 05-validate-mongodb.sh        # Etapa 5
    ├── 06-validate-services.sh       # Etapa 6
    └── 07-validate-integration.sh    # Etapa 7
```

## Mejores Prácticas

### Durante Desarrollo

1. Antes de commit: `make validate-quick`
2. Después de cambios estructurales: `make validate`
3. Después de cambios en Docker: `make validate-docker`

### En CI/CD

1. Pull Requests: validación completa
2. Branches principales: validación + JSON
3. Releases: validación + test de carga

---

**Última actualización**: 2026-01-23
**Versión**: 1.0.0
