# Guía de Validación Post-Refactor

Esta guía contiene todos los comandos necesarios para validar que el refactor se completó exitosamente.

## 📋 Checklist de Validación

### 1. Verificar Estructura de Directorios

```bash
# Desde la raíz del repositorio
cd /workspace

# Verificar servicios
echo "=== Servicios ==="
ls -la services/
# Debe mostrar: booking, movie, payment, notification

# Verificar estructura interna de un servicio
echo "=== Estructura booking service ==="
tree -L 2 services/booking/
# Debe mostrar: cmd/, internal/, go.mod, Dockerfile, README.md

# Verificar platform
echo "=== Platform ==="
ls -la platform/
# Debe mostrar: docker/, deploy/, scripts/

# Verificar que NO existan directorios antiguos
echo "=== Verificando limpieza ==="
ls -la | grep -E "(booking-service|movie-service|payment-service|notification-service|base_docker_image|cinemas-db|webserver)" && echo "⚠️ ADVERTENCIA: Directorios antiguos aún existen" || echo "✅ Directorios antiguos eliminados"
```

### 2. Verificar go.work

```bash
# Ver contenido de go.work
cat go.work

# Debe contener:
# go 1.21
#
# use (
#     ./services/booking
#     ./services/movie
#     ./services/notification
#     ./services/payment
# )
```

### 3. Verificar go.mod de Servicios

```bash
# Verificar module paths actualizados
echo "=== Booking ==="
head -1 services/booking/go.mod
# Debe mostrar: module cinemas/services/booking

echo "=== Movie ==="
head -1 services/movie/go.mod
# Debe mostrar: module cinemas/services/movie

echo "=== Payment ==="
head -1 services/payment/go.mod
# Debe mostrar: module cinemas/services/payment

echo "=== Notification ==="
head -1 services/notification/go.mod
# Debe mostrar: module cinemas/services/notification
```

### 4. Sincronizar Workspace

```bash
# IMPORTANTE: Este comando puede requerir permisos de escritura en /go/pkg/mod
# Si falla, es un problema de entorno, no del refactor

go work sync

# Resultado esperado:
# - Sin errores de sintaxis en go.mod
# - Sin errores de módulos no encontrados
```

### 5. Verificar Imports en Archivos Go

```bash
# Verificar que no queden imports antiguos
echo "=== Buscando imports antiguos (no debería haber resultados) ==="
grep -r "cinemas-microservices" services/*/internal/ services/*/cmd/ 2>/dev/null || echo "✅ Sin imports antiguos"

# Verificar imports nuevos (debe encontrar)
echo "=== Verificando imports nuevos ==="
grep -r "cinemas/services" services/booking/cmd/ | head -3
# Debe mostrar imports como: "cinemas/services/booking/internal/api"
```

### 6. Build de Servicios

```bash
# Build booking service
echo "=== Building booking service ==="
cd services/booking
go build -o booking ./cmd/booking
ls -lh booking
# Debe mostrar el binario compilado

# Build movie service
echo "=== Building movie service ==="
cd ../movie
go build -o movie ./cmd/movie
ls -lh movie

# Build payment service
echo "=== Building payment service ==="
cd ../payment
go build -o payment ./cmd/payment
ls -lh payment

# Build notification service
echo "=== Building notification service ==="
cd ../notification
go build -o notification ./cmd/notification
ls -lh notification

cd /workspace
```

### 7. Ejecutar Tests

```bash
# Tests unitarios (no requieren MongoDB)
echo "=== Running unit tests ==="
go test ./services/booking/internal/models/... -v
go test ./services/booking/internal/service/... -v
go test ./services/movie/internal/models/... -v
go test ./services/payment/internal/models/... -v
go test ./services/notification/internal/models/... -v

# Tests de integración (requieren MongoDB corriendo)
# Primero, levantar MongoDB:
cd platform/deploy/docker-compose
docker compose up -d mongo1 mongo2 mongo3

# Esperar a que MongoDB esté listo (40s)
sleep 45

# Ejecutar tests de integración
cd /workspace
go test -tags=integration ./services/booking/internal/db/... -v
go test -tags=integration ./services/movie/internal/db/... -v
go test -tags=integration ./services/payment/internal/db/... -v
```

### 8. Verificar Dockerfiles

```bash
# Verificar que Dockerfiles usen nuevas rutas
echo "=== Verificando Dockerfiles ==="

echo "Booking:"
grep "COPY cmd" services/booking/Dockerfile
grep "go build" services/booking/Dockerfile
# Debe mostrar: COPY cmd ./cmd
# Debe mostrar: go build ... ./cmd/booking

echo "Movie:"
grep "COPY cmd" services/movie/Dockerfile
grep "go build" services/movie/Dockerfile

echo "Payment:"
grep "COPY cmd" services/payment/Dockerfile
grep "go build" services/payment/Dockerfile

echo "Notification:"
grep "COPY cmd" services/notification/Dockerfile
grep "go build" services/notification/Dockerfile
```

### 9. Validar Scripts de Build

```bash
# Verificar que build-image.sh existe en nueva ubicación
ls -la platform/scripts/build-image.sh
# Debe mostrar el archivo

# Verificar Makefile
cat Makefile | grep BUILD_SCRIPT
# Debe mostrar: BUILD_SCRIPT := ./platform/scripts/build-image.sh

# Verificar create-images.sh
cat create-images.sh | grep BUILD_SCRIPT
# Debe mostrar: BUILD_SCRIPT="$SCRIPT_DIR/platform/scripts/build-image.sh"
```

### 10. Test Docker Build (Opcional - requiere Docker)

```bash
# Build de imagen Docker para un servicio
# NOTA: Esto solo funciona si tienes Docker daemon disponible

# Ejemplo con booking service
cd /workspace
make build SERVICE=booking VERSION=v1.0.0-test

# O manualmente:
SERVICE=booking VERSION=v1.0.0-test CONTEXT=services/booking platform/scripts/build-image.sh

# Verificar imagen creada
docker images | grep booking
# Debe mostrar: crizstian/cinema/booking:v1.0.0-test
```

### 11. Verificar Documentación

```bash
# Verificar que todos los READMEs existen
echo "=== Verificando documentación ==="
ls -la README.md
ls -la services/booking/README.md
ls -la services/movie/README.md
ls -la services/payment/README.md
ls -la services/notification/README.md
ls -la docs/REFACTOR-ANALYSIS.md
ls -la docs/REFACTOR-SUMMARY.md
ls -la docs/DOCKER-BUILD.md
ls -la docs/MONGODB-VALIDATION.md

echo "✅ Todos los archivos de documentación existen"
```

## 🎯 Resumen de Validación

Al completar todos los pasos anteriores, deberías ver:

### ✅ Estructura
- [x] Directorio `services/` con 4 servicios
- [x] Directorio `platform/` con docker, deploy, scripts
- [x] Sin directorios antiguos (`*-service/` en raíz)

### ✅ Go Workspace
- [x] `go.work` apunta a `./services/*`
- [x] `go.mod` de cada servicio con module path `cinemas/services/<name>`
- [x] `go work sync` ejecuta sin errores

### ✅ Código
- [x] Imports actualizados a `cinemas/services/<service>/internal/...`
- [x] Sin imports antiguos `cinemas-microservices/...`
- [x] Servicios compilan sin errores

### ✅ Tests
- [x] Tests unitarios pasan
- [x] Tests de integración pasan (con MongoDB)

### ✅ Docker
- [x] Dockerfiles actualizados con `cmd/` e `internal/`
- [x] Scripts de build apuntan a `platform/scripts/`

### ✅ Documentación
- [x] README principal actualizado
- [x] READMEs de servicios creados
- [x] Documentación de refactor completa

## 🚨 Troubleshooting

### Error: "go work sync" falla con permisos

**Causa**: Permisos de escritura en `/go/pkg/mod`

**Solución**:
```bash
# Opción 1: Cambiar GOPATH temporalmente
export GOPATH=$HOME/go
go work sync

# Opción 2: Ejecutar con privilegios adecuados
sudo go work sync

# Opción 3: Verificar manualmente sin sync
# Los imports y module paths se pueden validar sin sync
```

### Error: "module not found" en imports

**Causa**: Imports no actualizados o `go.work` desactualizado

**Solución**:
```bash
# Verificar que no haya imports antiguos
grep -r "cinemas-microservices" services/

# Si encuentra resultados, actualizar manualmente:
find services/ -name "*.go" -exec sed -i 's|cinemas-microservices/|cinemas/services/|g' {} \;
find services/ -name "*.go" -exec sed -i 's|/src/|/internal/|g' {} \;
```

### Error: Build falla con "package not found"

**Causa**: Estructura de directorios incorrecta o imports mal formados

**Solución**:
```bash
# Verificar estructura
ls -la services/booking/cmd/booking/main.go
ls -la services/booking/internal/

# Verificar imports en main.go
head -20 services/booking/cmd/booking/main.go
# Debe importar desde "cinemas/services/booking/internal/..."
```

### Docker build falla

**Causa**: Dockerfile no actualizado o contexto incorrecto

**Solución**:
```bash
# Verificar Dockerfile
cat services/booking/Dockerfile | grep -E "(COPY|go build)"

# Build manual con contexto explícito
cd /workspace
docker build -t test:latest -f services/booking/Dockerfile services/booking/
```

## 📞 Soporte

Si encuentras problemas no documentados aquí:

1. Verifica la estructura de archivos contra `docs/REFACTOR-SUMMARY.md`
2. Revisa el análisis detallado en `docs/REFACTOR-ANALYSIS.md`
3. Consulta los logs de error completos
4. Documenta el issue para futuras referencias

---

**Última actualización**: 2026-01-23
**Versión del refactor**: 2.0
