# ============================================================
# Dockerfile Genérico para Servicios Go - Cinemas Monorepo
# ============================================================
#
# Este Dockerfile usa multi-stage builds y build args para servir
# a TODOS los servicios Go del monorepo sin duplicación.
#
# Uso:
#   docker build -f platform/docker/go-service/Dockerfile \
#     --build-arg SERVICE_NAME=booking \
#     --build-arg SERVICE_PORT=8000 \
#     --build-arg VERSION=v1.0.0 \
#     -t crizstian/cinema/booking:v1.0.0 \
#     services/booking/
#
# ============================================================

# ------------------------------------------------------------
# Build Arguments (parametrización)
# ------------------------------------------------------------
ARG GO_VERSION=1.21
ARG ALPINE_VERSION=3.19

# ------------------------------------------------------------
# Stage 1: Builder
# ------------------------------------------------------------
FROM golang:${GO_VERSION}-alpine AS builder

# Build args para el servicio
ARG SERVICE_NAME
ARG VERSION=dev
ARG BUILD_DATE
ARG VCS_REF

# Validar que SERVICE_NAME esté definido
RUN if [ -z "$SERVICE_NAME" ]; then \
      echo "ERROR: SERVICE_NAME build arg is required"; \
      exit 1; \
    fi

# Instalar dependencias de build (si son necesarias)
RUN apk add --no-cache git ca-certificates tzdata

WORKDIR /build

# ============================================================
# OPTIMIZACIÓN: Copiar go.mod y go.sum PRIMERO
# Si solo cambia código (no deps), esta capa se cachea
# ============================================================
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# Copiar código fuente
COPY cmd ./cmd
COPY internal ./internal

# Build del binario
# - CGO_ENABLED=0: binario estático (no depende de libc)
# - -ldflags: inyectar versión y metadata
# - -trimpath: remover rutas absolutas (seguridad)
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -a \
    -installsuffix cgo \
    -ldflags="-w -s \
      -X main.Version=${VERSION} \
      -X main.BuildDate=${BUILD_DATE} \
      -X main.GitCommit=${VCS_REF}" \
    -trimpath \
    -o /build/app \
    ./cmd/${SERVICE_NAME}

# Verificar que el binario se creó
RUN ls -lh /build/app && file /build/app

# ------------------------------------------------------------
# Stage 2: Runtime (imagen final)
# ------------------------------------------------------------
FROM alpine:${ALPINE_VERSION}

# Build args para metadata
ARG SERVICE_NAME
ARG SERVICE_PORT=8000
ARG VERSION=dev
ARG VCS_REF
ARG BUILD_DATE

# Labels (OCI Image Spec)
LABEL org.opencontainers.image.title="${SERVICE_NAME}-service"
LABEL org.opencontainers.image.description="Cinemas ${SERVICE_NAME} microservice"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${VCS_REF}"
LABEL org.opencontainers.image.source="https://github.com/crizstian/cinemas-monorepo"
LABEL org.opencontainers.image.vendor="Cinemas"

# Instalar dependencias runtime mínimas
# - ca-certificates: Para HTTPS (MongoDB, APIs externas)
# - tzdata: Timezone data
# - wget: Para healthcheck
RUN apk add --no-cache ca-certificates tzdata wget && \
    update-ca-certificates

# Crear usuario no-root para seguridad
RUN addgroup -g 1000 appgroup && \
    adduser -D -u 1000 -G appgroup appuser

# Crear directorio de aplicación
WORKDIR /app

# Copiar binario desde builder
COPY --from=builder --chown=appuser:appgroup /build/app /app/service

# Cambiar a usuario no-root
USER appuser

# Exponer puerto del servicio
EXPOSE ${SERVICE_PORT}

# Variables de entorno por defecto
ENV SERVICE_PORT=${SERVICE_PORT}
ENV SERVICE_NAME=${SERVICE_NAME}

# Healthcheck
# Asume que el servicio expone GET / o /health
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${SERVICE_PORT}/ || exit 1

# Comando por defecto
ENTRYPOINT ["/app/service"]
