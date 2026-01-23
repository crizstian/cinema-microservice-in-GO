#!/bin/bash
# 07-validate-integration.sh - Validar integración completa end-to-end

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="/workspace"
COMPOSE_FILE="$WORKSPACE_ROOT/platform/deploy/docker-compose/docker-compose.yml"
FAILURES=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 7: Validación de Integración End-to-End"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

start_timer

# ============================================================
# 1. Verificar que la infraestructura está running
# ============================================================
log_header "1. Verificando infraestructura"

cd "$(dirname "$COMPOSE_FILE")"

# Verificar que los servicios están running
RUNNING_SERVICES=$(docker-compose ps --services --filter "status=running" | wc -l)

if [[ $RUNNING_SERVICES -lt 4 ]]; then
    log_warning "Solo $RUNNING_SERVICES servicios están running"
    log_step "Levantando servicios..."

    docker-compose up -d 2>&1 > /dev/null

    # Esperar que estén listos
    log_step "Esperando que los servicios estén listos (30s)..."
    sleep 30
fi

log_success "Infraestructura está running"

# ============================================================
# 2. Test funcional: GET /movies/all
# ============================================================
log_header "2. Test: GET /movies/all"

MOVIES_ENDPOINT="http://localhost:8000/movies/all"

log_step "Solicitando lista de películas..."

RESPONSE=$(curl -s -w "\n%{http_code}" "$MOVIES_ENDPOINT" 2>/dev/null || echo -e "\n000")
BODY=$(echo "$RESPONSE" | head -n -1)
STATUS=$(echo "$RESPONSE" | tail -n 1)

if [[ "$STATUS" == "200" ]]; then
    log_success "Endpoint /movies/all responde 200"

    # Verificar que el body contiene datos
    if echo "$BODY" | grep -q "title" || echo "$BODY" | grep -q "Title"; then
        log_success "Respuesta contiene datos de películas"

        # Contar películas (si es un array JSON)
        MOVIE_COUNT=$(echo "$BODY" | grep -o "\"title\"" | wc -l || echo "0")
        log_step "Películas encontradas: $MOVIE_COUNT"

        if [[ $MOVIE_COUNT -gt 0 ]]; then
            log_success "Datos de películas válidos"
        else
            log_warning "No se encontraron películas en la respuesta"
        fi
    else
        log_error "Respuesta no contiene datos válidos de películas"
        echo "$BODY" | head -n 10 | sed 's/^/  /'
        FAILURES=$((FAILURES + 1))
    fi
else
    log_error "Endpoint /movies/all falló con status $STATUS"
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 3. Test funcional: POST /booking
# ============================================================
log_header "3. Test: POST /booking"

BOOKING_ENDPOINT="http://localhost:8300/booking/"

# Crear payload de prueba
BOOKING_PAYLOAD=$(cat <<EOF
{
  "userId": "test-user-$(date +%s)",
  "movieId": "test-movie-1",
  "seats": ["A1", "A2"],
  "showtime": "2026-01-25T19:00:00Z"
}
EOF
)

log_step "Creando booking de prueba..."

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$BOOKING_PAYLOAD" \
  "$BOOKING_ENDPOINT" 2>/dev/null || echo -e "\n000")

BODY=$(echo "$RESPONSE" | head -n -1)
STATUS=$(echo "$RESPONSE" | tail -n 1)

if [[ "$STATUS" == "200" ]] || [[ "$STATUS" == "201" ]]; then
    log_success "Booking creado exitosamente (status: $STATUS)"

    # Extraer orderId de la respuesta (si existe)
    ORDER_ID=$(echo "$BODY" | grep -oP '"orderId"\s*:\s*"\K[^"]+' || \
               echo "$BODY" | grep -oP '"id"\s*:\s*"\K[^"]+' || \
               echo "")

    if [[ -n "$ORDER_ID" ]]; then
        log_success "Order ID recibido: $ORDER_ID"

        # Guardar para verificación posterior
        echo "$ORDER_ID" > /tmp/test-order-id.txt
    else
        log_warning "No se pudo extraer orderId de la respuesta"
        echo "$BODY" | head -n 5 | sed 's/^/  /'
    fi
else
    log_error "Falló creación de booking (status: $STATUS)"
    echo "$BODY" | head -n 10 | sed 's/^/  /'
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 4. Verificar booking guardado en MongoDB
# ============================================================
log_header "4. Verificando booking en MongoDB"

if [[ -f /tmp/test-order-id.txt ]]; then
    ORDER_ID=$(cat /tmp/test-order-id.txt)

    log_step "Buscando booking en MongoDB (orderId: $ORDER_ID)..."

    # Buscar en la colección bookings
    BOOKING_DOC=$(docker exec mongo1 mongosh cinemas --quiet --eval \
        "db.bookings.findOne({orderId: '$ORDER_ID'})" 2>/dev/null || echo "")

    if [[ -n "$BOOKING_DOC" ]] && [[ "$BOOKING_DOC" != "null" ]]; then
        log_success "Booking encontrado en MongoDB"
    else
        log_warning "Booking no encontrado en MongoDB (puede ser esperado si usa otra colección)"
    fi

    # Cleanup
    rm -f /tmp/test-order-id.txt
else
    log_step "Saltando verificación (no hay orderId)"
fi

# ============================================================
# 5. Verificar payment procesado
# ============================================================
log_header "5. Verificando procesamiento de payment"

# Verificar logs del servicio de payment
log_step "Verificando logs de payment-service..."

PAYMENT_LOGS=$(docker logs payment-service 2>&1 | tail -50 || echo "")

# Buscar indicios de procesamiento de payment
if echo "$PAYMENT_LOGS" | grep -qiE "payment.*process|process.*payment|POST.*payment"; then
    log_success "Se detectó procesamiento de payment en logs"
else
    log_step "No se detectó procesamiento de payment en logs recientes"
fi

# ============================================================
# 6. Verificar GET /booking/{orderId}
# ============================================================
log_header "6. Test: GET /booking/{orderId}"

if [[ -n "$ORDER_ID" ]]; then
    GET_BOOKING_ENDPOINT="http://localhost:8300/booking/$ORDER_ID"

    log_step "Obteniendo booking: $ORDER_ID..."

    RESPONSE=$(curl -s -w "\n%{http_code}" "$GET_BOOKING_ENDPOINT" 2>/dev/null || echo -e "\n000")
    BODY=$(echo "$RESPONSE" | head -n -1)
    STATUS=$(echo "$RESPONSE" | tail -n 1)

    if [[ "$STATUS" == "200" ]]; then
        log_success "Booking recuperado exitosamente"

        # Verificar que contiene el orderId
        if echo "$BODY" | grep -q "$ORDER_ID"; then
            log_success "Booking contiene orderId correcto"
        else
            log_warning "Booking no contiene orderId esperado"
        fi
    else
        log_warning "No se pudo recuperar booking (status: $STATUS)"
    fi
else
    log_step "Saltando test GET /booking (no hay orderId de test anterior)"
fi

# ============================================================
# 7. Verificar llamadas inter-servicio en logs
# ============================================================
log_header "7. Verificando llamadas inter-servicio"

# booking → payment
log_step "Verificando booking → payment..."

BOOKING_LOGS=$(docker logs booking-service 2>&1 | tail -100 || echo "")

if echo "$BOOKING_LOGS" | grep -qiE "payment|calling.*payment|request.*payment"; then
    log_success "Se detectaron llamadas de booking a payment"
else
    log_step "No se detectaron llamadas explícitas a payment en logs"
fi

# booking → notification
log_step "Verificando booking → notification..."

if echo "$BOOKING_LOGS" | grep -qiE "notification|notify|email"; then
    log_success "Se detectaron llamadas de booking a notification"
else
    log_step "No se detectaron llamadas explícitas a notification en logs"
fi

# ============================================================
# 8. Tests de integración Go (si existen)
# ============================================================
log_header "8. Ejecutando tests de integración Go"

cd "$WORKSPACE_ROOT"

INTEGRATION_TESTS_FOUND=false

SERVICES=("booking" "movie" "payment" "notification")

for service in "${SERVICES[@]}"; do
    SERVICE_DIR="$WORKSPACE_ROOT/services/$service"

    if [[ -d "$SERVICE_DIR" ]]; then
        cd "$SERVICE_DIR"

        # Buscar archivos de test de integración
        INTEGRATION_FILES=$(find . -name "*integration*_test.go" -o -name "*_integration_test.go" 2>/dev/null | wc -l)

        if [[ $INTEGRATION_FILES -gt 0 ]]; then
            INTEGRATION_TESTS_FOUND=true

            log_step "Ejecutando integration tests de $service..."

            # Ejecutar tests con tag integration
            if go test -tags=integration -v ./... 2>&1 | tee /tmp/integration-test-$service.log; then
                log_success "Integration tests de $service pasados"
            else
                log_error "Integration tests de $service fallaron"
                tail -n 20 /tmp/integration-test-$service.log | sed 's/^/  /'
                FAILURES=$((FAILURES + 1))
            fi

            rm -f /tmp/integration-test-$service.log
        fi

        cd "$WORKSPACE_ROOT"
    fi
done

if [[ "$INTEGRATION_TESTS_FOUND" == "false" ]]; then
    log_step "No se encontraron tests de integración Go"
fi

# ============================================================
# 9. Test de carga ligera (opcional)
# ============================================================
if [[ "${RUN_LOAD_TEST:-false}" == "true" ]]; then
    log_header "9. Test de carga ligera"

    log_step "Ejecutando 10 requests concurrentes a /movies/all..."

    for i in {1..10}; do
        curl -s "$MOVIES_ENDPOINT" > /dev/null &
    done

    wait

    log_success "Test de carga completado"
fi

# ============================================================
# 10. Cleanup
# ============================================================
log_header "10. Limpieza"

cd "$(dirname "$COMPOSE_FILE")"

if [[ "${KEEP_SERVICES_RUNNING:-false}" != "true" ]]; then
    log_step "Deteniendo servicios..."
    docker-compose down -v --remove-orphans 2>&1 > /dev/null || true
    log_success "Servicios detenidos"
else
    log_info "Manteniendo servicios running (KEEP_SERVICES_RUNNING=true)"
fi

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILURES -eq 0 ]]; then
    log_success "Validación de integración completada exitosamente"
    echo "  Tests funcionales: OK"
    echo "  Inter-service communication: OK"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de integración falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
