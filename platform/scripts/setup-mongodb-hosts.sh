#!/bin/bash
# setup-mongodb-hosts.sh
# Agrega entradas al /etc/hosts para resolver mongo1, mongo2, mongo3

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# IP de MongoDB (configurable)
MONGO_IP="${1:-192.168.21.145}"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Configuración de /etc/hosts para MongoDB${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}IP de MongoDB: ${MONGO_IP}${NC}"
echo ""

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Este script debe ejecutarse como root${NC}"
    echo -e "${YELLOW}Ejecuta: sudo $0 ${MONGO_IP}${NC}"
    exit 1
fi

# Backup del archivo hosts
echo -e "${YELLOW}[1/3] Creando backup de /etc/hosts...${NC}"
cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓ Backup creado${NC}"

# Verificar si ya existen las entradas
echo ""
echo -e "${YELLOW}[2/3] Verificando entradas existentes...${NC}"

if grep -q "# MongoDB Replica Set Entries" /etc/hosts; then
    echo -e "${YELLOW}⚠ Entradas de MongoDB ya existen, eliminando...${NC}"
    sed -i '/# MongoDB Replica Set Entries/,/# End MongoDB Entries/d' /etc/hosts
fi

# Agregar nuevas entradas
echo ""
echo -e "${YELLOW}[3/3] Agregando entradas a /etc/hosts...${NC}"

cat >> /etc/hosts << EOF

# MongoDB Replica Set Entries
${MONGO_IP}  mongo1
${MONGO_IP}  mongo2
${MONGO_IP}  mongo3
# End MongoDB Entries
EOF

echo -e "${GREEN}✓ Entradas agregadas${NC}"

# Verificar
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Verificando configuración:${NC}"
echo ""
grep -A 3 "MongoDB Replica Set Entries" /etc/hosts
echo ""

# Probar resolución DNS
echo -e "${YELLOW}Probando resolución DNS...${NC}"
for host in mongo1 mongo2 mongo3; do
    ip=$(getent hosts $host | awk '{print $1}')
    if [ "$ip" = "$MONGO_IP" ]; then
        echo -e "${GREEN}✓ $host → $ip${NC}"
    else
        echo -e "${RED}✗ $host no resuelve correctamente (obtenido: $ip)${NC}"
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}¡Configuración completada!${NC}"
echo ""
echo -e "${YELLOW}Ahora puedes ejecutar los tests:${NC}"
echo -e "  cd services/movie && go test -v ./internal/db/"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
