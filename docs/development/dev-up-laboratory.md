# dev:up Laboratory Guide

> Tutorial interactivo para aprovechar al maximo el entorno de desarrollo local con `task dev:up`.

## Tabla de Contenidos

- [Introduccion](#introduccion)
- [Prerequisitos](#prerequisitos)
- [Lab 1: Inicio Rapido](#lab-1-inicio-rapido)
- [Lab 2: Debugging con Delve](#lab-2-debugging-con-delve)
- [Lab 3: Inspeccion de MongoDB](#lab-3-inspeccion-de-mongodb)
- [Lab 4: Redis y Seat Holds](#lab-4-redis-y-seat-holds)
- [Lab 5: NATS Messaging](#lab-5-nats-messaging)
- [Lab 6: Pruebas Manuales con curl](#lab-6-pruebas-manuales-con-curl)
- [Lab 7: Resiliencia de MongoDB Replica Set](#lab-7-resiliencia-de-mongodb-replica-set)
- [Lab 8: Performance Testing con k6](#lab-8-performance-testing-con-k6)
- [Lab 9: Contract Testing Local](#lab-9-contract-testing-local)
- [Lab 10: Seed Data Persistente](#lab-10-seed-data-persistente)
- [Troubleshooting](#troubleshooting)

---

## Introduccion

`dev:up` levanta un entorno de desarrollo completo con:

| Componente | Configuracion |
|------------|---------------|
| MongoDB | 3 replicas (rs0) con volumenes persistentes |
| Redis | Volumen persistente |
| NATS | JetStream habilitado |
| Servicios | 8 microservicios con hot-reload |

### dev:up vs test:e2e

| Aspecto | dev:up | test:e2e |
|---------|--------|----------|
| **Proposito** | Desarrollo iterativo | Validacion automatizada |
| **MongoDB** | 3 replicas persistentes | 1 nodo efimero (tmpfs) |
| **Datos** | Persisten entre reinicios | Se borran al terminar |
| **Tiempo startup** | ~30s | ~15s |

---

## Prerequisitos

```bash
# Verificar herramientas instaladas
docker --version      # >= 24.0
docker compose version # >= 2.20
task --version        # >= 3.0
go version            # >= 1.24

# Clonar el repositorio (si no lo tienes)
git clone https://github.com/your-org/cinema-microservices.git
cd cinema-microservices
```

---

## Lab 1: Inicio Rapido

**Objetivo**: Levantar el entorno completo y verificar que todos los servicios estan healthy.

### Paso 1: Iniciar el entorno

```bash
task dev:up
```

**Output esperado**:
```
[+] Running 12/12
 ✔ Network cinema-dev-network  Created
 ✔ Container dev-mongo1        Healthy
 ✔ Container dev-mongo2        Healthy
 ✔ Container dev-mongo3        Healthy
 ✔ Container dev-redis         Healthy
 ✔ Container cinema-nats       Healthy
 ✔ Container cinema-movie      Healthy
 ✔ Container cinema-booking    Healthy
 ...
```

### Paso 2: Verificar servicios

```bash
# Ver estado de todos los contenedores
task dev:status

# O manualmente:
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps
```

### Paso 3: Health checks rapidos

```bash
# Verificar cada servicio
curl -s http://localhost:8000/ping  # movie
curl -s http://localhost:8004/ping  # user
curl -s http://localhost:8082/ping  # booking
curl -s http://localhost:3003/ping  # showtime
curl -s http://localhost:3004/ping  # seat
curl -s http://localhost:8001/ping  # payment
curl -s http://localhost:8002/ping  # notification
curl -s http://localhost:8085/ping  # cinema
```

### Paso 4: Detener el entorno

```bash
task dev:down
```

---

## Lab 2: Debugging con Delve

**Objetivo**: Conectar un debugger al servicio booking para inspeccionar el flujo SAGA.

### Paso 1: Modificar docker-compose para debug

```bash
# Crear override temporal para debugging
cat > docker-compose.debug.yml << 'EOF'
services:
  booking:
    build:
      args:
        - BUILD_FLAGS=-gcflags="all=-N -l"
    ports:
      - "2345:2345"
    security_opt:
      - "seccomp:unconfined"
    cap_add:
      - SYS_PTRACE
    command: ["dlv", "exec", "/app/booking", "--headless", "--listen=:2345", "--api-version=2", "--accept-multiclient"]
EOF
```

### Paso 2: Iniciar con debug habilitado

```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml \
  -f docker-compose.debug.yml --profile dev up -d booking
```

### Paso 3: Conectar desde VS Code

Agregar a `.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Attach to Booking",
      "type": "go",
      "request": "attach",
      "mode": "remote",
      "remotePath": "/app",
      "port": 2345,
      "host": "127.0.0.1"
    }
  ]
}
```

### Paso 4: Crear un booking y observar breakpoints

```bash
# Trigger el flujo de booking
curl -X POST http://localhost:8082/booking \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "name": "Debug User",
      "email": "debug@test.com",
      "creditCard": {"number": "4242424242424242", "cvc": "123", "exp_month": "12", "exp_year": "2027"}
    },
    "booking": {
      "showtime_id": "sht_001",
      "seats": ["A1", "A2"],
      "totalAmount": 240
    }
  }'
```

---

## Lab 3: Inspeccion de MongoDB

**Objetivo**: Explorar las colecciones y documentos directamente en MongoDB.

### Paso 1: Conectar a mongosh

```bash
task dev:mongo

# O manualmente:
docker exec -it dev-mongo1 mongosh
```

### Paso 2: Explorar bases de datos

```javascript
// Listar databases
show dbs

// Seleccionar database principal
use cinema

// Ver colecciones
show collections

// Explorar peliculas
db.movies.find().pretty()

// Contar documentos
db.movies.countDocuments()
db.showtimes.countDocuments()
```

### Paso 3: Queries utiles

```javascript
// Buscar pelicula por titulo
db.movies.findOne({ title: /Shawshank/i })

// Ver showtimes de hoy
db.showtimes.find({
  start_time: {
    $gte: new Date(),
    $lt: new Date(Date.now() + 24*60*60*1000)
  }
}).pretty()

// Ver bookings recientes
use cinema_booking
db.bookings.find().sort({ created_at: -1 }).limit(5).pretty()

// Ver estado del replica set
rs.status()

// Ver miembros del replica set
rs.conf()
```

### Paso 4: Indices y performance

```javascript
// Ver indices existentes
db.movies.getIndexes()

// Analizar query con explain
db.showtimes.find({ movie_id: "mov_001" }).explain("executionStats")
```

---

## Lab 4: Redis y Seat Holds

**Objetivo**: Entender como funcionan los seat holds con TTL en Redis.

### Paso 1: Conectar a Redis

```bash
task dev:redis

# O manualmente:
docker exec -it dev-redis redis-cli
```

### Paso 2: Crear un hold de asientos

```bash
# Desde otra terminal, crear un hold
curl -X POST http://localhost:3004/seats/hold \
  -H "Content-Type: application/json" \
  -d '{
    "showtime_id": "sht_001",
    "seat_ids": ["C1", "C2"],
    "session_id": "lab_session_001"
  }'
```

### Paso 3: Inspeccionar keys en Redis

```bash
# En redis-cli
KEYS seat:hold:*

# Ver contenido de un hold
GET seat:hold:sht_001:C1

# Ver TTL restante (en segundos)
TTL seat:hold:sht_001:C1

# Monitorear expiraciones en tiempo real
MONITOR
```

### Paso 4: Simular expiracion

```bash
# Reducir TTL manualmente para testing
EXPIRE seat:hold:sht_001:C1 5

# Esperar 5 segundos y verificar
TTL seat:hold:sht_001:C1
# Retorna -2 (key expirada)

# Verificar que el asiento esta disponible
curl http://localhost:3004/seats/availability?showtime_id=sht_001
```

### Paso 5: Ver sesiones activas

```bash
# Ver todas las sesiones
KEYS session:*

# Ver rate limiting (si esta implementado)
KEYS rate:*
```

---

## Lab 5: NATS Messaging

**Objetivo**: Observar eventos en tiempo real entre microservicios.

### Paso 1: Instalar nats-cli (si no lo tienes)

```bash
# macOS
brew install nats-io/nats-tools/nats

# Linux
curl -L https://github.com/nats-io/natscli/releases/download/v0.1.1/nats-0.1.1-linux-amd64.zip -o nats.zip
unzip nats.zip && sudo mv nats /usr/local/bin/
```

### Paso 2: Conectar y listar streams

```bash
# Ver informacion del servidor
nats server info -s localhost:4222

# Listar streams (JetStream)
nats stream ls -s localhost:4222

# Ver consumidores
nats consumer ls -s localhost:4222 STREAM_NAME
```

### Paso 3: Subscribirse a eventos

```bash
# Subscribirse a eventos de booking
nats sub "booking.>" -s localhost:4222

# En otra terminal, crear un booking
curl -X POST http://localhost:8082/booking ...

# Veras eventos como:
# booking.created
# payment.processed
# seats.confirmed
# notification.sent
```

### Paso 4: Publicar evento de prueba

```bash
# Publicar evento de test
nats pub "test.event" "Hello from lab!" -s localhost:4222
```

---

## Lab 6: Pruebas Manuales con curl

**Objetivo**: Ejecutar el flujo completo de booking manualmente.

### Paso 1: Registrar usuario

```bash
curl -X POST http://localhost:8004/users/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Lab User",
    "email": "lab@cinema.local",
    "password": "Lab123!@#",
    "phone": "+52 55 1234 5678"
  }' | jq
```

### Paso 2: Login y obtener token

```bash
TOKEN=$(curl -s -X POST http://localhost:8004/users/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "lab@cinema.local",
    "password": "Lab123!@#"
  }' | jq -r '.access_token')

echo "Token: $TOKEN"
```

### Paso 3: Listar peliculas

```bash
curl -s http://localhost:8000/movies \
  -H "Authorization: Bearer $TOKEN" | jq '.movies[0]'
```

### Paso 4: Ver showtimes

```bash
MOVIE_ID=$(curl -s http://localhost:8000/movies | jq -r '.movies[0].id')

curl -s "http://localhost:3003/showtimes?movie_id=$MOVIE_ID" | jq
```

### Paso 5: Ver disponibilidad de asientos

```bash
SHOWTIME_ID="sht_001"

curl -s "http://localhost:3004/seats/availability?showtime_id=$SHOWTIME_ID" | jq
```

### Paso 6: Hold de asientos

```bash
SESSION_ID="manual_$(date +%s)"

HOLD_RESPONSE=$(curl -s -X POST http://localhost:3004/seats/hold \
  -H "Content-Type: application/json" \
  -d "{
    \"showtime_id\": \"$SHOWTIME_ID\",
    \"seat_ids\": [\"D1\", \"D2\"],
    \"session_id\": \"$SESSION_ID\"
  }")

HOLD_ID=$(echo $HOLD_RESPONSE | jq -r '.hold_id')
echo "Hold ID: $HOLD_ID"
```

### Paso 7: Crear booking con pago

```bash
curl -X POST http://localhost:8082/booking \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"user\": {
      \"name\": \"Lab User\",
      \"lastName\": \"Test\",
      \"email\": \"lab@cinema.local\",
      \"phoneNumber\": \"+52 55 1234 5678\",
      \"creditCard\": {
        \"number\": \"4242424242424242\",
        \"cvc\": \"123\",
        \"exp_month\": \"12\",
        \"exp_year\": \"2027\"
      }
    },
    \"booking\": {
      \"showtime_id\": \"$SHOWTIME_ID\",
      \"hold_id\": \"$HOLD_ID\",
      \"session_id\": \"$SESSION_ID\",
      \"seats\": [\"D1\", \"D2\"],
      \"totalAmount\": 240
    }
  }" | jq
```

---

## Lab 7: Resiliencia de MongoDB Replica Set

**Objetivo**: Probar failover automatico del replica set MongoDB.

### Paso 1: Verificar estado inicial

```bash
# Conectar y ver estado
docker exec -it dev-mongo1 mongosh --eval "rs.status()"
```

### Paso 2: Identificar el primary

```bash
docker exec -it dev-mongo1 mongosh --eval "rs.isMaster()" | grep primary
```

### Paso 3: Simular caida del primary

```bash
# Detener el nodo primary (asumiendo es mongo1)
docker stop dev-mongo1

# Esperar 10-15 segundos para eleccion
sleep 15

# Verificar nuevo primary
docker exec -it dev-mongo2 mongosh --eval "rs.isMaster()" | grep primary
```

### Paso 4: Verificar que la aplicacion sigue funcionando

```bash
# Los servicios deben seguir respondiendo
curl -s http://localhost:8000/movies | jq '.movies | length'

# Crear un nuevo booking
curl -X POST http://localhost:8082/booking ...
```

### Paso 5: Recuperar el nodo caido

```bash
# Reiniciar mongo1
docker start dev-mongo1

# Verificar que se sincroniza
docker exec -it dev-mongo1 mongosh --eval "rs.status().members"
```

### Paso 6: Probar escrituras durante failover

```bash
# Script para probar continuidad
for i in {1..20}; do
  echo "Request $i:"
  curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000/movies
  sleep 0.5
done
```

---

## Lab 8: Performance Testing con k6

**Objetivo**: Ejecutar pruebas de carga contra el stack local.

### Paso 1: Instalar k6

```bash
# macOS
brew install k6

# Linux
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6
```

### Paso 2: Crear script de prueba

```bash
cat > tests/performance/booking_flow.js << 'EOF'
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up
    { duration: '1m', target: 10 },   // Stay
    { duration: '30s', target: 0 },   // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    errors: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8000';

export default function () {
  // Browse movies
  const moviesRes = http.get(`${BASE_URL}/movies`);
  check(moviesRes, {
    'movies status 200': (r) => r.status === 200,
    'movies has data': (r) => JSON.parse(r.body).movies.length > 0,
  }) || errorRate.add(1);

  sleep(1);

  // Get showtimes
  const showtimesRes = http.get('http://localhost:3003/showtimes');
  check(showtimesRes, {
    'showtimes status 200': (r) => r.status === 200,
  }) || errorRate.add(1);

  sleep(1);
}
EOF
```

### Paso 3: Ejecutar prueba de carga

```bash
task perf:baseline

# O manualmente:
k6 run tests/performance/booking_flow.js
```

### Paso 4: Analizar resultados

```
          /\      |‾‾| /‾‾/   /‾‾/
     /\  /  \     |  |/  /   /  /
    /  \/    \    |     (   /   ‾‾\
   /          \   |  |\  \ |  (‾)  |
  / __________ \  |__| \__\ \_____/

  execution: local
     script: tests/performance/booking_flow.js
     output: -

  scenarios: (100.00%) 1 scenario, 10 max VUs, 2m30s max duration

     ✓ movies status 200
     ✓ movies has data
     ✓ showtimes status 200

     checks.........................: 100.00% ✓ 600  ✗ 0
     http_req_duration..............: avg=45.23ms p(95)=89.12ms
```

---

## Lab 9: Contract Testing Local

**Objetivo**: Verificar contratos Pact entre servicios.

### Paso 1: Ejecutar tests de consumer

```bash
task test:contract:consumer

# O manualmente:
cd tests/contracts/consumer
go test -v ./...
```

### Paso 2: Verificar contratos contra providers

```bash
# Asegurar que dev:up esta corriendo
task dev:up

# Ejecutar verificacion
task test:contract:verify
```

### Paso 3: Ver contratos generados

```bash
# Los contratos estan en:
ls -la services/booking/contracts/pacts/

# Ver contenido de un contrato
cat services/booking/contracts/pacts/booking-payment.json | jq
```

### Paso 4: Modificar y re-verificar

```bash
# Edita un contrato y verifica que falla
# Luego restaura y verifica que pasa
```

---

## Lab 10: Seed Data Persistente

**Objetivo**: Cargar datos de prueba que persisten entre sesiones.

### Paso 1: Crear script de seed

```bash
cat > scripts/seed-dev-data.js << 'EOF'
// seed-dev-data.js - Datos para desarrollo
db = db.getSiblingDB('cinema');

// Limpiar datos existentes
db.movies.deleteMany({});
db.showtimes.deleteMany({});

// Insertar peliculas de prueba
db.movies.insertMany([
  {
    _id: "mov_interstellar",
    id: "mov_interstellar",
    title: "Interstellar",
    director: "Christopher Nolan",
    duration: 169,
    genre: ["Sci-Fi", "Drama"],
    rating: "PG-13",
    releaseDate: new Date("2014-11-07"),
    poster: "https://example.com/interstellar.jpg",
    status: "showing"
  },
  {
    _id: "mov_inception",
    id: "mov_inception",
    title: "Inception",
    director: "Christopher Nolan",
    duration: 148,
    genre: ["Sci-Fi", "Action"],
    rating: "PG-13",
    releaseDate: new Date("2010-07-16"),
    poster: "https://example.com/inception.jpg",
    status: "showing"
  }
]);

// Insertar showtimes
const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
tomorrow.setHours(18, 0, 0, 0);

db.showtimes.insertMany([
  {
    _id: "sht_dev_001",
    id: "sht_dev_001",
    movie_id: "mov_interstellar",
    cinema_id: "cin_001",
    room: "Sala 1",
    start_time: tomorrow,
    end_time: new Date(tomorrow.getTime() + 169*60000),
    price: 120,
    available_seats: 100,
    status: "scheduled"
  }
]);

print("Seed data loaded successfully!");
print("Movies: " + db.movies.countDocuments());
print("Showtimes: " + db.showtimes.countDocuments());
EOF
```

### Paso 2: Ejecutar seed

```bash
task dev:seed

# O manualmente:
docker exec -i dev-mongo1 mongosh < scripts/seed-dev-data.js
```

### Paso 3: Verificar datos

```bash
curl -s http://localhost:8000/movies | jq '.movies[] | {id, title}'
```

### Paso 4: Los datos persisten

```bash
# Reiniciar el entorno
task dev:down
task dev:up

# Los datos siguen ahi (volumenes persistentes)
curl -s http://localhost:8000/movies | jq '.movies | length'
```

---

## Troubleshooting

### Servicios no inician

```bash
# Ver logs de un servicio especifico
task dev:log SERVICE=booking

# Ver logs de todos
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev logs -f
```

### MongoDB no conecta

```bash
# Verificar estado del replica set
docker exec -it dev-mongo1 mongosh --eval "rs.status()"

# Reinicializar replica set
docker exec -it dev-mongo1 mongosh --eval "rs.initiate()"
```

### Puerto ocupado

```bash
# Ver que proceso usa el puerto
lsof -i :8000

# Matar proceso
kill -9 <PID>
```

### Limpiar todo y empezar de cero

```bash
# Eliminar todos los contenedores y volumenes
task dev:down
docker volume prune -f
docker network prune -f

# Reiniciar
task dev:up
```

### Rebuild forzado

```bash
# Rebuild sin cache
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev build --no-cache
task dev:up
```

---

## Comandos Rapidos de Referencia

```bash
# Iniciar/detener
task dev:up
task dev:down

# Logs
task dev:log SERVICE=booking

# Shell en servicio
task dev:shell SERVICE=booking

# MongoDB
task dev:mongo

# Redis
task dev:redis

# Estado
task dev:status

# Seed
task dev:seed

# Performance
task perf:baseline
```

---

## Siguiente: test:e2e

Una vez que hayas validado tu codigo manualmente con `dev:up`, ejecuta:

```bash
task test:e2e
```

Para validar automaticamente todo el flujo de booking en un entorno efimero.
