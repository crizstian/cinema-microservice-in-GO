# E2E Integration Tests - Cinema Booking System

Tests de integracion end-to-end para el sistema completo de reservas de cine.

## Flujo de Compra Testeado

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         FLUJO COMPLETO DE COMPRA                              │
└──────────────────────────────────────────────────────────────────────────────┘

  Step 1: Register/Login           Step 2: Browse Movies        Step 3: Select Showtime
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │   user-service  │              │  movie-service  │          │showtime-service │
  │   POST /users/  │              │  GET /movies    │          │ GET /showtimes  │
  │    register     │              │                 │          │  ?movie_id=X    │
  └────────┬────────┘              └────────┬────────┘          └────────┬────────┘
           │                                │                            │
           ▼                                ▼                            ▼
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │  Access Token   │              │  List of movies │          │  Available      │
  │  (JWT)          │              │  in cartelera   │          │  showtimes      │
  └─────────────────┘              └─────────────────┘          └─────────────────┘
           │                                │                            │
           └────────────────────────────────┴────────────────────────────┘
                                            │
                                            ▼
  Step 4: View Seat Map            Step 5: Hold Seats          Step 6: Create Booking
  ┌─────────────────┐              ┌─────────────────┐          ┌─────────────────┐
  │  seat-service   │              │  seat-service   │          │ booking-service │
  │ GET /seats/     │              │ POST /seats/    │          │ POST /booking   │
  │  availability   │              │    hold         │          │                 │
  └────────┬────────┘              └────────┬────────┘          └────────┬────────┘
           │                                │                            │
           ▼                                ▼                            │
  ┌─────────────────┐              ┌─────────────────┐                   │
  │  Seat map with  │              │   hold_id       │                   │
  │  availability   │              │   (TTL: 5 min)  │                   │
  └─────────────────┘              └─────────────────┘                   │
                                                                         │
                    ┌────────────────────────────────────────────────────┘
                    │
                    ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │                      SAGA ORCHESTRATION                               │
  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
  │  │  Validate   │  │   Process   │  │   Confirm   │  │    Send     │  │
  │  │  Showtime   │──│   Payment   │──│   Seats     │──│   Email     │  │
  │  │ (showtime)  │  │  (payment)  │  │   (seat)    │  │(notification│  │
  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
  │                          │                │                          │
  │                          │ COMPENSATE     │ COMPENSATE               │
  │                          ▼                ▼                          │
  │                   ┌─────────────┐  ┌─────────────┐                   │
  │                   │Release Hold │  │   Refund    │                   │
  │                   └─────────────┘  └─────────────┘                   │
  └──────────────────────────────────────────────────────────────────────┘
                    │
                    ▼
  Step 7: Verify                   Step 8: Notification
  ┌─────────────────┐              ┌─────────────────┐
  │ booking-service │              │ notification-   │
  │ GET /booking/:id│              │    service      │
  └────────┬────────┘              │ (async email)   │
           │                       └─────────────────┘
           ▼
  ┌─────────────────┐
  │  Ticket with    │
  │  confirmation   │
  └─────────────────┘
```

## Prerequisitos

- Docker y Docker Compose v2
- Go 1.23+
- mongosh (para seeding manual)

## Ejecucion Rapida

```bash
# Ejecutar todo el ciclo de tests
make all

# O paso a paso:
make up          # Levantar servicios
make seed        # Cargar datos de prueba
make test        # Ejecutar tests
make down        # Limpiar
```

## Estructura del Proyecto

```
tests/integration/
├── docker-compose.e2e.yml   # Configuracion de todos los servicios
├── e2e_booking_test.go      # Tests E2E del flujo de compra
├── go.mod                   # Modulo Go
├── Makefile                 # Comandos utiles
├── README.md                # Este archivo
└── testdata/
    └── seed.js              # Datos iniciales para MongoDB
```

## Servicios y Puertos

| Servicio     | Puerto | Descripcion                          |
|--------------|--------|--------------------------------------|
| MongoDB      | 27017  | Base de datos (replica set)          |
| Redis        | 6379   | Cache para seat holds (TTL)          |
| user         | 8004   | Autenticacion y perfiles             |
| movie        | 8000   | Catalogo de peliculas                |
| cinema       | 8085   | Catalogo de cines y salas            |
| showtime     | 3003   | Horarios de funciones                |
| seat         | 3004   | Gestion de asientos y holds          |
| payment      | 8001   | Procesamiento de pagos (Stripe mock) |
| booking      | 8082   | Orquestador SAGA de reservas         |
| notification | 8002   | Envio de emails (SMTP mock)          |

## Tests Incluidos

### TestE2ESuite (Flujo Completo)

1. **Test01_UserRegistration** - Registro de usuario y login
2. **Test02_BrowseMovies** - Listar peliculas en cartelera
3. **Test03_SelectShowtime** - Seleccionar horario disponible
4. **Test04_ViewSeatMap** - Ver mapa de asientos
5. **Test05_HoldSeats** - Bloquear asientos temporalmente
6. **Test06_CreateBooking** - Crear reserva con pago
7. **Test07_VerifyBooking** - Verificar ticket creado
8. **Test08_VerifyNotification** - Verificar servicio de notificaciones
9. **Test09_ConcurrentSeatHolds** - Prevenir doble reserva
10. **Test10_HoldExpiration** - Expiracion de holds (placeholder)

### TestHealthChecks

Verifica que todos los servicios estan saludables.

## Comandos Make

```bash
make help           # Ver todos los comandos disponibles
make up             # Iniciar servicios
make down           # Detener servicios
make seed           # Cargar datos de prueba
make test           # Ejecutar tests
make test-verbose   # Tests con salida detallada
make health         # Verificar salud de servicios
make logs           # Ver logs de todos los servicios
make logs-booking   # Ver logs de un servicio especifico
make clean          # Limpiar todo
make rebuild        # Reconstruir imagenes
make all            # Ciclo completo: up, seed, test, down
```

## Datos de Prueba

El script `testdata/seed.js` carga:

- **3 peliculas**: The Shawshank Redemption, The Godfather, The Dark Knight
- **2 cines**: Cinepolis Reforma, Cinepolis Perisur
- **3 salas**: Con layouts de asientos generados (regular, VIP, wheelchair)
- **10 showtimes**: Funciones para hoy y manana

## Variables de Entorno

Para conectar a servicios en otra ubicacion:

```bash
export USER_SERVICE_URL=http://my-user-service:8004
export MOVIE_SERVICE_URL=http://my-movie-service:8000
# ... etc
make test
```

## Troubleshooting

### Los servicios no inician

```bash
# Ver logs de docker compose
make logs

# Verificar que no hay puertos en uso
lsof -i :8000,8001,8002,8004,8082,3003,3004,27017,6379
```

### MongoDB no acepta conexiones

```bash
# Verificar replica set
docker exec e2e-mongo mongosh --eval "rs.status()"

# Re-inicializar si es necesario
docker exec e2e-mongo mongosh --eval "rs.initiate()"
```

### Tests fallan con "service not available"

```bash
# Esperar mas tiempo para inicializacion
make health

# Si un servicio falla, ver sus logs
make logs-booking
```

### Errores de build en servicios

```bash
# Reconstruir sin cache
make rebuild
make up
```

## Integracion con CI/CD

### GitHub Actions

```yaml
name: E2E Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.23'

      - name: Start services
        run: |
          cd tests/integration
          make up
          sleep 30

      - name: Seed test data
        run: |
          cd tests/integration
          make seed

      - name: Run E2E tests
        run: |
          cd tests/integration
          make test-verbose

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: e2e-test-results
          path: tests/integration/test-results.log

      - name: Cleanup
        if: always()
        run: |
          cd tests/integration
          make down
```

## Extender los Tests

### Agregar un nuevo test case

```go
func (s *E2ETestSuite) Test11_MyNewTest() {
    s.T().Log("Step 11: My New Test")

    // Tu logica de test aqui
    resp, err := s.get(SomeServiceURL+"/endpoint", s.accessToken)
    require.NoError(s.T(), err)
    defer resp.Body.Close()

    assert.Equal(s.T(), http.StatusOK, resp.StatusCode)
}
```

### Agregar datos de prueba

Edita `testdata/seed.js` y agrega mas documentos:

```javascript
db.movies.insertOne({
  _id: "mov_nuevo",
  id: "mov_nuevo",
  title: "Nueva Pelicula",
  // ...
});
```
