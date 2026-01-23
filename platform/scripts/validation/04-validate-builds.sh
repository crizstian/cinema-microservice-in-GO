#!/bin/bash
# 04-validate-builds.sh - Validar construcción de imágenes Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="/workspace"
FAILURES=0
BUILD_SCRIPT="$WORKSPACE_ROOT/platform/scripts/build-go-service.sh"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 4: Validación de Builds Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

start_timer

# ============================================================
# 1. Verificar herramientas necesarias
# ============================================================
log_header "1. Verificando herramientas"

if ! check_command "docker"; then
    log_error "Docker no está instalado"
    exit 1
fi

log_success "Docker disponible: $(docker --version | cut -d' ' -f3)"

# ============================================================
# 2. Verificar script de build existe
# ============================================================
log_header "2. Verificando script de build"

if ! check_file "$BUILD_SCRIPT" "build-go-service.sh"; then
    log_error "Script de build no encontrado"
    exit 1
fi

# Verificar que es ejecutable
if [[ ! -x "$BUILD_SCRIPT" ]]; then
    log_warning "Script de build no es ejecutable, corrigiendo..."
    chmod +x "$BUILD_SCRIPT"
fi

log_success "Script de build está listo"

# ============================================================
# 3. Verificar Dockerfile genérico
# ============================================================
log_header "3. Verificando Dockerfile genérico"

DOCKERFILE="$WORKSPACE_ROOT/platform/docker/go-service/Dockerfile"

if ! check_file "$DOCKERFILE" "platform/docker/go-service/Dockerfile"; then
    log_error "Dockerfile genérico no encontrado"
    exit 1
fi

# Verificar multi-stage build
if grep -q "FROM.*AS builder" "$DOCKERFILE"; then
    log_success "Dockerfile usa multi-stage build"
else
    log_warning "Dockerfile no parece usar multi-stage build"
fi

# ============================================================
# 4. Build de cada servicio
# ============================================================
log_header "4. Construyendo imágenes de servicios"

SERVICES=("booking" "movie" "payment" "notification")
VERSION="test-$(date +%Y%m%d-%H%M%S)"

log_step "Versión de test: $VERSION"

for service in "${SERVICES[@]}"; do
    log_step "Construyendo $service..."

    # Verificar que el servicio existe
    if [[ ! -d "$WORKSPACE_ROOT/services/$service" ]]; then
        log_error "Servicio no encontrado: $service"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    # Construir imagen
    IMAGE_NAME="cinema/$service:$VERSION"

    log_step "  → Ejecutando build..."

    if SERVICE="$service" VERSION="$VERSION" ORGANIZATION="cinema" bash "$BUILD_SCRIPT" > /tmp/build-$service.log 2>&1; then
        log_success "  Build de $service exitoso"

        # Verificar que la imagen existe
        if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
            log_success "  Imagen creada: $IMAGE_NAME"

            # Verificar tamaño de imagen
            SIZE_MB=$(get_image_size_mb "$IMAGE_NAME")
            log_step "  → Tamaño: ${SIZE_MB}MB"

            if [[ $SIZE_MB -gt 50 ]]; then
                log_warning "  Imagen más grande de lo esperado (>50MB)"
            elif [[ $SIZE_MB -lt 5 ]]; then
                log_warning "  Imagen muy pequeña (<5MB), verificar contenido"
            else
                log_success "  Tamaño de imagen apropiado"
            fi

            # Verificar metadata/labels OCI
            log_step "  → Verificando metadata OCI..."

            # Obtener labels
            LABELS=$(docker image inspect "$IMAGE_NAME" --format='{{json .Config.Labels}}' 2>/dev/null || echo "{}")

            if echo "$LABELS" | grep -q "org.opencontainers"; then
                log_success "  Labels OCI presentes"
            else
                log_warning "  Labels OCI no encontrados"
            fi

            # Verificar entrypoint
            ENTRYPOINT=$(docker image inspect "$IMAGE_NAME" --format='{{.Config.Entrypoint}}' 2>/dev/null || echo "")

            if [[ -n "$ENTRYPOINT" ]] && [[ "$ENTRYPOINT" != "[]" ]]; then
                log_success "  Entrypoint configurado"
            else
                log_warning "  Entrypoint no configurado"
            fi

        else
            log_error "  Imagen no encontrada después del build"
            FAILURES=$((FAILURES + 1))
        fi

    else
        log_error "  Build de $service falló"
        FAILURES=$((FAILURES + 1))

        # Mostrar últimas líneas del log
        log_step "  → Últimos errores del build:"
        tail -n 20 /tmp/build-$service.log | sed 's/^/    /'
    fi

    # Cleanup del log
    rm -f /tmp/build-$service.log

done

# ============================================================
# 5. Verificar que las imágenes pueden ejecutarse
# ============================================================
log_header "5. Verificando que las imágenes pueden ejecutarse"

for service in "${SERVICES[@]}"; do
    IMAGE_NAME="cinema/$service:$VERSION"

    if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
        log_step "Verificando ejecución de $service..."

        # Intentar ejecutar con --help o version (si existe)
        # Usar timeout para no quedar colgado
        if timeout 5s docker run --rm "$IMAGE_NAME" --version > /dev/null 2>&1 || \
           timeout 5s docker run --rm "$IMAGE_NAME" --help > /dev/null 2>&1 || \
           timeout 5s docker run --rm "$IMAGE_NAME" version > /dev/null 2>&1; then
            log_success "$service puede ejecutarse"
        else
            # No es crítico si no responde a estos comandos
            log_step "$service no responde a comandos de ayuda (OK si requiere config)"
        fi
    fi
done

# ============================================================
# 6. Cleanup de imágenes de test
# ============================================================
log_header "6. Limpieza de imágenes de test"

if [[ "${KEEP_TEST_IMAGES:-false}" != "true" ]]; then
    log_step "Eliminando imágenes de test..."

    for service in "${SERVICES[@]}"; do
        IMAGE_NAME="cinema/$service:$VERSION"

        if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
            docker rmi "$IMAGE_NAME" > /dev/null 2>&1 || true
            log_step "  → Eliminada: $IMAGE_NAME"
        fi
    done

    log_success "Imágenes de test eliminadas"
else
    log_info "Manteniendo imágenes de test (KEEP_TEST_IMAGES=true)"
fi

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILURES -eq 0 ]]; then
    log_success "Validación de builds completada exitosamente"
    echo "  Servicios construidos: ${#SERVICES[@]}"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de builds falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
