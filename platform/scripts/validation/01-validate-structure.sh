#!/bin/bash
# 01-validate-structure.sh - Validar estructura del monorepo y archivos críticos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="/workspace"
FAILURES=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 1: Validación de Estructura"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

start_timer

# ============================================================
# 1. Verificar estructura de directorios principales
# ============================================================
log_header "1. Verificando estructura de directorios"

REQUIRED_DIRS=(
    "services"
    "services/booking"
    "services/movie"
    "services/payment"
    "services/notification"
    "platform"
    "platform/docker"
    "platform/deploy"
    "platform/scripts"
    "docs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if ! check_directory "$WORKSPACE_ROOT/$dir" "$dir/"; then
        FAILURES=$((FAILURES + 1))
    fi
done

# ============================================================
# 2. Verificar go.work y módulos
# ============================================================
log_header "2. Verificando Go workspace"

# Verificar go.work existe
if ! check_file "$WORKSPACE_ROOT/go.work" "go.work"; then
    FAILURES=$((FAILURES + 1))
else
    # Verificar que contiene los 4 servicios
    SERVICES=("booking" "movie" "payment" "notification")
    for service in "${SERVICES[@]}"; do
        if grep -q "./services/$service" "$WORKSPACE_ROOT/go.work"; then
            log_success "go.work contiene ./services/$service"
        else
            log_error "go.work no contiene ./services/$service"
            FAILURES=$((FAILURES + 1))
        fi
    done
fi

# ============================================================
# 3. Verificar estructura de cada servicio
# ============================================================
log_header "3. Verificando estructura de servicios"

SERVICES=("booking" "movie" "payment" "notification")

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/services/$service"

    log_step "Verificando $service..."

    # Verificar directorios requeridos
    if ! check_directory "$SERVICE_DIR/cmd" "services/$service/cmd/"; then
        FAILURES=$((FAILURES + 1))
    fi

    if ! check_directory "$SERVICE_DIR/internal" "services/$service/internal/"; then
        FAILURES=$((FAILURES + 1))
    fi

    # Verificar go.mod
    if ! check_file "$SERVICE_DIR/go.mod" "services/$service/go.mod"; then
        FAILURES=$((FAILURES + 1))
    fi
done

# ============================================================
# 4. Verificar estructura de platform
# ============================================================
log_header "4. Verificando estructura de platform"

PLATFORM_DIRS=(
    "platform/docker"
    "platform/deploy"
    "platform/scripts"
    "platform/deploy/docker-compose"
)

for dir in "${PLATFORM_DIRS[@]}"; do
    if ! check_directory "$WORKSPACE_ROOT/$dir" "$dir/"; then
        FAILURES=$((FAILURES + 1))
    fi
done

# ============================================================
# 5. Verificar Dockerfiles centralizados
# ============================================================
log_header "5. Verificando Dockerfiles centralizados"

# Verificar que los Dockerfiles centralizados existen
CENTRAL_DOCKERFILES=(
    "platform/docker/go-service/Dockerfile"
    "platform/docker/devcontainer/Dockerfile"
)

for dockerfile in "${CENTRAL_DOCKERFILES[@]}"; do
    if ! check_file "$WORKSPACE_ROOT/$dockerfile" "$dockerfile"; then
        FAILURES=$((FAILURES + 1))
    fi
done

# Verificar docker-compose.yml
if ! check_file "$WORKSPACE_ROOT/platform/deploy/docker-compose/docker-compose.yml" "docker-compose.yml"; then
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 6. Verificar que NO existen archivos duplicados
# ============================================================
log_header "6. Verificando que no hay archivos duplicados"

# Verificar que NO existen Dockerfiles en servicios individuales
SERVICES=("booking" "movie" "payment" "notification")

for service in "${SERVICES[@]}"; do
    if check_file_not_exists "$WORKSPACE_ROOT/services/$service/Dockerfile" "services/$service/Dockerfile"; then
        log_success "No hay Dockerfile duplicado en services/$service/"
    else
        FAILURES=$((FAILURES + 1))
    fi
done

# Verificar que NO existen scripts de build antiguos
OLD_SCRIPTS=(
    "services/booking/create-image.sh"
    "services/movie/create-image.sh"
    "services/payment/create-image.sh"
    "services/notification/create-image.sh"
)

for script in "${OLD_SCRIPTS[@]}"; do
    if check_file_not_exists "$WORKSPACE_ROOT/$script" "$script"; then
        log_success "No hay script duplicado: $script"
    else
        log_warning "Script antiguo encontrado: $script (debería estar eliminado)"
    fi
done

# ============================================================
# 7. Verificar archivos críticos
# ============================================================
log_header "7. Verificando archivos críticos"

CRITICAL_FILES=(
    "README.md"
    "Makefile"
    "platform/scripts/build-go-service.sh"
)

for file in "${CRITICAL_FILES[@]}"; do
    if ! check_file "$WORKSPACE_ROOT/$file" "$file"; then
        FAILURES=$((FAILURES + 1))
    fi
done

# ============================================================
# 8. Verificar permisos de scripts
# ============================================================
log_header "8. Verificando permisos de scripts"

EXECUTABLE_SCRIPTS=(
    "platform/scripts/build-go-service.sh"
    "platform/scripts/build-image.sh"
)

for script in "${EXECUTABLE_SCRIPTS[@]}"; do
    if [[ -f "$WORKSPACE_ROOT/$script" ]]; then
        if [[ -x "$WORKSPACE_ROOT/$script" ]]; then
            log_success "$script es ejecutable"
        else
            log_warning "$script no es ejecutable"
            chmod +x "$WORKSPACE_ROOT/$script"
            log_success "Permisos corregidos para $script"
        fi
    fi
done

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILURES -eq 0 ]]; then
    log_success "Validación de estructura completada exitosamente"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de estructura falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
