# Guía de Construcción de Imágenes Docker

## 📋 Índice

- [Guía Rápida](#guía-rápida)
- [Convención de Nombrado](#convención-de-nombrado)
- [Versionamiento](#versionamiento)
- [Uso del Makefile](#uso-del-makefile)
- [Uso del Script Directo](#uso-del-script-directo)
- [CI/CD](#integración-cicd)
- [Migración desde Scripts Antiguos](#migración-desde-scripts-antiguos)

---

## 🚀 Guía Rápida

### Build de un servicio específico

```bash
# Opción 1: Usando Makefile (recomendado)
make build SERVICE=booking-service VERSION=v1.0.0

# Opción 2: Script directo
SERVICE=booking-service VERSION=v1.0.0 ./scripts/build-image.sh
```

### Build de todos los servicios

```bash
# Opción 1: Makefile
make build-all VERSION=v1.0.0

# Opción 2: Script legacy (deprecado)
VERSION=v1.0.0 ./create-images.sh
```

### Build + Push al registry

```bash
# Un servicio
make push SERVICE=booking-service VERSION=v1.0.0

# Todos los servicios
make push-all VERSION=v1.0.0
```

---

## 🏷️ Convención de Nombrado

### Formato de imágenes

```
<registry>/<organization>/<service>:<version>
```

### Ejemplos

```
crizstian/cinema/booking-service:v1.0.0
crizstian/cinema/movie-service:v1.0.0
crizstian/cinema/base-image:v0.2.0
```

### Tags especiales

- `latest` - Última build exitosa (siempre se genera)
- `vX.Y.Z` - Release estable (SemVer)
- `vX.Y.Z-rc.N` - Release candidate
- `vX.Y.Z-<sha>` - Build de commit específico
- `v0.0.0-dev` - Desarrollo local (default)

---

## 📦 Versionamiento

Este proyecto sigue [Semantic Versioning 2.0.0](https://semver.org/).

### Formato

```
vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

### Incremento de versiones

| Tipo | Cuándo usar | Ejemplo |
|------|-------------|---------|
| **MAJOR** | Cambios incompatibles en API | v1.0.0 → v2.0.0 |
| **MINOR** | Nueva funcionalidad compatible | v1.0.0 → v1.1.0 |
| **PATCH** | Bug fixes compatibles | v1.0.0 → v1.0.1 |
| **PRERELEASE** | Release candidate, beta | v1.0.0-rc.1 |
| **BUILD** | Build metadata (SHA, fecha) | v1.0.0+20260123 |

### Ejemplos

```bash
# Release stable
make build-all VERSION=v1.0.0

# Release candidate
make build-all VERSION=v1.1.0-rc.1

# Build de desarrollo
make build-all VERSION=v0.0.0-dev

# Build con SHA de commit
make build-all VERSION=v1.0.0-$(git rev-parse --short HEAD)
```

---

## 🛠️ Uso del Makefile

### Comandos disponibles

```bash
# Ver ayuda
make help

# Listar servicios disponibles
make list

# Build de un servicio
make build SERVICE=<service> VERSION=<version>

# Build + push de un servicio
make push SERVICE=<service> VERSION=<version>

# Build de todos los servicios
make build-all VERSION=<version>

# Build + push de todos
make push-all VERSION=<version>

# Test build (sin push, con timestamp)
make test-build SERVICE=<service>
```

### Configuración de variables

El Makefile acepta las siguientes variables:

| Variable | Default | Descripción |
|----------|---------|-------------|
| `SERVICE` | - | Nombre del servicio (requerido para build single) |
| `VERSION` | v0.0.0-dev | Tag de la imagen |
| `REGISTRY` | crizstian | Registro Docker |
| `ORGANIZATION` | cinema | Nombre de la organización/proyecto |

### Ejemplos

```bash
# Build básico
make build SERVICE=booking-service VERSION=v1.2.3

# Cambiar registry y org
make build SERVICE=movie-service VERSION=v1.0.0 REGISTRY=myregistry ORGANIZATION=myorg

# Build + push
make push SERVICE=payment-service VERSION=v2.0.0

# Build de desarrollo (versión auto)
make test-build SERVICE=notification-service
```

---

## 📜 Uso del Script Directo

El script `scripts/build-image.sh` es el motor detrás del Makefile y puede usarse directamente.

### Variables de entorno

| Variable | Default | Requerida | Descripción |
|----------|---------|-----------|-------------|
| `SERVICE` | - | ✅ | Nombre del servicio |
| `VERSION` | v0.0.0-dev | ❌ | Tag de la imagen |
| `REGISTRY` | crizstian | ❌ | Registro Docker |
| `ORGANIZATION` | cinema | ❌ | Organización |
| `CONTEXT` | ./$SERVICE | ❌ | Contexto de build Docker |
| `DOCKERFILE` | $CONTEXT/Dockerfile | ❌ | Ruta al Dockerfile |
| `PUSH` | false | ❌ | Pushear al registry (true/false) |
| `BUILD_ARGS` | - | ❌ | Args adicionales para docker build |

### Ejemplos

```bash
# Build mínimo
SERVICE=booking-service ./scripts/build-image.sh

# Build con versión específica
SERVICE=booking-service VERSION=v1.0.0 ./scripts/build-image.sh

# Build + push
SERVICE=booking-service VERSION=v1.0.0 PUSH=true ./scripts/build-image.sh

# Dockerfile en ubicación no estándar
SERVICE=custom-service CONTEXT=./path/to/service DOCKERFILE=./path/to/Dockerfile ./scripts/build-image.sh

# Pasar argumentos de build
SERVICE=booking-service BUILD_ARGS="--no-cache --build-arg ENV=production" ./scripts/build-image.sh
```

---

## 🔄 Integración CI/CD

### GitHub Actions

```yaml
name: Build and Push Docker Images

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service:
          - booking-service
          - movie-service
          - payment-service
          - notification-service

    steps:
      - uses: actions/checkout@v3

      - name: Extract version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT

      - name: Login to Docker Registry
        run: echo "${{ secrets.DOCKER_PASSWORD }}" | docker login -u "${{ secrets.DOCKER_USERNAME }}" --password-stdin

      - name: Build and push
        run: make push SERVICE=${{ matrix.service }} VERSION=${{ steps.version.outputs.VERSION }}
```

### GitLab CI

```yaml
variables:
  REGISTRY: registry.example.com
  ORGANIZATION: cinema

stages:
  - build
  - push

.build_template: &build_template
  stage: build
  script:
    - make build SERVICE=$SERVICE_NAME VERSION=$CI_COMMIT_TAG

booking-service:
  <<: *build_template
  variables:
    SERVICE_NAME: booking-service

movie-service:
  <<: *build_template
  variables:
    SERVICE_NAME: movie-service
```

### Jenkins

```groovy
pipeline {
    agent any

    parameters {
        choice(name: 'SERVICE', choices: ['booking-service', 'movie-service', 'payment-service'], description: 'Service to build')
        string(name: 'VERSION', defaultValue: 'v0.0.0-dev', description: 'Image version')
        booleanParam(name: 'PUSH', defaultValue: false, description: 'Push to registry')
    }

    stages {
        stage('Build') {
            steps {
                sh """
                    make build SERVICE=${params.SERVICE} VERSION=${params.VERSION}
                """
            }
        }

        stage('Push') {
            when {
                expression { params.PUSH == true }
            }
            steps {
                sh """
                    make push SERVICE=${params.SERVICE} VERSION=${params.VERSION}
                """
            }
        }
    }
}
```

---

## 🔄 Migración desde Scripts Antiguos

### Scripts deprecados

Los siguientes scripts están **deprecados** pero se mantienen temporalmente:

- `booking-service/create-image.sh`
- `movie-service/create-image.sh`
- `payment-service/create-image.sh`
- `notification-service/create-image.sh`
- `webserver/create-image.sh`
- `cinemas-db/create-image.sh`
- `base_docker_image/create-image.sh`

### Tabla de equivalencias

| Antiguo | Nuevo |
|---------|-------|
| `cd booking-service && bash create-image.sh` | `make build SERVICE=booking-service VERSION=v0.5` |
| `bash create-images.sh` | `make build-all VERSION=v0.5` |
| `cd movie-service && bash create-image.sh` | `make build SERVICE=movie-service VERSION=v0.5` |

### Plan de migración

1. **Fase 1 (actual)**: Scripts antiguos y nuevos coexisten
2. **Fase 2**: Actualizar CI/CD para usar nuevo proceso
3. **Fase 3**: Deprecar formalmente scripts individuales
4. **Fase 4**: Eliminar scripts individuales después de período de gracia

---

## 📝 Notas Adicionales

### Diferencias vs proceso antiguo

| Aspecto | Antiguo | Nuevo |
|---------|---------|-------|
| Scripts | 7 duplicados | 1 genérico |
| Versionamiento | Hardcodeado | Parametrizado |
| Nombrado | Inconsistente | Estandarizado |
| Destructivo | `docker rm -f` | Sin ops destructivas |
| CI/CD | No parametrizable | Totalmente parametrizable |
| Push | Siempre | Opcional |

### Troubleshooting

**Error: SERVICE es requerido**
```bash
# ❌ Incorrecto
./scripts/build-image.sh

# ✅ Correcto
SERVICE=booking-service ./scripts/build-image.sh
```

**Imagen no encontrada en runtime**
```bash
# Verificar que se construyó correctamente
docker images | grep booking-service

# Reconstruir forzando pull de base
SERVICE=booking-service BUILD_ARGS="--pull" ./scripts/build-image.sh
```

**Push falla con "unauthorized"**
```bash
# Login en el registry
docker login crizstian

# Retry
make push SERVICE=booking-service VERSION=v1.0.0
```

---

## 📚 Referencias

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Semantic Versioning](https://semver.org/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
