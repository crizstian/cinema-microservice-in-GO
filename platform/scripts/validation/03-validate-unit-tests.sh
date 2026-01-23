#!/bin/bash
# 03-validate-unit-tests.sh - Ejecutar tests unitarios de todos los servicios

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="/workspace"
FAILURES=0
TOTAL_TESTS=0
PASSED_TESTS=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 3: Validación de Tests Unitarios"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

start_timer

# ============================================================
# 1. Verificar que Go test está disponible
# ============================================================
log_header "1. Verificando herramientas de testing"

if ! check_command "go"; then
    log_error "Go no está instalado"
    exit 1
fi

log_success "Go test disponible"

# ============================================================
# 2. Ejecutar tests de cada servicio
# ============================================================
log_header "2. Ejecutando tests unitarios"

SERVICES=("booking" "movie" "payment" "notification")

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/services/$service"

    log_step "Testing $service..."

    if [[ ! -d "$SERVICE_DIR" ]]; then
        log_error "Directorio no encontrado: services/$service"
        FAILURES=$((FAILURES + 1))
        continue
    fi

    cd "$SERVICE_DIR"

    # Buscar tests (excluyendo integration tests)
    TEST_FILES=$(find ./internal -name "*_test.go" 2>/dev/null | wc -l)

    if [[ $TEST_FILES -eq 0 ]]; then
        log_warning "  No se encontraron tests en $service"
        cd "$WORKSPACE_ROOT"
        continue
    fi

    log_step "  → Encontrados $TEST_FILES archivos de test"

    # Ejecutar tests (excluir integration tests)
    log_step "  → Ejecutando tests..."

    # Crear directorio temporal para coverage
    COVERAGE_FILE="/tmp/coverage-$service.out"

    if go test -v -coverprofile="$COVERAGE_FILE" ./internal/... 2>&1 | tee /tmp/test-output-$service.log; then
        # Contar tests pasados
        test_count=$(grep -c "^=== RUN" /tmp/test-output-$service.log || echo "0")
        pass_count=$(grep -c "^--- PASS" /tmp/test-output-$service.log || echo "0")

        TOTAL_TESTS=$((TOTAL_TESTS + test_count))
        PASSED_TESTS=$((PASSED_TESTS + pass_count))

        log_success "  Tests de $service pasados ($pass_count/$test_count)"

        # Calcular cobertura si existe el archivo
        if [[ -f "$COVERAGE_FILE" ]]; then
            coverage=$(go tool cover -func="$COVERAGE_FILE" 2>/dev/null | tail -1 | awk '{print $3}' || echo "N/A")
            log_step "  → Cobertura: $coverage"
        fi
    else
        log_error "  Tests de $service fallaron"
        FAILURES=$((FAILURES + 1))

        # Mostrar últimas líneas del error
        log_step "  → Últimos errores:"
        tail -n 10 /tmp/test-output-$service.log | sed 's/^/    /'
    fi

    cd "$WORKSPACE_ROOT"

    # Cleanup
    rm -f /tmp/test-output-$service.log
    rm -f "$COVERAGE_FILE"
done

# ============================================================
# 3. Verificar que no hay tests ignorados (skip)
# ============================================================
log_header "3. Verificando tests ignorados"

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/services/$service"
    cd "$SERVICE_DIR"

    # Buscar t.Skip en tests
    SKIPPED=$(grep -r "t.Skip\|t.SkipNow" ./internal/*_test.go 2>/dev/null | wc -l || echo "0")

    if [[ $SKIPPED -gt 0 ]]; then
        log_warning "$service tiene $SKIPPED tests ignorados"
    else
        log_success "$service no tiene tests ignorados"
    fi

    cd "$WORKSPACE_ROOT"
done

# ============================================================
# 4. Verificar race conditions (opcional, puede ser lento)
# ============================================================
if [[ "${RUN_RACE_DETECTOR:-false}" == "true" ]]; then
    log_header "4. Verificando race conditions"

    for service in "${SERVICES[@]}"; do
        SERVICE_DIR="$WORKSPACE_ROOT/services/$service"
        cd "$SERVICE_DIR"

        log_step "Verificando race conditions en $service..."

        if go test -race ./internal/... 2>&1 > /dev/null; then
            log_success "$service pasa race detector"
        else
            log_warning "$service tiene posibles race conditions"
        fi

        cd "$WORKSPACE_ROOT"
    done
fi

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Resumen de Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Tests totales: $TOTAL_TESTS"
echo "  Tests pasados: $PASSED_TESTS"
echo "  Servicios testeados: ${#SERVICES[@]}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAILURES -eq 0 ]] && [[ $TOTAL_TESTS -gt 0 ]]; then
    log_success "Validación de tests completada exitosamente"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
elif [[ $TOTAL_TESTS -eq 0 ]]; then
    log_warning "No se encontraron tests para ejecutar"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de tests falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
