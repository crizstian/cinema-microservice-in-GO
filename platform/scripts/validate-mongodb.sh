#!/usr/bin/env bash
#
# validate-mongodb.sh - Script de validación del MongoDB Replica Set
#
# Uso:
#   bash scripts/validate-mongodb.sh
#
# Requisitos:
#   - Docker y Docker Compose
#   - Cluster MongoDB levantado (docker-compose up -d)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/deploy/docker-compose/docker-compose.yml"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Credenciales (deben coincidir con docker-compose.yml)
REPLICA_USER="replicaAdmin"
REPLICA_PASS="replicaAdminPassword2017"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Validación MongoDB Replica Set - Cinemas Microservices${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================
# 1. Verificar que los contenedores estén corriendo
# ============================================================
echo -e "${YELLOW}[1/6] Verificando contenedores MongoDB...${NC}"

MONGO_CONTAINERS=$(docker-compose -f "$COMPOSE_FILE" ps -q mongo1 mongo2 mongo3 2>/dev/null | wc -l)

if [ "$MONGO_CONTAINERS" -ne 3 ]; then
    echo -e "${RED}❌ Error: No se encontraron los 3 contenedores MongoDB${NC}"
    echo -e "${YELLOW}Ejecuta: cd deploy/docker-compose && docker-compose up -d mongo1 mongo2 mongo3${NC}"
    exit 1
fi

echo -e "${GREEN}✅ 3 contenedores MongoDB encontrados${NC}"

# Obtener IDs de contenedores
MONGO1_ID=$(docker-compose -f "$COMPOSE_FILE" ps -q mongo1)
MONGO2_ID=$(docker-compose -f "$COMPOSE_FILE" ps -q mongo2)
MONGO3_ID=$(docker-compose -f "$COMPOSE_FILE" ps -q mongo3)

echo "   mongo1: $MONGO1_ID"
echo "   mongo2: $MONGO2_ID"
echo "   mongo3: $MONGO3_ID"
echo ""

# ============================================================
# 2. Verificar estado de health checks
# ============================================================
echo -e "${YELLOW}[2/6] Verificando health checks...${NC}"

for container in mongo1 mongo2 mongo3; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $(docker-compose -f "$COMPOSE_FILE" ps -q $container) 2>/dev/null || echo "none")

    if [ "$HEALTH" == "healthy" ]; then
        echo -e "   ${GREEN}✅ $container: $HEALTH${NC}"
    elif [ "$HEALTH" == "none" ]; then
        echo -e "   ${YELLOW}⚠️  $container: sin healthcheck configurado${NC}"
    else
        echo -e "   ${RED}❌ $container: $HEALTH${NC}"
    fi
done
echo ""

# ============================================================
# 3. Verificar estado del Replica Set
# ============================================================
echo -e "${YELLOW}[3/6] Verificando estado del replica set...${NC}"

RS_STATUS=$(docker exec $MONGO3_ID mongo -u $REPLICA_USER -p $REPLICA_PASS --quiet --authenticationDatabase admin --eval "rs.status().ok" 2>/dev/null || echo "0")

if [ "$RS_STATUS" == "1" ]; then
    echo -e "${GREEN}✅ Replica set inicializado correctamente${NC}"
else
    echo -e "${RED}❌ Replica set no inicializado o con errores${NC}"
    exit 1
fi
echo ""

# ============================================================
# 4. Verificar configuración del Replica Set
# ============================================================
echo -e "${YELLOW}[4/6] Verificando configuración del replica set...${NC}"

RS_CONFIG=$(docker exec $MONGO3_ID mongo -u $REPLICA_USER -p $REPLICA_PASS --quiet --authenticationDatabase admin --eval "
    var cfg = rs.conf();
    print('Replica Set Name: ' + cfg._id);
    print('Members:');
    cfg.members.forEach(function(m) {
        print('  - ' + m.host + ' (priority: ' + m.priority + ')');
    });
" 2>/dev/null)

echo "$RS_CONFIG"
echo ""

# ============================================================
# 5. Verificar miembros y estados
# ============================================================
echo -e "${YELLOW}[5/6] Verificando miembros del replica set...${NC}"

RS_MEMBERS=$(docker exec $MONGO3_ID mongo -u $REPLICA_USER -p $REPLICA_PASS --quiet --authenticationDatabase admin --eval "
    rs.status().members.forEach(function(m) {
        print(m.name + ' | ' + m.stateStr + ' | health:' + m.health);
    });
" 2>/dev/null)

echo "$RS_MEMBERS" | while read line; do
    if echo "$line" | grep -q "PRIMARY"; then
        echo -e "   ${GREEN}✅ $line${NC}"
    elif echo "$line" | grep -q "SECONDARY"; then
        echo -e "   ${GREEN}✅ $line${NC}"
    else
        echo -e "   ${YELLOW}⚠️  $line${NC}"
    fi
done
echo ""

# ============================================================
# 6. Probar conexión desde servicios
# ============================================================
echo -e "${YELLOW}[6/6] Verificando conexión desde microservicios...${NC}"

SERVICES=("movie" "payment" "booking")

for service in "${SERVICES[@]}"; do
    SERVICE_ID=$(docker-compose -f "$COMPOSE_FILE" ps -q $service 2>/dev/null)

    if [ -z "$SERVICE_ID" ]; then
        echo -e "   ${YELLOW}⚠️  $service: contenedor no encontrado (no iniciado)${NC}"
        continue
    fi

    # Buscar en logs evidencia de conexión exitosa
    CONN_LOG=$(docker logs $SERVICE_ID 2>&1 | grep -i "connecting to.*db" | tail -1)

    if [ -n "$CONN_LOG" ]; then
        echo -e "   ${GREEN}✅ $service: conexión detectada${NC}"
        echo "      Log: $(echo $CONN_LOG | cut -c1-60)..."
    else
        echo -e "   ${YELLOW}⚠️  $service: sin logs de conexión${NC}"
    fi
done
echo ""

# ============================================================
# Resumen final
# ============================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Validación completada${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Comandos útiles:"
echo "  • Ver estado detallado:"
echo "    docker exec \$MONGO3_ID mongo -u $REPLICA_USER -p $REPLICA_PASS --authenticationDatabase admin --eval 'rs.status()'"
echo ""
echo "  • Ver logs de inicialización:"
echo "    docker-compose -f $COMPOSE_FILE logs mongo3"
echo ""
echo "  • Probar failover (detener PRIMARY):"
echo "    docker-compose -f $COMPOSE_FILE stop mongo3"
echo "    # Esperar ~10-30s"
echo "    docker exec \$MONGO1_ID mongo -u $REPLICA_USER -p $REPLICA_PASS --authenticationDatabase admin --eval 'rs.status()'"
echo ""
