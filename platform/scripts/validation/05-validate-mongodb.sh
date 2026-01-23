#!/bin/bash
# 05-validate-mongodb.sh - Validar MongoDB replica set

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

WORKSPACE_ROOT="/workspace"
COMPOSE_FILE="$WORKSPACE_ROOT/platform/deploy/docker-compose/docker-compose.yml"
FAILURES=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ETAPA 5: Validación de MongoDB Replica Set"
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

if ! check_command "docker-compose"; then
    log_error "Docker Compose no está instalado"
    exit 1
fi

log_success "Docker y Docker Compose disponibles"

# ============================================================
# 2. Verificar docker-compose.yml
# ============================================================
log_header "2. Verificando docker-compose.yml"

if ! check_file "$COMPOSE_FILE" "docker-compose.yml"; then
    log_error "docker-compose.yml no encontrado"
    exit 1
fi

# Verificar que contiene MongoDB
if grep -q "mongo1:" "$COMPOSE_FILE" && \
   grep -q "mongo2:" "$COMPOSE_FILE" && \
   grep -q "mongo3:" "$COMPOSE_FILE"; then
    log_success "docker-compose.yml contiene 3 nodos MongoDB"
else
    log_error "docker-compose.yml no contiene configuración completa de MongoDB"
    exit 1
fi

# ============================================================
# 3. Limpiar contenedores existentes
# ============================================================
log_header "3. Preparando ambiente"

log_step "Limpiando contenedores existentes..."
cd "$(dirname "$COMPOSE_FILE")"
docker-compose down -v --remove-orphans 2>&1 > /dev/null || true
log_success "Ambiente limpio"

# ============================================================
# 4. Levantar solo MongoDB
# ============================================================
log_header "4. Levantando MongoDB replica set"

log_step "Iniciando contenedores MongoDB..."

if docker-compose up -d mongo1 mongo2 mongo3 2>&1 > /tmp/mongo-start.log; then
    log_success "Contenedores MongoDB iniciados"
else
    log_error "Falló al iniciar contenedores MongoDB"
    cat /tmp/mongo-start.log
    FAILURES=$((FAILURES + 1))
    exit 1
fi

# ============================================================
# 5. Esperar inicialización completa
# ============================================================
log_header "5. Esperando inicialización del replica set"

INIT_TIMEOUT=90
log_step "Esperando hasta ${INIT_TIMEOUT}s para inicialización completa..."

# Esperar que los contenedores estén running
sleep 5

# Verificar que los 3 contenedores están running
RUNNING_COUNT=$(docker-compose ps mongo1 mongo2 mongo3 | grep -c "Up" || echo "0")

if [[ $RUNNING_COUNT -eq 3 ]]; then
    log_success "Los 3 contenedores MongoDB están running"
else
    log_error "No todos los contenedores MongoDB están running ($RUNNING_COUNT/3)"
    docker-compose ps
    FAILURES=$((FAILURES + 1))
fi

# Esperar healthchecks
log_step "Esperando healthchecks..."

for container in mongo1 mongo2 mongo3; do
    if wait_for_healthy "$container" "$INIT_TIMEOUT"; then
        log_success "$container está healthy"
    else
        log_error "$container no está healthy"
        FAILURES=$((FAILURES + 1))
    fi
done

# Esperar adicional para que el replica set se estabilice
log_step "Esperando estabilización del replica set (30s)..."
sleep 30

# ============================================================
# 6. Verificar replica set status
# ============================================================
log_header "6. Verificando estado del replica set"

log_step "Ejecutando rs.status()..."

RS_STATUS=$(docker exec mongo1 mongosh --quiet --eval "rs.status()" 2>/dev/null || echo "{}")

# Verificar que rs.status().ok == 1
if echo "$RS_STATUS" | grep -q "ok: 1" || echo "$RS_STATUS" | grep -q "'ok': 1"; then
    log_success "Replica set está OK (ok: 1)"
else
    log_error "Replica set no está OK"
    echo "$RS_STATUS"
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 7. Verificar topología: 1 PRIMARY + 2 SECONDARY
# ============================================================
log_header "7. Verificando topología del replica set"

# Contar PRIMARY
PRIMARY_COUNT=$(echo "$RS_STATUS" | grep -c "stateStr: 'PRIMARY'" || echo "0")

# Contar SECONDARY
SECONDARY_COUNT=$(echo "$RS_STATUS" | grep -c "stateStr: 'SECONDARY'" || echo "0")

log_step "PRIMARY nodes: $PRIMARY_COUNT"
log_step "SECONDARY nodes: $SECONDARY_COUNT"

if [[ $PRIMARY_COUNT -eq 1 ]]; then
    log_success "1 nodo PRIMARY (correcto)"
else
    log_error "Se esperaba 1 PRIMARY, encontrados: $PRIMARY_COUNT"
    FAILURES=$((FAILURES + 1))
fi

if [[ $SECONDARY_COUNT -eq 2 ]]; then
    log_success "2 nodos SECONDARY (correcto)"
else
    log_error "Se esperaban 2 SECONDARY, encontrados: $SECONDARY_COUNT"
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 8. Verificar datos de prueba
# ============================================================
log_header "8. Verificando datos de prueba"

log_step "Verificando base de datos 'cinemas'..."

# Esperar a que la DB esté lista
sleep 5

# Verificar colección movies
MOVIE_COUNT=$(docker exec mongo1 mongosh cinemas --quiet --eval "db.movies.countDocuments({})" 2>/dev/null || echo "0")

log_step "Documentos en colección 'movies': $MOVIE_COUNT"

if [[ $MOVIE_COUNT -gt 0 ]]; then
    log_success "Datos de prueba cargados ($MOVIE_COUNT movies)"
else
    log_warning "No se encontraron datos de prueba en la colección movies"
fi

# ============================================================
# 9. Verificar autenticación (si está habilitada)
# ============================================================
log_header "9. Verificando configuración de autenticación"

# Intentar conectar sin autenticación
AUTH_REQUIRED=$(docker exec mongo1 mongosh --quiet --eval "db.adminCommand({listDatabases: 1})" 2>&1 | grep -c "command listDatabases requires authentication" || echo "0")

if [[ $AUTH_REQUIRED -gt 0 ]]; then
    log_success "Autenticación está habilitada"

    # Intentar conectar con credenciales (si están disponibles)
    # Esto depende de cómo estén configuradas las credenciales
    log_step "Verificando autenticación con credenciales..."

    # Aquí podrías agregar verificación con usuario/password si los conoces
    # Por ahora solo verificamos que la autenticación está activa

else
    log_warning "Autenticación no parece estar habilitada (modo desarrollo OK)"
fi

# ============================================================
# 10. Verificar logs sin errores críticos
# ============================================================
log_header "10. Verificando logs"

for container in mongo1 mongo2 mongo3; do
    log_step "Verificando logs de $container..."

    # Buscar errores críticos en los últimos logs
    ERRORS=$(docker logs "$container" 2>&1 | tail -50 | grep -iE "error|fatal|exception" | grep -v "error: NotYetInitialized" | grep -v "error: HostUnreachable" || true)

    if [[ -z "$ERRORS" ]]; then
        log_success "No hay errores críticos en $container"
    else
        log_warning "Posibles errores en $container:"
        echo "$ERRORS" | head -n 5 | sed 's/^/  /'
    fi
done

# ============================================================
# 11. Test de escritura y lectura
# ============================================================
log_header "11. Probando escritura y lectura"

TEST_DOC='{"test": "validation", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'

log_step "Insertando documento de prueba..."

INSERT_RESULT=$(docker exec mongo1 mongosh cinemas --quiet --eval "db.validation_test.insertOne($TEST_DOC)" 2>/dev/null || echo "error")

if echo "$INSERT_RESULT" | grep -q "acknowledged: true"; then
    log_success "Escritura exitosa"

    # Intentar leer
    log_step "Leyendo documento de prueba..."

    READ_RESULT=$(docker exec mongo1 mongosh cinemas --quiet --eval 'db.validation_test.findOne({test: "validation"})' 2>/dev/null || echo "error")

    if echo "$READ_RESULT" | grep -q "validation"; then
        log_success "Lectura exitosa"

        # Cleanup
        docker exec mongo1 mongosh cinemas --quiet --eval 'db.validation_test.drop()' > /dev/null 2>&1 || true
    else
        log_error "Falló la lectura"
        FAILURES=$((FAILURES + 1))
    fi
else
    log_error "Falló la escritura"
    FAILURES=$((FAILURES + 1))
fi

# ============================================================
# 12. Cleanup
# ============================================================
log_header "12. Limpieza"

if [[ "${KEEP_MONGODB_RUNNING:-false}" != "true" ]]; then
    log_step "Deteniendo contenedores MongoDB..."
    docker-compose down -v --remove-orphans 2>&1 > /dev/null || true
    log_success "Contenedores MongoDB detenidos"
else
    log_info "Manteniendo MongoDB running (KEEP_MONGODB_RUNNING=true)"
fi

# Cleanup de archivos temporales
rm -f /tmp/mongo-start.log

# ============================================================
# Resumen
# ============================================================
ELAPSED=$(get_elapsed)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ $FAILURES -eq 0 ]]; then
    log_success "Validación de MongoDB completada exitosamente"
    echo "  Nodos: 3 (1 PRIMARY + 2 SECONDARY)"
    echo "  Estado: Replica set operacional"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    log_error "Validación de MongoDB falló con $FAILURES errores"
    echo -e "  ${CLOCK} Tiempo: $ELAPSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi
