# Platform Docker - Dockerfiles Centralizados

Este directorio contiene los Dockerfiles centralizados y optimizados para todo el monorepo.

## 📁 Estructura

```
platform/docker/
├── go-service/                # ✨ Dockerfile genérico para servicios Go
│   ├── Dockerfile
│   ├── .dockerignore
│   └── README.md
├── devcontainer/              # ✨ Contenedor de desarrollo
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── devcontainer.json
│   └── README.md
├── base/                      # Imagen base Alpine (si usas Consul/Vault)
│   └── Dockerfile
├── mongodb/                   # MongoDB Replica Set
│   ├── Dockerfile
│   └── Dockerfile.optimized
└── webserver/                 # Nginx reverse proxy
    ├── Dockerfile
    └── Dockerfile.optimized
```

## 🚀 Uso

### Build de Servicios Go

**Opción 1: Usando script helper (recomendado)**
```bash
SERVICE=booking VERSION=v1.0.0 platform/scripts/build-go-service.sh
```

**Opción 2: Docker build directo**
```bash
docker build \
  -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  --build-arg SERVICE_PORT=8000 \
  --build-arg VERSION=v1.0.0 \
  -t crizstian/cinema/booking:v1.0.0 \
  services/booking/
```

**Opción 3: Usando Makefile**
```bash
make build SERVICE=booking VERSION=v1.0.0
```

### Build Args Disponibles

| Arg | Default | Descripción |
|-----|---------|-------------|
| `SERVICE_NAME` | (requerido) | Nombre del servicio |
| `SERVICE_PORT` | 8000 | Puerto del servicio |
| `VERSION` | dev | Versión de la imagen |
| `GO_VERSION` | 1.21 | Versión de Go |
| `ALPINE_VERSION` | 3.19 | Versión de Alpine |
| `BUILD_DATE` | (auto) | Fecha de build |
| `VCS_REF` | (auto) | Git commit hash |

## 🎯 Mejores Prácticas Implementadas

### ✅ Multi-Stage Build
Reduce el tamaño final de la imagen de ~500MB a ~15MB.

### ✅ Caching Inteligente
Las dependencias Go se cachean independientemente del código fuente.

### ✅ Usuario No-Root
Todos los servicios corren como `appuser` (UID 1000).

### ✅ Healthchecks
Healthchecks HTTP integrados para Kubernetes/Docker.

### ✅ Labels OCI
Metadata completa según spec OCI.

### ✅ Build Metadata
Versión, commit Git y fecha inyectados en el binario.

## 📊 Ventajas vs Dockerfiles Individuales

| Aspecto | Antes | Ahora |
|---------|-------|-------|
| **Archivos** | 4 duplicados | 1 genérico ✅ |
| **Mantenimiento** | Actualizar 4 archivos | 1 archivo ✅ |
| **Consistencia** | Riesgo divergencia | Garantizada ✅ |
| **Best practices** | Difícil aplicar | Centralizadas ✅ |
| **Build time** | ~45s | ~30s (cache) ✅ |
| **Tamaño imagen** | ~20MB | ~15MB ✅ |
| **Seguridad** | Root user | No-root ✅ |

## 🔧 Personalización por Servicio

Cada servicio puede customizar:

- **Puerto**: Via `--build-arg SERVICE_PORT=XXXX`
- **Variables de entorno**: En runtime con `-e`
- **Volumes**: Para configuración dinámica

**Ejemplo con configuración custom**:
```bash
docker run \
  -p 8300:8300 \
  -e SERVICE_PORT=8300 \
  -e DB_SERVERS=mongo1:27017,mongo2:27017 \
  -e LOG_LEVEL=debug \
  -v $(pwd)/config.yml:/app/config.yml \
  crizstian/cinema/booking:v1.0.0
```

## 🧪 Testing

### Validar Build
```bash
# Build de prueba
docker build \
  -f platform/docker/go-service.Dockerfile \
  --build-arg SERVICE_NAME=booking \
  -t test-booking:latest \
  services/booking/

# Verificar tamaño
docker images | grep test-booking

# Verificar capas
docker history test-booking:latest
```

### Validar Healthcheck
```bash
# Ejecutar contenedor
docker run -d --name test-booking -p 8000:8000 test-booking:latest

# Esperar inicio
sleep 10

# Verificar health
docker inspect test-booking | jq '.[].State.Health'

# Debería mostrar: "Status": "healthy"

# Cleanup
docker rm -f test-booking
```

### Validar Usuario No-Root
```bash
docker run --rm test-booking:latest whoami
# Debería mostrar: appuser

docker run --rm test-booking:latest id
# Debería mostrar: uid=1000(appuser) gid=1000(appgroup)
```

## 📦 Tamaños de Referencia

| Imagen | Tamaño |
|--------|--------|
| **Builder stage** | ~500MB |
| **Runtime (Alpine)** | ~5MB |
| **App binary** | ~8-10MB |
| **Total final** | **~15MB** ✅ |

## 🐳 Dockerfile Genérico - Highlights

```dockerfile
# Stage 1: Builder
FROM golang:1.21-alpine AS builder
ARG SERVICE_NAME
COPY go.mod go.sum ./
RUN go mod download        # ← Cacheado independiente
COPY cmd ./cmd
COPY internal ./internal
RUN go build -ldflags="-w -s -X main.Version=${VERSION}" \
  ./cmd/${SERVICE_NAME}

# Stage 2: Runtime
FROM alpine:3.19
RUN adduser -D -u 1000 appuser
USER appuser               # ← No-root
COPY --from=builder /build/app /app/service
HEALTHCHECK ...            # ← Healthcheck integrado
ENTRYPOINT ["/app/service"]
```

## 🔒 Seguridad

### Vulnerabilities Scanning
```bash
# Usar Trivy para escanear
trivy image crizstian/cinema/booking:v1.0.0

# Usar Docker Scout
docker scout cves crizstian/cinema/booking:v1.0.0
```

### SBOM Generation
```bash
docker sbom crizstian/cinema/booking:v1.0.0
```

## 📝 Notas

### .dockerignore
El archivo `.dockerignore` en este directorio excluye:
- Tests (`*_test.go`)
- Documentación (`*.md`, `docs/`)
- Builds locales (`bin/`, `dist/`)
- IDE files (`.vscode/`, `.idea/`)

Esto reduce el contexto de build de ~50MB a ~5MB.

### Imagen Base Custom
Si usas `crizstian/cinemas-base-image`:
- Asegúrate de versionarla (no usar `:latest`)
- Considera si realmente necesitas Consul/Vault
- Si no, simplifica usando Alpine directo

## 🚀 CI/CD Integration

### GitHub Actions
```yaml
- name: Build Docker Image
  run: |
    docker build \
      -f platform/docker/go-service.Dockerfile \
      --build-arg SERVICE_NAME=${{ matrix.service }} \
      --build-arg VERSION=${{ github.ref_name }} \
      -t ${{ secrets.REGISTRY }}/cinema/${{ matrix.service }}:${{ github.ref_name }} \
      services/${{ matrix.service }}/
```

### GitLab CI
```yaml
build:
  script:
    - docker build -f platform/docker/go-service.Dockerfile
        --build-arg SERVICE_NAME=$SERVICE_NAME
        --build-arg VERSION=$CI_COMMIT_TAG
        -t $CI_REGISTRY/cinema/$SERVICE_NAME:$CI_COMMIT_TAG
        services/$SERVICE_NAME/
```

## 📚 Referencias

- [Análisis Completo](../../docs/DOCKERFILE-ANALYSIS.md)
- [Mejoras Implementadas](../../docs/DOCKERFILE-IMPROVEMENTS.md)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)

---

**Última actualización**: 2026-01-23
**Mantenedor**: DevOps Team
