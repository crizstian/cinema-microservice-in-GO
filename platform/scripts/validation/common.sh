#!/bin/bash
# common.sh - Funciones comunes para scripts de validación

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Símbolos
CHECK="✅"
CROSS="❌"
WARNING="⚠️"
INFO="ℹ️"
CLOCK="⏱"

# Logging functions
log_info() {
    echo -e "${BLUE}${INFO} ${NC}$1"
}

log_success() {
    echo -e "${GREEN}${CHECK} ${NC}$1"
}

log_error() {
    echo -e "${RED}${CROSS} ${NC}$1" >&2
}

log_warning() {
    echo -e "${YELLOW}${WARNING} ${NC}$1"
}

log_header() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
}

log_step() {
    echo -e "  ${BLUE}→${NC} $1"
}

# Verificar que un comando existe
check_command() {
    local cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Comando requerido no encontrado: $cmd"
        return 1
    fi
    return 0
}

# Verificar que un archivo existe
check_file() {
    local file=$1
    local description=${2:-"$file"}
    if [[ ! -f "$file" ]]; then
        log_error "Archivo no encontrado: $description"
        return 1
    fi
    log_success "$description"
    return 0
}

# Verificar que un directorio existe
check_directory() {
    local dir=$1
    local description=${2:-"$dir"}
    if [[ ! -d "$dir" ]]; then
        log_error "Directorio no encontrado: $description"
        return 1
    fi
    log_success "$description"
    return 0
}

# Verificar que un archivo NO existe (para detectar duplicados)
check_file_not_exists() {
    local file=$1
    local description=${2:-"$file"}
    if [[ -f "$file" ]]; then
        log_error "Archivo duplicado encontrado: $description"
        return 1
    fi
    return 0
}

# Esperar a que un contenedor Docker esté healthy
wait_for_healthy() {
    local container=$1
    local timeout=${2:-60}
    local elapsed=0

    log_step "Esperando que $container esté healthy..."

    while [[ $elapsed -lt $timeout ]]; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

        if [[ "$health" == "healthy" ]]; then
            log_success "$container está healthy"
            return 0
        fi

        sleep 2
        elapsed=$((elapsed + 2))

        # Mostrar progreso cada 10 segundos
        if [[ $((elapsed % 10)) -eq 0 ]]; then
            log_step "Esperando... ${elapsed}s/${timeout}s (estado: $health)"
        fi
    done

    log_error "$container no alcanzó estado healthy después de ${timeout}s"
    return 1
}

# Verificar endpoint HTTP
check_http_endpoint() {
    local url=$1
    local expected_status=${2:-200}
    local expected_body=${3:-""}
    local max_retries=${4:-5}
    local retry=0

    while [[ $retry -lt $max_retries ]]; do
        # Hacer request y capturar status code y body
        local response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
        local body=$(echo "$response" | head -n -1)
        local status=$(echo "$response" | tail -n 1)

        if [[ "$status" == "$expected_status" ]]; then
            if [[ -z "$expected_body" ]] || [[ "$body" == *"$expected_body"* ]]; then
                log_success "Endpoint $url responde correctamente"
                return 0
            fi
        fi

        retry=$((retry + 1))
        if [[ $retry -lt $max_retries ]]; then
            sleep 2
        fi
    done

    log_error "Endpoint $url no responde correctamente (esperado: $expected_status, obtenido: $status)"
    return 1
}

# Limpiar contenedores Docker de prueba
cleanup_docker() {
    local compose_file=${1:-"/workspace/platform/deploy/docker-compose/docker-compose.yml"}

    if [[ -f "$compose_file" ]]; then
        log_step "Limpiando contenedores Docker..."
        docker-compose -f "$compose_file" down -v --remove-orphans 2>/dev/null || true
        log_success "Contenedores limpiados"
    fi
}

# Ejecutar comando con timeout
run_with_timeout() {
    local timeout=$1
    shift
    local cmd="$@"

    timeout "$timeout" bash -c "$cmd"
    return $?
}

# Contar archivos que coinciden con patrón
count_files() {
    local pattern=$1
    find . -path "$pattern" 2>/dev/null | wc -l
}

# Obtener tamaño de imagen Docker en MB
get_image_size_mb() {
    local image=$1
    local size_bytes=$(docker image inspect "$image" --format='{{.Size}}' 2>/dev/null || echo "0")
    echo $((size_bytes / 1024 / 1024))
}

# Verificar logs de Docker para errores
check_docker_logs() {
    local container=$1
    local error_pattern=${2:-"ERROR|FATAL|panic"}

    local errors=$(docker logs "$container" 2>&1 | grep -iE "$error_pattern" || true)

    if [[ -n "$errors" ]]; then
        log_warning "Errores encontrados en logs de $container:"
        echo "$errors" | head -n 5
        return 1
    fi

    log_success "No hay errores críticos en logs de $container"
    return 0
}

# Verificar que Go workspace está sincronizado
check_go_workspace() {
    local workspace_file=${1:-"/workspace/go.work"}

    if [[ ! -f "$workspace_file" ]]; then
        log_error "go.work no encontrado"
        return 1
    fi

    # Verificar que go work sync funciona
    if ! go work sync 2>&1 | grep -q ""; then
        log_error "go work sync falló"
        return 1
    fi

    log_success "Go workspace sincronizado"
    return 0
}

# Formatear duración en segundos a formato legible
format_duration() {
    local seconds=$1

    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    else
        local minutes=$((seconds / 60))
        local secs=$((seconds % 60))
        echo "${minutes}m ${secs}s"
    fi
}

# Iniciar timer
start_timer() {
    TIMER_START=$(date +%s)
}

# Obtener tiempo transcurrido
get_elapsed() {
    local end=$(date +%s)
    local elapsed=$((end - TIMER_START))
    format_duration $elapsed
}

# Exportar funciones para uso en subshells
export -f log_info log_success log_error log_warning log_header log_step
export -f check_command check_file check_directory check_file_not_exists
export -f wait_for_healthy check_http_endpoint cleanup_docker
export -f run_with_timeout count_files get_image_size_mb check_docker_logs
export -f check_go_workspace format_duration start_timer get_elapsed
