#!/bin/bash
# 02-validate-workspace.sh - Validar Go workspace y dependencias

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="/workspace"
FAILURES=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 2: Validación de Go Workspace"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

start_timer

# Cambiar al directorio del workspace
cd "$WORKSPACE_ROOT"

# ============================================================
# 1. Verificar Go instalado
# ============================================================
log_header "1. Verificando Go"

if ! check_command "go"; then
    log_error "Go no está instalado"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}')
log_success "Go instalado: $GO_VERSION"

# ============================================================
# 2. Verificar y sincronizar workspace
# ============================================================
log_header "2. Sincronizando Go workspace"

if [[ ! -f "go.work" ]]; then
    log_error "go.work no encontrado"
    exit 1
fi

log_step "Ejecutando go work sync..."
if go work sync 2>&1; then
    log_success "go work sync completado"
else
    log_error "go work sync falló"
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 3. Verificar módulos de cada servicio
# ============================================================
log_header "3. Verificando módulos de servicios"

SERVICES=("booking" "movie" "payment" "notification")

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/services/$service"

    log_step "Verificando módulo de $service..."

    if [[ ! -d "$SERVICE_DIR" ]]; then
        log_error "Directorio no encontrado: services/$service"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    cd "$SERVICE_DIR"

    # Verificar go.mod
    if [[ ! -f "go.mod" ]]; then
        log_error "go.mod no encontrado en services/$service"
        FAILURES=$((FAILURES + 1))
        cd "$WORKSPACE_ROOT"
        continue
    fi

    # go mod verify
    log_step "  → go mod verify"
    if go mod verify 2>&1 > /dev/null; then
        log_success "  Módulo de $service verificado"
    else
        log_error "  go mod verify falló para $service"
        FAILURES=$((FAILURES + 1))
    fi

    # go mod download
    log_step "  → go mod download"
    if go mod download 2>&1 > /dev/null; then
        log_success "  Dependencias descargadas para $service"
    else
        log_error "  go mod download falló para $service"
        FAILURES=$((FAILURES + 1))
    fi

    # Verificar que compila
    log_step "  → verificando compilación"
    if go build -v ./... 2>&1 > /dev/null; then
        log_success "  $service compila correctamente"
    else
        log_error "  $service no compila"
        FAILURES=$((FAILURES + 1))
    fi

    cd "$WORKSPACE_ROOT"
done

# ============================================================
# 4. Verificar dependencias no rotas
# ============================================================
log_header "4. Verificando dependencias"

cd "$WORKSPACE_ROOT"

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/services/$service"
    cd "$SERVICE_DIR"

    log_step "Verificando dependencias de $service..."

    # go list -m all para verificar dependencias
    if go list -m all > /dev/null 2>&1; then
        log_success "Dependencias de $service están OK"
    else
        log_error "Dependencias rotas en $service"
        FAILURES=$((FAILURES + 1))
    fi

    cd "$WORKSPACE_ROOT"
done

# ============================================================
# 5. Verificar go.work.sum
# ============================================================
log_header "5. Verificando go.work.sum"

cd "$WORKSPACE_ROOT"

if [[ -f "go.work.sum" ]]; then
    log_success "go.work.sum existe"

    # Verificar que está actualizado
    go work sync
    if git diff --quiet go.work.sum 2>/dev/null; then
        log_success "go.work.sum está actualizado"
    else
        log_warning "go.work.sum tiene cambios no confirmados"
    fi
else
    log_info "go.work.sum no existe (se creará automáticamente)"
fi

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILURES -eq 0 ]]; then
    log_success "Validación de workspace completada exitosamente"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de workspace falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
