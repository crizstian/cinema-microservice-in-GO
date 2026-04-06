#!/bin/bash
# reconfigure-replica-with-ips.sh
# Reconfigura el replica set de MongoDB para usar IPs en lugar de hostnames

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Reconfiguración de MongoDB Replica Set${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Configuración
MONGO_USER="${1:-cristian}"
MONGO_PASS="${2:-cristianPassword2017}"
MONGO_IP="${3:-192.168.68.104}"
REPLICA_SET="${4:-rs1}"

echo -e "${YELLOW}Configuración:${NC}"
echo -e "  Usuario: ${MONGO_USER}"
echo -e "  IP Base: ${MONGO_IP}"
echo -e "  Replica Set: ${REPLICA_SET}"
echo ""

# Conectar a MongoDB y obtener configuración actual
echo -e "${YELLOW}[1/4] Obteniendo configuración actual...${NC}"

CURRENT_CONFIG=$(docker exec mongo1 mongosh --quiet -u "${MONGO_USER}" -p "${MONGO_PASS}" --authenticationDatabase admin --eval "
var config = rs.conf();
printjson(config);
" 2>/dev/null)

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Error al obtener configuración actual${NC}"
    echo -e "${YELLOW}Intentando sin autenticación...${NC}"

    CURRENT_CONFIG=$(docker exec mongo1 mongosh --quiet --eval "
    var config = rs.conf();
    printjson(config);
    " 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ No se pudo conectar a MongoDB${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Configuración actual obtenida${NC}"

# Reconfigurar replica set con IPs
echo ""
echo -e "${YELLOW}[2/4] Reconfigurando replica set con IPs...${NC}"

docker exec mongo1 mongosh --quiet -u "${MONGO_USER}" -p "${MONGO_PASS}" --authenticationDatabase admin --eval "
var config = rs.conf();
config.members[0].host = '${MONGO_IP}:27017';
config.members[1].host = '${MONGO_IP}:27018';
config.members[2].host = '${MONGO_IP}:27019';
config.version++;

var result = rs.reconfig(config, {force: true});
printjson(result);
" 2>&1

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Error al reconfigurar${NC}"
    echo -e "${YELLOW}Intentando sin autenticación...${NC}"

    docker exec mongo1 mongosh --quiet --eval "
    var config = rs.conf();
    config.members[0].host = '${MONGO_IP}:27017';
    config.members[1].host = '${MONGO_IP}:27018';
    config.members[2].host = '${MONGO_IP}:27019';
    config.version++;

    var result = rs.reconfig(config, {force: true});
    printjson(result);
    " 2>&1

    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Falló la reconfiguración${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Replica set reconfigurado${NC}"

# Esperar estabilización
echo ""
echo -e "${YELLOW}[3/4] Esperando estabilización (20 segundos)...${NC}"
sleep 20

# Verificar nueva configuración
echo ""
echo -e "${YELLOW}[4/4] Verificando nueva configuración...${NC}"

docker exec mongo1 mongosh --quiet -u "${MONGO_USER}" -p "${MONGO_PASS}" --authenticationDatabase admin --eval "
var status = rs.status();
print('');
print('Replica Set: ' + status.set);
print('');
print('Miembros:');
status.members.forEach(function(member) {
  print('  ' + member.name + ' - ' + member.stateStr + ' (health: ' + member.health + ')');
});
print('');
" 2>/dev/null || docker exec mongo1 mongosh --quiet --eval "
var status = rs.status();
print('');
print('Replica Set: ' + status.set);
print('');
print('Miembros:');
status.members.forEach(function(member) {
  print('  ' + member.name + ' - ' + member.stateStr + ' (health: ' + member.health + ')');
});
print('');
"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Reconfiguración completada exitosamente${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Ahora puedes conectarte usando:${NC}"
    echo -e "${YELLOW}  mongodb://${MONGO_USER}:****@${MONGO_IP}:27017,${MONGO_IP}:27018,${MONGO_IP}:27019/?replicaSet=${REPLICA_SET}&authSource=admin${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
else
    echo -e "${RED}✗ Error al verificar configuración${NC}"
    exit 1
fi
