# Guía de Tests Integrados para Microservicios

## Descripción General

Se han creado tests comprehensivos para los tres servicios principales:
- **Movie Service**: Tests de API de películas
- **Booking Service**: Tests de API de reservas
- **Payment Service**: Tests de API de pagos

Cada servicio incluye:
✅ Tests unitarios con mocks
✅ Tests de integración con MongoDB real
✅ Tests de endpoints HTTP
✅ Tests de validación con table-driven tests
✅ Tests de benchmark de rendimiento
✅ Tests de casos edge
✅ Tests de acceso concurrente

## Archivos de Tests Creados

```
services/movie/internal/api/movies_test.go
services/booking/internal/api/booking_test.go
services/payment/internal/api/payment_test.go
```

## Configuración Previa

### 1. Variable de Entorno para MongoDB de Tests

Los tests de integración requieren una instancia de MongoDB. Configura la variable:

```bash
export MONGODB_TEST_URI="mongodb://cristian:cristianPassword2017@192.168.68.121:27017,192.168.68.121:27018,192.168.68.121:27019/?replicaSet=rs1&authSource=admin"
```

**Nota**: Esta URI debe apuntar a tu instancia de MongoDB de tests. Los tests crearán y limpiarán sus propias bases de datos temporales.

### 2. Instalar Dependencias

```bash
# En cada servicio
cd services/movie && go mod tidy
cd services/booking && go mod tidy
cd services/payment && go mod tidy
```

## Ejecutar Tests

### Tests por Servicio

#### Movie Service
```bash
cd services/movie

# Todos los tests
go test -v ./internal/api/

# Solo tests de integración
go test -v ./internal/api/ -run Integration

# Solo tests unitarios (sin MongoDB)
go test -v ./internal/api/ -run "^Test[^I]"

# Tests con cobertura
go test -v -cover ./internal/api/

# Tests con cobertura detallada
go test -v -coverprofile=coverage.out ./internal/api/
go tool cover -html=coverage.out
```

#### Booking Service
```bash
cd services/booking

# Todos los tests
go test -v ./internal/api/

# Solo tests de integración
go test -v ./internal/api/ -run Integration

# Tests con cobertura
go test -v -cover ./internal/api/
```

#### Payment Service
```bash
cd services/payment

# Todos los tests
go test -v ./internal/api/

# Solo tests de integración
go test -v ./internal/api/ -run Integration

# Tests con cobertura
go test -v -cover ./internal/api/
```

### Ejecutar Todos los Tests de Una Vez

```bash
# Desde la raíz del proyecto
./run-all-tests.sh
```

O manualmente:
```bash
cd /workspace
for service in movie booking payment; do
    echo "================================================"
    echo "Testing $service service..."
    echo "================================================"
    cd services/$service
    go test -v ./internal/api/
    cd ../..
done
```

### Benchmark Tests

Los tests de benchmark miden el rendimiento de las operaciones:

```bash
# Movie Service
cd services/movie
go test -bench=. -benchmem ./internal/api/

# Booking Service
cd services/booking
go test -bench=. -benchmem ./internal/api/

# Payment Service
cd services/payment
go test -bench=. -benchmem ./internal/api/
```

## Estructura de los Tests

### Movie Service Tests

**Test Functions:**
- `TestGetTimeFormat` - Valida función helper de tiempo
- `TestIntegrationGetAllMovies` - Obtener todas las películas (MongoDB)
- `TestIntegrationGetMovieByID` - Obtener película por ID (MongoDB)
- `TestIntegrationGetMovieByIDNotFound` - Caso de película no encontrada
- `TestIntegrationGetMoviePremiers` - Obtener estrenos recientes
- `TestConnectWithValidDB` - Validar conexión a DB
- `TestConnectWithNilDB` - Validar error con DB nula
- `TestGetMovieByIDTableDriven` - Tests con múltiples casos
- `TestGetAllMoviesEmptyDB` - Base de datos vacía
- `TestGetMoviePremiersNoRecent` - Sin estrenos recientes
- `TestConcurrentGetAllMovies` - Acceso concurrente

**Benchmarks:**
- `BenchmarkGetAllMovies` - Rendimiento de listar películas
- `BenchmarkGetMovieByID` - Rendimiento de búsqueda por ID

### Booking Service Tests

**Test Functions:**
- `TestIntegrationGetOrderByID` - Obtener orden por ID (MongoDB)
- `TestIntegrationGetOrderByIDNotFound` - Orden no encontrada
- `TestConnectWithValidDB` - Validar conexión
- `TestConnectWithNilDB` - Validar error con DB nula
- `TestGetOrderByIDTableDriven` - Tests con múltiples casos
- `TestBookingRequestValidation` - Validación de requests
- `TestGetOrderByIDWithSpecialCharacters` - Caracteres especiales
- `TestGetOrderByIDEmptyDatabase` - Base de datos vacía
- `TestConcurrentGetOrderByID` - Acceso concurrente

**Mocks:**
- `MockAPIClient` - Mock completo de servicios externos (payment, notification)

**Benchmarks:**
- `BenchmarkGetOrderByID` - Rendimiento de búsqueda de órdenes

### Payment Service Tests

**Test Functions:**
- `TestIntegrationGetPurchaseByID` - Obtener pago por ID (MongoDB)
- `TestIntegrationGetPurchaseByIDNotFound` - Pago no encontrado
- `TestConnectWithValidDB` - Validar conexión
- `TestConnectWithNilDB` - Validar error con DB nula
- `TestGetPurchaseByIDTableDriven` - Tests con múltiples casos
- `TestPaymentRequestValidation` - Validación de requests de pago
- `TestPaymentAmountValidation` - Validación de montos
- `TestCreditCardValidation` - Validación de tarjetas
- `TestGetPurchaseByIDWithSpecialCharacters` - Caracteres especiales
- `TestGetPurchaseByIDEmptyDatabase` - Base de datos vacía
- `TestConcurrentGetPurchaseByID` - Acceso concurrente
- `TestMultipleCurrencies` - Validación de monedas

**Benchmarks:**
- `BenchmarkGetPurchaseByID` - Rendimiento de búsqueda de pagos

## Sin MongoDB (Skip Tests de Integración)

Si no tienes MongoDB disponible, los tests de integración se saltarán automáticamente:

```bash
# Los tests sin MONGODB_TEST_URI se saltarán
unset MONGODB_TEST_URI
go test -v ./internal/api/
```

Verás mensajes como:
```
--- SKIP: TestIntegrationGetAllMovies (0.00s)
    movies_test.go:55: MONGODB_TEST_URI not set, skipping integration test
```

## Cobertura de Tests

### Generar Reporte de Cobertura

```bash
# Para cada servicio
cd services/movie
go test -coverprofile=coverage.out ./internal/api/
go tool cover -html=coverage.out -o coverage.html

# Abrir en navegador
open coverage.html  # macOS
xdg-open coverage.html  # Linux
start coverage.html  # Windows
```

### Cobertura Consolidada

```bash
#!/bin/bash
# Script para generar cobertura consolidada

echo "mode: set" > coverage-all.out

for service in movie booking payment; do
    cd services/$service
    go test -coverprofile=coverage.tmp ./internal/api/
    tail -n +2 coverage.tmp >> ../../coverage-all.out
    rm coverage.tmp
    cd ../..
done

go tool cover -html=coverage-all.out -o coverage-all.html
echo "Coverage report: coverage-all.html"
```

## Tests Continuos (Watch Mode)

Usando `entr` o `watchexec`:

```bash
# Instalar entr
# macOS: brew install entr
# Linux: apt-get install entr

# Watch mode para movie service
cd services/movie
find . -name "*.go" | entr -c go test -v ./internal/api/
```

O con `watchexec`:
```bash
# Instalar watchexec
# cargo install watchexec-cli

cd services/movie
watchexec -e go -c go test -v ./internal/api/
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      mongodb:
        image: mongo:8.0
        env:
          MONGO_INITDB_ROOT_USERNAME: cristian
          MONGO_INITDB_ROOT_PASSWORD: cristianPassword2017
        ports:
          - 27017:27017
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.23'
      
      - name: Run tests
        env:
          MONGODB_TEST_URI: mongodb://cristian:cristianPassword2017@localhost:27017/?authSource=admin
        run: |
          cd services/movie && go test -v -cover ./internal/api/
          cd ../booking && go test -v -cover ./internal/api/
          cd ../payment && go test -v -cover ./internal/api/
```

## Troubleshooting

### Error: "MONGODB_TEST_URI not set"
**Solución**: Exporta la variable de entorno con tu URI de MongoDB:
```bash
export MONGODB_TEST_URI="mongodb://user:pass@host:port/?replicaSet=rs1"
```

### Error: "connection refused"
**Solución**: Verifica que MongoDB está corriendo y accesible:
```bash
mongosh "mongodb://cristian:cristianPassword2017@192.168.68.121:27017/?authSource=admin"
```

### Tests muy lentos
**Solución**: 
1. Reduce timeouts en tests
2. Usa `-short` flag para tests más rápidos
3. Ejecuta tests en paralelo: `go test -parallel 4`

### Error: "duplicate test database"
**Solución**: Los tests crean DBs temporales con timestamp. Si hay conflicto:
```bash
# Limpiar DBs de test
mongosh --eval 'db.adminCommand("listDatabases").databases.forEach(function(d){if(d.name.startsWith("test_")) db.getSiblingDB(d.name).dropDatabase()})'
```

## Mejores Prácticas

1. **Ejecuta tests antes de commit**
   ```bash
   git add .
   go test ./...  # Si pasa, entonces commit
   git commit -m "..."
   ```

2. **Mantén tests rápidos**
   - Tests unitarios < 100ms
   - Tests de integración < 1s
   - Usa mocks cuando sea posible

3. **Limpia recursos**
   - Los tests limpian sus propias DBs temporales
   - Usa `defer cleanup()` siempre

4. **Tests determinísticos**
   - No dependas de orden de ejecución
   - No uses datos de producción
   - Seed data explícitamente

5. **Cobertura objetivo: >80%**
   - Prioriza rutas críticas
   - Incluye casos edge
   - Tests de error son importantes

## Próximos Pasos

### Tests Adicionales Recomendados

1. **E2E Tests**: Tests completos de flujo usuario
2. **Load Tests**: Tests de carga con k6 o Gatling
3. **Contract Tests**: Tests de contratos entre servicios
4. **Security Tests**: Tests de vulnerabilidades
5. **Chaos Engineering**: Tests de resiliencia

### Herramientas Adicionales

- **gomock**: Para mocks más complejos
- **testify/suite**: Para test suites organizadas
- **httpexpect**: Para tests de API más expresivos
- **go-sqlmock**: Para mocks de SQL si se usa
- **dockertest**: Para levantar MongoDB en tests

## Contacto

Para dudas o mejoras en los tests, contacta al equipo de desarrollo.
