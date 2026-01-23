# Análisis de Dockerfiles - Monorepo Cinemas

## 📊 Resumen Ejecutivo

**Hallazgos principales**:
- ❌ **4 Dockerfiles duplicados** en servicios (99.9% idénticos)
- ⚠️ **Falta optimización de capas** y cache
- ⚠️ **Imagen base custom innecesaria** para servicios simples
- ⚠️ **No hay .devcontainer** para desarrollo local
- ✅ Multi-stage builds implementados correctamente
- ⚠️ Falta user no-root y health checks

---

## 🔍 Análisis por Tipo

### 1. Dockerfiles de Servicios Go (4 archivos)

**Ubicación actual**:
```
services/booking/Dockerfile
services/movie/Dockerfile
services/payment/Dockerfile
services/notification/Dockerfile
```

**Contenido (idéntico en todos)**:
```dockerfile
FROM golang:1.21-alpine

WORKDIR /build

COPY go.mod go.sum ./
COPY cmd ./cmd
COPY internal ./internal

RUN go mod download && \
    CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main ./cmd/<SERVICE>

FROM crizstian/cinemas-base-image:alpine-v0.2

WORKDIR /tmp

ENV APP_NAME <service>-service

COPY --from=0 /build/main .

CMD ["/tmp/main"]
```

#### ❌ Problemas Identificados

| Problema | Impacto | Prioridad |
|----------|---------|-----------|
| **Duplicación** | 4 archivos idénticos = mantenimiento 4x | 🔴 Alta |
| **Sin argumentos** | No parametrizable, hardcoded | 🔴 Alta |
| **Sin caching óptimo** | go mod download se ejecuta aunque no cambien deps | 🟡 Media |
| **Base image custom** | Dependencia de imagen externa no versionada | 🟡 Media |
| **Sin user no-root** | Contenedor corre como root (riesgo seguridad) | 🟡 Media |
| **Sin healthcheck** | No validación de salud del servicio | 🟢 Baja |
| **WORKDIR /tmp** | No es best practice, mejor /app | 🟢 Baja |

#### ✅ Aspectos Correctos

- Multi-stage build (reduce tamaño final)
- CGO_ENABLED=0 (binario estático)
- GOOS=linux (target correcto)
- Alpine como base (imagen ligera)

---

### 2. Dockerfile Base Image

**Ubicación**: `platform/docker/base/Dockerfile`

```dockerfile
FROM alpine:latest
RUN apk --no-cache add ca-certificates curl unzip jq bash
COPY ct.hcl /tmp/ct.hcl
COPY envconsul.hcl.tmpl /tmp/envconsul.hcl.tmpl
COPY *.sh /tmp/
COPY ca.crt.pem /tmp/
RUN chmod +x /tmp/*.sh && \
  bash /tmp/install-tools.sh && \
  chmod 400 /tmp/ca.crt.pem
ENV CONSUL_SCHEME http
ENV CONSUL_PORT 8500
ENTRYPOINT [ "bash", "/tmp/pre-start.sh" ]
```

#### Análisis

**Propósito**: Imagen base con integración Consul/Vault para servicios

**Problemas**:
- ⚠️ Usado solo en servicios Go, pero agrega complejidad innecesaria
- ⚠️ COPY *.sh puede copiar archivos no deseados
- ⚠️ No tiene versión (`:latest`)
- ✅ Usa ENTRYPOINT para pre-start scripts

**Recomendación**:
- Mantener SOLO si realmente se usa Consul/Vault en producción
- Si no, simplificar servicios Go a usar Alpine directo

---

### 3. Dockerfile MongoDB

**Ubicación**: `platform/docker/mongodb/Dockerfile`

```dockerfile
FROM mongo
RUN set -eux; \
    apt-get update; \
    apt-get install -y curl software-properties-common wget unzip
RUN mkdir /data/keyfile /data/admin /var/tmp/start
COPY files/admin.js.ctmpl /data/admin/
COPY files/replica.js.ctmpl /data/admin/
# ... más archivos
RUN chown -R mongodb:mongodb /data && \
    chmod -R +x /tmp && \
    /tmp/installhashi.sh && \
    chmod 400 /tmp/ca.crt.pem
ENV CONSUL_SCHEME http
ENV APP_NAME mongo-db
ENTRYPOINT [ "/tmp/pre-start.sh" ]
```

#### Análisis

**Propósito**: MongoDB con replica set + integración Consul/Vault

**Problemas**:
- ⚠️ FROM mongo (sin versión) - debería ser `mongo:7.0` o similar
- ⚠️ Muchas dependencias de Hashicorp (¿realmente necesarias?)
- ✅ Permisos correctos (chown mongodb)
- ✅ Scripts de inicialización organizados

**Recomendación**:
- Usar versión específica de MongoDB
- Evaluar si Consul/Vault son necesarios o se puede simplificar

---

### 4. Dockerfile Webserver (Nginx)

**Ubicación**: `platform/docker/webserver/Dockerfile`

```dockerfile
FROM nginx:alpine
COPY startup /tmp/
COPY files/bin /tmp/
COPY files/template /tmp/
COPY files/certs/*.* /etc/nginx/conf.d/certs/
RUN apk update && apk --no-cache add linux-headers curl unzip openssl ca-certificates wget libgcc nfs-utils jq tar libstdc++ bash
RUN chmod -R +x /tmp && /tmp/installhashi.sh
RUN mkdir -p /usr/local/nginx/ssl && \
  openssl dhparam -out /usr/local/nginx/ssl/dhparam.pem 2048
ENV CONSUL_SCHEME http
ENV ENABLE_SECRETS false
ENTRYPOINT [ "bash", "/tmp/pre-start.sh" ]
```

#### Análisis

**Propósito**: Nginx como reverse proxy con integración Consul/Vault

**Problemas**:
- ⚠️ Muchas dependencias instaladas (¿todas necesarias?)
- ⚠️ No se ve configuración de nginx (`nginx.conf`)
- ✅ Genera dhparam para TLS (seguridad)
- ✅ Alpine base (ligero)

**Recomendación**:
- Simplificar dependencias
- Agregar nginx.conf explícito
- Usar versión específica: `nginx:1.25-alpine`

---

## 🎯 Propuesta de Mejora

### Opción 1: Dockerfile Genérico Parametrizado (RECOMENDADO)

**Crear**: `platform/docker/go-service.Dockerfile`

Ventajas:
- ✅ Un solo archivo para mantener
- ✅ Parametrizable con build args
- ✅ Aplicar mejoras una vez, beneficia a todos
- ✅ Mantiene flexibilidad

**Uso**:
```bash
docker build -f platform/docker/go-service.Dockerfile \
  --build-arg SERVICE_NAME=booking \
  -t booking:v1.0.0 \
  services/booking/
```

---

### Opción 2: Mantener Dockerfiles por Servicio (NO RECOMENDADO)

Razones:
- ❌ Duplicación de código
- ❌ Cambios requieren actualizar 4 archivos
- ❌ Riesgo de inconsistencias

---

## 📋 Mejores Prácticas a Aplicar

### 1. Optimización de Capas

**Antes**:
```dockerfile
COPY go.mod go.sum ./
COPY cmd ./cmd
COPY internal ./internal
RUN go mod download && go build ...
```

**Después**:
```dockerfile
# Primero copiar solo dependencias
COPY go.mod go.sum ./
RUN go mod download

# Luego copiar código (cambia más frecuentemente)
COPY cmd ./cmd
COPY internal ./internal
RUN go build ...
```

**Beneficio**: Cache de `go mod download` se preserva aunque cambies código.

---

### 2. Usuario No-Root

**Antes**:
```dockerfile
CMD ["/tmp/main"]  # Corre como root
```

**Después**:
```dockerfile
RUN adduser -D -u 1000 appuser
USER appuser
CMD ["/app/main"]
```

**Beneficio**: Mejor seguridad, cumple con políticas empresariales.

---

### 3. Healthcheck

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:${SERVICE_PORT}/ || exit 1
```

**Beneficio**: Kubernetes/Docker pueden detectar servicios unhealthy.

---

### 4. Labels (Metadata)

```dockerfile
LABEL org.opencontainers.image.title="${SERVICE_NAME}"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.source="https://github.com/crizstian/cinemas-monorepo"
```

**Beneficio**: Trazabilidad de imágenes.

---

### 5. Build Args Parametrizables

```dockerfile
ARG SERVICE_NAME
ARG SERVICE_PORT=8000
ARG GO_VERSION=1.21
```

**Beneficio**: Flexibilidad sin duplicar Dockerfiles.

---

## 🏗️ Estructura Propuesta

```
platform/docker/
├── go-service.Dockerfile      # ✨ NUEVO: Dockerfile genérico para servicios Go
├── .dockerignore              # ✨ NUEVO: Ignorar archivos innecesarios
├── base/
│   └── Dockerfile             # (mantener si se usa Consul/Vault)
├── mongodb/
│   └── Dockerfile             # (mejorar versiones)
└── webserver/
    └── Dockerfile             # (simplificar deps)
```

Servicios:
```
services/booking/
├── cmd/
├── internal/
├── go.mod
└── README.md                  # ❌ ELIMINAR Dockerfile local
```

---

## 🆚 Comparación de Opciones

| Aspecto | Dockerfiles por Servicio | Dockerfile Genérico |
|---------|--------------------------|---------------------|
| **Mantenimiento** | 4 archivos a actualizar | 1 archivo centralizado ✅ |
| **Consistencia** | Riesgo de divergencia | Garantizada ✅ |
| **Flexibilidad** | Alta (pero duplicada) | Alta (parametrizada) ✅ |
| **Build time** | Similar | Similar |
| **Complejidad** | Baja individual | Media (build args) |
| **Best practices** | Difícil aplicar uniformemente | Fácil ✅ |

**Ganador**: Dockerfile Genérico ✅

---

## 🎯 Plan de Implementación

### Fase 1: Crear Dockerfile Genérico
- [x] Analizar Dockerfiles existentes
- [ ] Crear `platform/docker/go-service.Dockerfile`
- [ ] Crear `.dockerignore`
- [ ] Aplicar mejores prácticas:
  - [ ] Multi-stage build optimizado
  - [ ] User no-root
  - [ ] Healthcheck
  - [ ] Build args
  - [ ] Labels

### Fase 2: Actualizar Build Scripts
- [ ] Actualizar `platform/scripts/build-image.sh`
- [ ] Actualizar `Makefile`
- [ ] Probar builds

### Fase 3: Cleanup
- [ ] Eliminar Dockerfiles individuales de servicios
- [ ] Actualizar documentación

### Fase 4: Mejorar Infraestructura
- [ ] Versiones específicas en mongodb/webserver
- [ ] Simplificar dependencias
- [ ] Crear .devcontainer

---

## 📚 Referencias

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Dockerfile reference](https://docs.docker.com/engine/reference/builder/)
- [Security scanning](https://docs.docker.com/scout/)

---

**Próximo paso**: Implementar Dockerfile genérico con mejores prácticas.
