# Go Service - Dockerfile Genérico

Dockerfile optimizado y parametrizable para **todos** los servicios Go del monorepo.

## 🚀 Uso Rápido

```bash
# Build de un servicio
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg VERSION=v1.0.0 \
  -t crizstian/cinema/booking:v1.0.0 \
  services/booking/
```

## 📋 Build Args

| Arg | Default | Descripción |
|-----|---------|-------------|
| `SERVICE_NAME` | *(requerido)* | Nombre del servicio (booking, movie, payment, notification) |
| `SERVICE_PORT` | `8000` | Puerto del servicio |
| `VERSION` | `dev` | Versión de la imagen |
| `BUILD_DATE` | *(auto)* | Fecha de build ISO 8601 |
| `VCS_REF` | *(auto)* | Git commit hash |
| `GO_VERSION` | `1.21` | Versión de Go para builder |
| `ALPINE_VERSION` | `3.19` | Versión de Alpine para runtime |

## 🎯 Características

### Multi-Stage Build
- **Builder**: `golang:1.21-alpine` (~500MB)
- **Runtime**: `alpine:3.19` (~5MB base)
- **Final**: ~15MB total

### Optimizaciones
- ✅ **Caching de dependencias**: `go mod download` en capa separada
- ✅ **Binario estático**: `CGO_ENABLED=0`
- ✅ **Stripped**: `-ldflags="-w -s"` (sin símbolos debug)
- ✅ **Metadata inyectada**: Version, BuildDate, GitCommit en binario

### Seguridad
- ✅ **Usuario no-root**: `appuser` (UID 1000)
- ✅ **CA certificates**: Para HTTPS
- ✅ **Minimal dependencies**: Solo lo esencial

### Observabilidad
- ✅ **Healthcheck**: HTTP GET en `SERVICE_PORT`
- ✅ **Labels OCI**: Metadata estándar
- ✅ **Logs a stdout**: Compatible con Docker/Kubernetes

## 📦 Ejemplos

### Build Básico
```bash
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  -t booking:latest \
  services/booking/
```

### Build con Metadata
```bash
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=movie \
  --build-arg VERSION=v1.2.0 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t crizstian/cinema/movie:v1.2.0 \
  services/movie/
```

### Build con Puerto Custom
```bash
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg SERVICE_PORT=8300 \
  -t booking:latest \
  services/booking/
```

## 🧪 Validación

### Verificar Tamaño
```bash
docker images | grep booking
# Debería mostrar ~15MB
```

### Verificar Usuario No-Root
```bash
docker run --rm booking:latest whoami
# Output: appuser
```

### Verificar Healthcheck
```bash
docker run -d --name test-booking -p 8000:8000 booking:latest
sleep 10
docker inspect test-booking | jq '.[].State.Health.Status'
# Output: "healthy"
docker rm -f test-booking
```

### Verificar Metadata
```bash
docker inspect booking:latest | jq '.[].Config.Labels'
```

## 🔧 Personalización

### Variables de Entorno en Runtime
```bash
docker run -p 8000:8000 \
  -e SERVICE_PORT=8000 \
  -e DB_SERVERS=mongo:27017 \
  -e LOG_LEVEL=debug \
  booking:latest
```

### Volumes para Configuración
```bash
docker run -p 8000:8000 \
  -v $(pwd)/config.yml:/app/config.yml:ro \
  booking:latest
```

## 📊 Estructura de Capas

```
Layer 1: alpine:3.19 base          (~5MB)
Layer 2: ca-certificates, tzdata   (~2MB)
Layer 3: appuser creation          (<1MB)
Layer 4: /app directory            (<1MB)
Layer 5: Binary from builder       (~8-10MB)
----------------------------------------
Total:                             ~15MB
```

## 🚀 Integración CI/CD

### GitHub Actions
```yaml
- name: Build Docker Image
  run: |
    docker build \
      -f platform/docker/go-service/Dockerfile \
      --build-arg SERVICE_NAME=${{ matrix.service }} \
      --build-arg VERSION=${{ github.ref_name }} \
      --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
      --build-arg VCS_REF=${{ github.sha }} \
      -t ${{ secrets.REGISTRY }}/cinema/${{ matrix.service }}:${{ github.ref_name }} \
      services/${{ matrix.service }}/
```

### Makefile
```makefile
build:
	docker build \
	  -f platform/docker/go-service/Dockerfile \
	  --build-arg SERVICE_NAME=$(SERVICE) \
	  --build-arg VERSION=$(VERSION) \
	  -t $(REGISTRY)/cinema/$(SERVICE):$(VERSION) \
	  services/$(SERVICE)/
```

## 📝 Notas

### .dockerignore
El archivo `.dockerignore` en este directorio excluye archivos innecesarios del contexto de build, reduciendo el tamaño de ~50MB a ~5MB.

### Compatibilidad
Este Dockerfile funciona para **todos** los servicios Go del monorepo:
- booking
- movie
- payment
- notification

### Requisitos del Servicio
Para que un servicio sea compatible con este Dockerfile, debe:
1. Tener estructura `cmd/<service-name>/main.go`
2. Tener estructura `internal/` para código privado
3. Tener `go.mod` y `go.sum` en la raíz del servicio
4. Exponer un servidor HTTP en `SERVICE_PORT`

## 🔗 Referencias

- [Análisis de Dockerfiles](../../../docs/DOCKERFILE-ANALYSIS.md)
- [Mejoras Implementadas](../../../docs/DOCKERFILE-IMPROVEMENTS.md)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [OCI Image Spec](https://github.com/opencontainers/image-spec)
