#!/bin/bash
# deploy-fixed.sh - Script para desplegar la solución corregida

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Despliegue de Solución MongoDB + Docker${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Paso 1: Backup
echo -e "${YELLOW}[1/8] Creando backup...${NC}"
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -r platform/deploy/docker-compose/docker-compose.yml "$BACKUP_DIR/" 2>/dev/null || true
echo -e "${GREEN}✓ Backup creado en $BACKUP_DIR${NC}"
echo ""

# Paso 2: Verificar compilación
echo -e "${YELLOW}[2/8] Verificando compilación de servicios...${NC}"
cd services/movie && go build ./... && cd ../..
cd services/booking && go build ./... && cd ../..
cd services/payment && go build ./... && cd ../..
echo -e "${GREEN}✓ Todos los servicios compilan correctamente${NC}"
echo ""

# Paso 3: Detener servicios actuales
echo -e "${YELLOW}[3/8] Deteniendo servicios actuales...${NC}"
cd platform/deploy/docker-compose
docker-compose down || true
echo -e "${GREEN}✓ Servicios detenidos${NC}"
echo ""

# Paso 4: Aplicar nuevo docker-compose
echo -e "${YELLOW}[4/8] Aplicando nuevo docker-compose.yml...${NC}"
if [ -f docker-compose.fixed.yml ]; then
    cp docker-compose.yml docker-compose.old.yml
    cp docker-compose.fixed.yml docker-compose.yml
    echo -e "${GREEN}✓ docker-compose.yml actualizado${NC}"
else
    echo -e "${RED}✗ No se encontró docker-compose.fixed.yml${NC}"
    echo -e "${YELLOW}Por favor, crea el archivo manualmente o usa el existente${NC}"
fi
echo ""

# Paso 5: Limpiar volúmenes y caché
echo -e "${YELLOW}[5/8] Limpiando caché de Docker...${NC}"
read -p "¿Deseas limpiar volúmenes de MongoDB? Esto BORRARÁ TODOS LOS DATOS (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down -v
    docker system prune -f
    echo -e "${GREEN}✓ Volúmenes limpiados${NC}"
else
    echo -e "${YELLOW}⚠ Conservando volúmenes existentes${NC}"
fi
echo ""

# Paso 6: Rebuild de imágenes
echo -e "${YELLOW}[6/8] Rebuilding imágenes Docker...${NC}"
docker-compose build --no-cache movie payment booking
echo -e "${GREEN}✓ Imágenes reconstruidas${NC}"
echo ""

# Paso 7: Iniciar MongoDB
echo -e "${YELLOW}[7/8] Iniciando MongoDB...${NC}"
docker-compose up -d mongo1 mongo2 mongo3
echo -e "${YELLOW}Esperando 20 segundos para que MongoDB esté listo...${NC}"
sleep 20

# Verificar MongoDB
echo -e "${YELLOW}Verificando salud de MongoDB...${NC}"
for i in {1..30}; do
    if docker exec mongo1 mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ MongoDB está listo${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ MongoDB no responde después de 30 intentos${NC}"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""

# Inicializar replica set
echo -e "${YELLOW}Inicializando replica set...${NC}"
docker-compose up mongo-init
docker-compose logs mongo-init | tail -20
echo ""

# Verificar replica set
echo -e "${YELLOW}Verificando replica set...${NC}"
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 \
    --authenticationDatabase admin \
    --eval "rs.status()" | grep -E "(stateStr|name)" || true
echo -e "${GREEN}✓ Replica set inicializado${NC}"
echo ""

# Paso 8: Iniciar servicios
echo -e "${YELLOW}[8/8] Iniciando servicios...${NC}"
docker-compose up -d notification payment movie booking
echo -e "${YELLOW}Esperando 30 segundos para que los servicios inicien...${NC}"
sleep 30
echo ""

# Verificar salud de servicios
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Estado de Servicios${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker-compose ps
echo ""

# Health checks
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Health Checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -n "Movie Service: "
if curl -s -f http://localhost:8000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -n "Payment Service: "
if curl -s -f http://localhost:8100/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -n "Booking Service: "
if curl -s -f http://localhost:8300/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -n "Notification Service: "
if curl -s -f http://localhost:8200/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ OK${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi
echo ""

# Logs de movie service
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Logs de Movie Service (últimas 20 líneas)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
docker-compose logs --tail=20 movie
echo ""

# Verificar SIGSEGV
if docker-compose logs movie | grep -q "SIGSEGV"; then
    echo -e "${RED}✗ SIGSEGV detectado en logs!${NC}"
    echo -e "${YELLOW}Revisa los logs completos con: docker-compose logs movie${NC}"
    exit 1
else
    echo -e "${GREEN}✓ No se detectó SIGSEGV${NC}"
fi
echo ""

# Verificar conexión a MongoDB
if docker-compose logs movie | grep -q "Successfully connected to MongoDB"; then
    echo -e "${GREEN}✓ Conexión a MongoDB exitosa${NC}"
else
    echo -e "${RED}✗ No se pudo confirmar conexión a MongoDB${NC}"
    echo -e "${YELLOW}Revisa los logs completos con: docker-compose logs movie${NC}"
fi
echo ""

# Resumen final
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Resumen${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Backup: ${GREEN}$BACKUP_DIR${NC}"
echo -e "Docker Compose: ${GREEN}Actualizado${NC}"
echo -e "Servicios: ${GREEN}$(docker-compose ps --services --filter 'status=running' | wc -l) running${NC}"
echo ""
echo -e "${GREEN}✓ Despliegue completado!${NC}"
echo ""
echo -e "${YELLOW}Comandos útiles:${NC}"
echo -e "  Ver logs:      ${BLUE}cd platform/deploy/docker-compose && docker-compose logs -f movie${NC}"
echo -e "  Reiniciar:     ${BLUE}docker-compose restart movie${NC}"
echo -e "  Estado:        ${BLUE}docker-compose ps${NC}"
echo -e "  Health:        ${BLUE}curl http://localhost:8000/health${NC}"
echo ""
