#!/bin/bash
# validate-monorepo.sh - Script maestro de validación del monorepo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATION_DIR="$SCRIPT_DIR/validation"

# Source common functions
source "$VALIDATION_DIR/common.sh"

# ============================================================
# Variables globales
# ============================================================
TOTAL_STAGES=7
STAGES_TO_RUN=(1 2 3 4 5 6 7)
CONTINUE_ON_ERROR=false
VERBOSE=false
OUTPUT_JSON=""
QUICK_MODE=false

STAGES_PASSED=0
STAGES_FAILED=0
TOTAL_TIME=0

# ============================================================
# Funciones
# ============================================================

show_help() {
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Monorepo Validation - Cinema Microservices
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Uso:
  $0 [opciones]

Opciones:
  --stages N,M,X        Ejecutar solo etapas específicas (ej: --stages 1,2,3)
  --quick               Modo rápido (solo etapas 1,2,3 sin Docker)
  --verbose             Modo verbose (mostrar más detalles)
  --continue-on-error   Continuar después de fallos
  --output-json FILE    Guardar resultados en JSON
  --help                Mostrar esta ayuda

Etapas disponibles:
  1. Validación de Estructura      (archivos y directorios)
  2. Validación de Go Workspace     (módulos y dependencias)
  3. Validación de Tests Unitarios  (go test)
  4. Validación de Builds Docker    (construcción de imágenes)
  5. Validación de MongoDB          (replica set)
  6. Validación de Servicios        (endpoints y health)
  7. Validación de Integración      (end-to-end tests)

Ejemplos:
  $0                                # Ejecutar todas las etapas
  $0 --quick                        # Solo etapas 1-3 (rápido, sin Docker)
  $0 --stages 1,2,3                 # Ejecutar etapas 1, 2 y 3
  $0 --stages 4,5,6,7               # Solo validaciones Docker
  $0 --continue-on-error            # No detenerse en errores
  $0 --output-json results.json    # Guardar resultados en JSON

Variables de ambiente:
  KEEP_TEST_IMAGES=true            # No eliminar imágenes de test
  KEEP_MONGODB_RUNNING=true        # No detener MongoDB después de validar
  KEEP_SERVICES_RUNNING=true       # No detener servicios después de validar
  RUN_RACE_DETECTOR=true           # Ejecutar race detector en tests
  RUN_LOAD_TEST=true               # Ejecutar test de carga en integración

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
}

parse_stages() {
    local stages_str=$1
    STAGES_TO_RUN=()

    IFS=',' read -ra STAGES <<< "$stages_str"
    for stage in "${STAGES[@]}"; do
        # Verificar que es un número válido
        if [[ "$stage" =~ ^[1-7]$ ]]; then
            STAGES_TO_RUN+=("$stage")
        else
            log_error "Etapa inválida: $stage (debe ser 1-7)"
            exit 1
        fi
    done
}

get_stage_name() {
    local stage=$1

    case $stage in
        1) echo "Validación de Estructura" ;;
        2) echo "Validación de Go Workspace" ;;
        3) echo "Validación de Tests Unitarios" ;;
        4) echo "Validación de Builds Docker" ;;
        5) echo "Validación de MongoDB" ;;
        6) echo "Validación de Servicios" ;;
        7) echo "Validación de Integración" ;;
        *) echo "Etapa Desconocida" ;;
    esac
}

get_stage_script() {
    local stage=$1
    echo "$VALIDATION_DIR/0${stage}-validate-*.sh"
}

run_stage() {
    local stage=$1
    local stage_name=$(get_stage_name "$stage")
    local stage_script=$(ls $VALIDATION_DIR/0${stage}-*.sh 2>/dev/null | head -1)

    if [[ ! -f "$stage_script" ]]; then
        log_error "Script de etapa $stage no encontrado: $stage_script"
        return 1
    fi

    # Hacer el script ejecutable
    chmod +x "$stage_script"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  [ETAPA $stage/$TOTAL_STAGES] $stage_name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local stage_start=$(date +%s)

    if [[ "$VERBOSE" == "true" ]]; then
        bash "$stage_script"
    else
        bash "$stage_script" 2>&1
    fi

    local exit_code=$?
    local stage_end=$(date +%s)
    local stage_duration=$((stage_end - stage_start))

    TOTAL_TIME=$((TOTAL_TIME + stage_duration))

    if [[ $exit_code -eq 0 ]]; then
        STAGES_PASSED=$((STAGES_PASSED + 1))
        return 0
    else
        STAGES_FAILED=$((STAGES_FAILED + 1))
        return 1
    fi
}

save_json_results() {
    local output_file=$1

    cat > "$output_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_stages": $TOTAL_STAGES,
  "stages_run": ${#STAGES_TO_RUN[@]},
  "stages_passed": $STAGES_PASSED,
  "stages_failed": $STAGES_FAILED,
  "total_time_seconds": $TOTAL_TIME,
  "success": $([ $STAGES_FAILED -eq 0 ] && echo "true" || echo "false")
}
EOF

    log_success "Resultados guardados en: $output_file"
}

show_summary() {
    local elapsed=$(format_duration $TOTAL_TIME)

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Resumen Final"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Etapas ejecutadas: ${#STAGES_TO_RUN[@]}"
    echo "  Etapas exitosas:   $STAGES_PASSED"
    echo "  Etapas fallidas:   $STAGES_FAILED"
    echo "  Tiempo total:      $elapsed"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ $STAGES_FAILED -eq 0 ]]; then
        echo ""
        log_success "✅ MONOREPO VALIDADO CORRECTAMENTE"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 0
    else
        echo ""
        log_error "❌ VALIDACIÓN FALLÓ"
        echo ""
        echo "  Revisa los logs arriba para ver los detalles de los errores."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
}

# ============================================================
# Parse argumentos
# ============================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --stages)
            parse_stages "$2"
            shift 2
            ;;
        --quick)
            QUICK_MODE=true
            STAGES_TO_RUN=(1 2 3)
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --continue-on-error)
            CONTINUE_ON_ERROR=true
            shift
            ;;
        --output-json)
            OUTPUT_JSON="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Opción desconocida: $1"
            echo "Use --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
done

# ============================================================
# Main
# ============================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Monorepo Validation - Cinema Microservices"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$QUICK_MODE" == "true" ]]; then
    log_info "Modo rápido: ejecutando solo etapas 1-3 (sin Docker)"
fi

log_step "Etapas a ejecutar: ${STAGES_TO_RUN[*]}"

if [[ "$CONTINUE_ON_ERROR" == "true" ]]; then
    log_warning "Modo continue-on-error: se ejecutarán todas las etapas incluso si algunas fallan"
fi

echo ""

# Iniciar timer global
GLOBAL_START=$(date +%s)

# Ejecutar cada etapa
for stage in "${STAGES_TO_RUN[@]}"; do
    if run_stage "$stage"; then
        log_success "Etapa $stage completada exitosamente"
    else
        log_error "Etapa $stage falló"

        if [[ "$CONTINUE_ON_ERROR" != "true" ]]; then
            log_error "Deteniendo validación (use --continue-on-error para continuar)"

            # Guardar resultados parciales si se especificó JSON
            if [[ -n "$OUTPUT_JSON" ]]; then
                save_json_results "$OUTPUT_JSON"
            fi

            show_summary
            exit 1
        fi
    fi
done

# Guardar resultados en JSON si se especificó
if [[ -n "$OUTPUT_JSON" ]]; then
    save_json_results "$OUTPUT_JSON"
fi

# Mostrar resumen final
if show_summary; then
    exit 0
else
    exit 1
fi
