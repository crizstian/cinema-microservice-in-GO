#!/bin/bash
# test-mongodb-connection.sh
# Script para ejecutar tests de conexión MongoDB en todos los servicios

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración MongoDB
export DB_USER="cristian"
export DB_PASS="cristianPassword2017"
export DB_SERVERS="192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019"
export DB_REPLICA="rs1"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  MongoDB Connection Tests - Cinema Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}MongoDB Configuration:${NC}"
echo -e "  User: ${DB_USER}"
echo -e "  Servers: ${DB_SERVERS}"
echo -e "  Replica Set: ${DB_REPLICA}"
echo ""

# Función para ejecutar tests de un servicio
run_service_tests() {
    local service_name=$1
    local service_path=$2
    local db_name=$3

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Testing ${service_name} Service${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    export DB_NAME="${db_name}"

    cd "${service_path}" || {
        echo -e "${RED}✗ Failed to change directory to ${service_path}${NC}"
        return 1
    }

    echo -e "Database: ${DB_NAME}"
    echo ""

    if go test -v -timeout 120s ./internal/db/; then
        echo -e "${GREEN}✓ ${service_name} tests PASSED${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}✗ ${service_name} tests FAILED${NC}"
        echo ""
        return 1
    fi
}

# Función para ejecutar un test específico
run_specific_test() {
    local service_name=$1
    local service_path=$2
    local db_name=$3
    local test_name=$4

    echo -e "${YELLOW}Running test: ${test_name} for ${service_name}${NC}"

    export DB_NAME="${db_name}"

    cd "${service_path}" || {
        echo -e "${RED}✗ Failed to change directory to ${service_path}${NC}"
        return 1
    }

    if go test -v -timeout 120s ./internal/db/ -run "${test_name}"; then
        echo -e "${GREEN}✓ Test PASSED${NC}"
        return 0
    else
        echo -e "${RED}✗ Test FAILED${NC}"
        return 1
    fi
}

# Obtener directorio raíz del proyecto
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Servicios a testear
SERVICES=(
    "Movie:${PROJECT_ROOT}/services/movie:movies"
    "Booking:${PROJECT_ROOT}/services/booking:booking"
    "Payment:${PROJECT_ROOT}/services/payment:payment"
)

# Variables para tracking de resultados
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Función de ayuda
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -s, --service SERVICE   Run tests only for specific service (movie|booking|payment)"
    echo "  -t, --test TEST_NAME    Run specific test by name"
    echo "  -q, --quick             Run only the main connection test"
    echo "  -a, --all               Run all tests (default)"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests for all services"
    echo "  $0 -s movie             # Run all tests for movie service only"
    echo "  $0 -s movie -t TestMongoDBConnection_WithRealReplicaSet"
    echo "  $0 -q                   # Quick test - only connection validation"
    exit 0
}

# Parsear argumentos
SERVICE_FILTER=""
TEST_FILTER=""
QUICK_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -s|--service)
            SERVICE_FILTER="$2"
            shift 2
            ;;
        -t|--test)
            TEST_FILTER="$2"
            shift 2
            ;;
        -q|--quick)
            QUICK_MODE=true
            TEST_FILTER="TestMongoDBConnection_WithRealReplicaSet"
            shift
            ;;
        -a|--all)
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            ;;
    esac
done

# Ejecutar tests
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r service_name service_path db_name <<< "$service_info"

    # Filtrar por servicio si se especificó
    if [[ -n "$SERVICE_FILTER" ]]; then
        if [[ "${service_name,,}" != "${SERVICE_FILTER,,}" ]]; then
            continue
        fi
    fi

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    if [[ -n "$TEST_FILTER" ]]; then
        if run_specific_test "$service_name" "$service_path" "$db_name" "$TEST_FILTER"; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    else
        if run_service_tests "$service_name" "$service_path" "$db_name"; then
            PASSED_TESTS=$((PASSED_TESTS + 1))
        else
            FAILED_TESTS=$((FAILED_TESTS + 1))
        fi
    fi
done

# Resumen final
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total Services Tested: ${TOTAL_TESTS}"
echo -e "${GREEN}Passed: ${PASSED_TESTS}${NC}"
echo -e "${RED}Failed: ${FAILED_TESTS}${NC}"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the output above.${NC}"
    exit 1
fi
