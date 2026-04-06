#!/bin/bash
# run-all-tests.sh - Script para ejecutar todos los tests de los microservicios

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Tests Integrados - Microservicios Cinema${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Verificar MONGODB_TEST_URI
if [ -z "$MONGODB_TEST_URI" ]; then
    echo -e "${YELLOW}⚠ MONGODB_TEST_URI no está configurado${NC}"
    echo -e "${YELLOW}Los tests de integración se saltarán${NC}"
    echo ""
    echo -e "${YELLOW}Para habilitar tests de integración:${NC}"
    echo -e "export MONGODB_TEST_URI=\"mongodb://cristian:cristianPassword2017@192.168.68.121:27017,192.168.68.121:27018,192.168.68.121:27019/?replicaSet=rs1&authSource=admin\""
    echo ""
    read -p "¿Continuar sin tests de integración? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Contadores
TOTAL_SERVICES=3
PASSED=0
FAILED=0

# Función para ejecutar tests de un servicio
run_service_tests() {
    local service=$1
    local service_path=$2
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Testing: $service Service${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    cd "$service_path"
    
    # Ejecutar tests con cobertura
    if go test -v -cover ./internal/api/ 2>&1 | tee test-output.log; then
        echo ""
        echo -e "${GREEN}✓ $service tests PASSED${NC}"
        echo ""
        PASSED=$((PASSED + 1))
    else
        echo ""
        echo -e "${RED}✗ $service tests FAILED${NC}"
        echo ""
        FAILED=$((FAILED + 1))
    fi
    
    # Extraer estadísticas de cobertura
    if grep -q "coverage:" test-output.log; then
        coverage=$(grep "coverage:" test-output.log | tail -1 | awk '{print $NF}')
        echo -e "${YELLOW}Coverage: $coverage${NC}"
    fi
    
    rm -f test-output.log
    cd - > /dev/null
    echo ""
}

# Ejecutar tests de cada servicio
run_service_tests "Movie" "/workspace/services/movie"
run_service_tests "Booking" "/workspace/services/booking"
run_service_tests "Payment" "/workspace/services/payment"

# Resumen final
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Resumen Final${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total de servicios: $TOTAL_SERVICES"
echo -e "${GREEN}Pasados: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Fallados: $FAILED${NC}"
else
    echo -e "Fallados: $FAILED"
fi
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Todos los tests pasaron exitosamente!${NC}"
    exit 0
else
    echo -e "${RED}✗ Algunos tests fallaron${NC}"
    exit 1
fi
