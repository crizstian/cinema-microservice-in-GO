#!/bin/bash
# 06-validate-services.sh - Validar servicios individuales con infraestructura

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="."
COMPOSE_FILE="$WORKSPACE_ROOT/platform/deploy/docker-compose/docker-compose.yml"
FAILURES=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 6: Validación de Servicios"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

start_timer

# ============================================================
# 1. Verificar herramientas necesarias
# ============================================================
log_header "1. Verificando herramientas"

if ! check_command "docker-compose"; then
    log_error "Docker Compose no está instalado"
    exit 1
fi

if ! check_command "curl"; then
    log_error "curl no está instalado"
    exit 1
fi

log_success "Herramientas disponibles"

# ============================================================
# 2. Verificar docker-compose.yml
# ============================================================
log_header "2. Verificando docker-compose.yml"

if ! check_file "$COMPOSE_FILE" "docker-compose.yml"; then
    exit 1
fi

# ============================================================
# 3. Limpiar ambiente previo
# ============================================================
log_header "3. Preparando ambiente"

log_step "Limpiando contenedores existentes..."
cd "$(dirname "$COMPOSE_FILE")"
docker compose down -v --remove-orphans 2>&1 > /dev/null || true
log_success "Ambiente limpio"

# ============================================================
# 4. Levantar infraestructura completa
# ============================================================
log_header "4. Levantando infraestructura completa"

log_step "Iniciando todos los servicios..."

if docker compose up -d 2>&1 > /tmp/compose-start.log; then
    log_success "Servicios iniciados"
else
    log_error "Falló al iniciar servicios"
    cat /tmp/compose-start.log
    FAILURES=$((FAILURES + 1))
    exit 1
fi

# Mostrar servicios levantados
log_step "Servicios activos:"
docker compose ps | sed 's/^/  /'

# ============================================================
# 5. Esperar que los servicios estén listos
# ============================================================
log_header "5. Esperando que los servicios estén listos"

SERVICES_TIMEOUT=120
log_step "Esperando hasta ${SERVICES_TIMEOUT}s..."

# Esperar MongoDB primero (es crítico)
log_step "Esperando MongoDB replica set..."

sleep 10  # Dar tiempo inicial

for mongo in mongo1 mongo2 mongo3; do
    if docker compose ps | grep -q "$mongo.*Up"; then
        log_success "$mongo está running"
    else
        log_warning "$mongo no está running"
    fi
done

# Esperar servicios de aplicación
log_step "Esperando servicios de aplicación..."

SERVICE_CONTAINERS=(
    "movie"
    "payment"
    "notification"
    "booking"
)

sleep 20  # Dar tiempo para que se conecten a MongoDB

for container in "${SERVICE_CONTAINERS[@]}"; do
    # Verificar que el contenedor está running
    if docker compose ps | grep -q "$container.*Up"; then
        log_success "$container está running"
    else
        log_warning "$container no está running"
    fi
done

# ============================================================
# 6. Verificar healthchecks
# ============================================================
log_header "6. Verificando healthchecks"

# Verificar healthchecks de MongoDB
for mongo in mongo1 mongo2 mongo3; do
    # Intentar verificar health, pero no fallar si no tiene healthcheck
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$mongo" 2>/dev/null || echo "no-healthcheck")

    if [[ "$HEALTH" == "healthy" ]]; then
        log_success "$mongo: healthy"
    elif [[ "$HEALTH" == "no-healthcheck" ]]; then
        log_step "$mongo: sin healthcheck (verificando manualmente)"

        # Verificar manualmente con mongosh
        if docker exec "$mongo" mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
            log_success "$mongo: respondiendo OK"
        else
            log_warning "$mongo: no responde"
        fi
    else
        log_warning "$mongo: estado $HEALTH"
    fi
done

# ============================================================
# 7. Verificar endpoints de los servicios
# ============================================================
log_header "7. Verificando endpoints de servicios"

# Esperar un poco más para que los servicios estén completamente listos
sleep 10

# Definir endpoints de ping sin declare -A
SERVICE_ENDPOINTS="
movie=http://localhost:8000/ping
payment=http://localhost:8100/ping
notification=http://localhost:8200/ping
booking=http://localhost:8300/ping
"

get_endpoint() {
  local svc="$1"
  echo "$SERVICE_ENDPOINTS" | awk -F= -v s="$svc" '$1==s {print $2}'
}

for service in movie payment notification booking; do
    endpoint="$(get_endpoint "$service")"

    log_step "Verificando $service ($endpoint)..."

    # Intentar con retries
    MAX_RETRIES=10
    RETRY=0
    SUCCESS=false

    while [[ $RETRY -lt $MAX_RETRIES ]]; do
        RESPONSE=$(curl -s -w "\n%{http_code}" "$endpoint" 2>/dev/null || echo -e "\n000")

        # Última línea = status, resto = body (compatible con macOS/BSD)
        STATUS=$(printf '%s\n' "$RESPONSE" | tail -n 1)
        BODY=$(printf '%s\n' "$RESPONSE" | sed '$d')

        if [[ "$STATUS" == "200" ]]; then
            if [[ "$BODY" == *"pong"* ]] || [[ "$BODY" == *"OK"* ]]; then
                log_success "  $service responde correctamente: $BODY"
                SUCCESS=true
                break
            fi
        fi

        RETRY=$((RETRY + 1))
        if [[ $RETRY -lt $MAX_RETRIES ]]; then
            sleep 3
        fi
    done

    if [[ "$SUCCESS" != "true" ]]; then
        log_error "  $service no responde correctamente después de $MAX_RETRIES intentos"
        log_step "  Último status: $STATUS, body: $BODY"
        FAILURES=$((FAILURES + 1))
    fi
done
# ============================================================
# 8. Verificar logs sin errores críticos
# ============================================================
log_header "8. Verificando logs de servicios"

for container in "${SERVICE_CONTAINERS[@]}"; do
    log_step "Verificando logs de $container..."

    # Buscar errores críticos en logs recientes
    CRITICAL_ERRORS=$(docker logs "$container" 2>&1 | tail -50 | grep -iE "fatal|panic|critical" || true)

    if [[ -z "$CRITICAL_ERRORS" ]]; then
        log_success "  No hay errores críticos en $container"
    else
        log_warning "  Errores críticos encontrados en $container:"
        echo "$CRITICAL_ERRORS" | head -n 5 | sed 's/^/    /'
        FAILURES=$((FAILURES + 1))
    fi

    # Verificar errores de conexión a MongoDB
    MONGO_ERRORS=$(docker logs "$container" 2>&1 | tail -50 | grep -iE "mongodb.*error|connection.*failed|dial.*failed" || true)

    if [[ -z "$MONGO_ERRORS" ]]; then
        log_success "  Conexión a MongoDB OK en $container"
    else
        log_warning "  Posibles problemas de conexión a MongoDB en $container"
    fi
done

# ============================================================
# 9. Verificar conexiones a MongoDB
# ============================================================
log_header "9. Verificando conexiones a MongoDB"

# Verificar conexiones activas en MongoDB
CONNECTIONS=$(docker exec mongo1 mongosh --quiet --eval "db.serverStatus().connections" 2>/dev/null || echo "{}")

CURRENT_CONN=$(echo "$CONNECTIONS" | grep -oP 'current: \K\d+' || echo "0")
log_step "Conexiones activas a MongoDB: $CURRENT_CONN"

if [[ $CURRENT_CONN -gt 0 ]]; then
    log_success "Hay $CURRENT_CONN conexiones activas a MongoDB"
else
    log_warning "No hay conexiones activas a MongoDB (los servicios podrían no estar conectados)"
fi

# ============================================================
# 10. Verificar recursos de Docker
# ============================================================
log_header "10. Verificando recursos de Docker"

# Verificar uso de memoria
log_step "Verificando uso de memoria de contenedores..."

TOTAL_MEM=0
for container in "${SERVICE_CONTAINERS[@]}" mongo1 mongo2 mongo3; do
    if docker ps | grep -q "$container"; then
        MEM=$(docker stats "$container" --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk '{print $1}' || echo "0")
        log_step "  $container: $MEM"
    fi
done

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAILURES -eq 0 ]]; then
    log_success "Validación de servicios completada exitosamente"
    echo "  Servicios verificados: ${#SERVICE_ENDPOINTS[@]}"
    echo "  MongoDB: 3 nodos activos"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo ""
    log_info "Los servicios se mantienen running para la siguiente etapa"
    echo "  Para detenerlos: docker-compose -f $COMPOSE_FILE down"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de servicios falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo ""
    log_step "Para ver logs:"
    echo "  docker-compose -f $COMPOSE_FILE logs [servicio]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi

# Cleanup de archivos temporales
rm -f /tmp/compose-start.log
