# Debugging Runbook

> Guia rapida para diagnosticar y resolver problemas comunes en el stack Cinema Microservices.

## Tabla de Contenidos

- [Diagnostico Rapido](#diagnostico-rapido)
- [Problemas de Servicios](#problemas-de-servicios)
- [Problemas de MongoDB](#problemas-de-mongodb)
- [Problemas de Redis](#problemas-de-redis)
- [Problemas de NATS](#problemas-de-nats)
- [Problemas de Red](#problemas-de-red)
- [Problemas de E2E Tests](#problemas-de-e2e-tests)
- [Comandos Utiles](#comandos-utiles)

---

## Diagnostico Rapido

### Paso 1: Ver estado de contenedores

```bash
task dev:status
# o
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps -a
```

**Buscar:**
- Status "unhealthy" o "exited"
- Restart count alto
- Puertos no mapeados

### Paso 2: Health check rapido

```bash
# Script de verificacion
for port in 8000 8001 8002 8004 8082 8085 3003 3004; do
  echo -n "Port $port: "
  curl -s -o /dev/null -w "%{http_code}" http://localhost:$port/ping || echo "FAIL"
  echo ""
done
```

### Paso 3: Ver logs de errores

```bash
# Ultimos errores de todos los servicios
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev logs --tail=50 2>&1 | grep -i error
```

---

## Problemas de Servicios

### Servicio no inicia

**Sintomas:**
- Container en estado "restarting" o "exited"
- Health check failing

**Diagnostico:**
```bash
# Ver logs del servicio
task dev:log SERVICE=booking

# Ver eventos de Docker
docker events --filter container=cinema-booking --since 5m
```

**Causas comunes:**

1. **MongoDB no disponible**
   ```bash
   # Verificar MongoDB
   docker exec -it dev-mongo1 mongosh --eval "rs.status()"
   ```

2. **Variables de entorno faltantes**
   ```bash
   # Ver variables del contenedor
   docker inspect cinema-booking | jq '.[0].Config.Env'
   ```

3. **Puerto ocupado**
   ```bash
   lsof -i :8082
   ```

**Solucion:**
```bash
# Restart individual
docker compose -f platform/deploy/docker-compose/docker-compose.yml restart booking

# Rebuild forzado
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d --build --force-recreate booking
```

### Servicio responde lento

**Diagnostico:**
```bash
# Medir tiempo de respuesta
time curl -s http://localhost:8082/health

# Ver metricas del contenedor
docker stats cinema-booking --no-stream
```

**Causas comunes:**

1. **CPU/Memory alta**
   ```bash
   docker stats --no-stream | sort -k 3 -h -r | head -5
   ```

2. **Queries MongoDB lentas**
   ```javascript
   // En mongosh
   db.setProfilingLevel(1, { slowms: 100 })
   db.system.profile.find().sort({ ts: -1 }).limit(5)
   ```

3. **Conexiones agotadas**
   ```bash
   # Ver conexiones activas
   ss -tunap | grep :8082 | wc -l
   ```

### Health Check falla con HTTP 000

**Sintomas:**
```bash
task dev:health
# Output:
# cinema          :8003  /health/live         FAIL (HTTP 000)
# seat            :8005  /health/live         FAIL (HTTP 000)
```

**Diagnostico:**
```bash
# 1. Ver estado de containers
task dev:status

# 2. Buscar containers con estado != "Up" o "healthy"
#    - "Restarting (1)" → crash loop
#    - "Exited (1)"     → falló al iniciar

# 3. Ver logs del servicio fallido
docker logs dev-cinema --tail 50
docker logs dev-seat --tail 50

# Patrones de error comunes:
#   "connection refused"      → dependencia no disponible
#   "no reachable servers"    → MongoDB no inicializado
#   "ReplicaSetNoPrimary"     → MongoDB sin PRIMARY
#   "context deadline"        → timeout conectando a DB
```

**Causas y Soluciones:**

1. **MongoDB no tiene PRIMARY (más común)**
   ```bash
   docker exec dev-mongo1 mongosh --quiet --eval "rs.status().ok"
   # Si retorna 1 → MongoDB OK
   # Si falla o retorna 0 → reiniciar mongo-init
   docker restart dev-mongo-init
   sleep 15
   docker restart dev-cinema dev-seat
   ```

2. **MONGO_SERVERS incorrecto en .env**
   ```bash
   # Verificar
   grep MONGO_SERVERS platform/deploy/docker-compose/.env
   # Para dev profile debe ser: MONGO_SERVERS=mongo1:27017
   # Si falta, añadir y reiniciar
   echo "MONGO_SERVERS=mongo1:27017" >> platform/deploy/docker-compose/.env
   task dev:down && task dev:up
   ```

3. **Race condition al iniciar**
   ```bash
   # Los servicios iniciaron antes de que mongo-init completara
   docker restart dev-cinema dev-seat
   sleep 10
   task dev:health
   ```

### Booking falla con PAYMENT_FAILED

**Sintomas:**
```json
{
  "code": "PAYMENT_FAILED",
  "message": "Payment processing failed",
  "details": { "error": "Post \"http://payment:8007/payment/makePurchase\": EOF" }
}
```

**Diagnostico:**
```bash
# Ver logs de payment
docker logs dev-payment --tail 30

# Buscar panic o errores
docker logs dev-payment 2>&1 | grep -E "panic|error|Error"
```

**Causas y Soluciones:**

1. **Payment service crasheando (panic)**
   ```bash
   # Verificar si hay panic en logs
   docker logs dev-payment 2>&1 | grep -A5 "panic"
   
   # Si hay panic, rebuild el servicio
   cd services/payment && go build -o payment ./cmd/payment && cd ../..
   docker build --no-cache -f platform/docker/go-service/Dockerfile \
     --build-arg SERVICE_NAME=payment --build-arg SERVICE_PORT=8007 \
     -t crizstian/payment-service:dev .
   docker rm -f dev-payment
   docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d payment
   ```

2. **Request con formato incorrecto**
   ```bash
   # El booking request debe incluir:
   # - user.creditCard (no booking.payment)
   # - booking.totalAmount > 0
   # - booking.seats array
   # Ver formato correcto en docker-compose-deployment-guide.md sección 9.5
   ```

### Premieres endpoint retorna null

**Sintomas:**
```bash
curl http://movie:8002/movies/premieres
# {"movies":null,"msg":"list of movies"}
```

**Causa:** Los campos de fecha en seed data no coinciden con los que busca el API.

**Diagnostico:**
```bash
# Ver campos en la DB
docker exec dev-mongo1 mongosh movie --quiet --eval \
  "db.movies.findOne({}, {title:1, releaseYear:1, releaseMonth:1, releaseDay:1})"

# Si falta releaseYear/Month/Day, el seed data está incorrecto
```

**Solucion:**
```bash
# Re-ejecutar seed con datos correctos
docker exec -i dev-mongo1 mongosh --quiet < platform/docker/mongodb/seed/04-seed-test-data.js
```

---

## Problemas de MongoDB

### Replica set no inicializado

**Sintomas:**
```
MongoServerError: not primary
MongoServerError: no replica set config
```

**Diagnostico:**
```bash
docker exec -it dev-mongo1 mongosh --eval "rs.status()"
```

**Solucion:**
```bash
# Reinicializar replica set
docker exec -it dev-mongo1 mongosh --eval "rs.initiate({
  _id: 'rs0',
  members: [
    { _id: 0, host: 'mongo1:27017' },
    { _id: 1, host: 'mongo2:27017' },
    { _id: 2, host: 'mongo3:27017' }
  ]
})"
```

### No hay primary

**Diagnostico:**
```bash
docker exec -it dev-mongo1 mongosh --eval "rs.isMaster()"
```

**Causas:**
- Menos de 2 nodos disponibles
- Network partition

**Solucion:**
```bash
# Verificar que todos los nodos estan arriba
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps mongo1 mongo2 mongo3

# Forzar eleccion (cuidado en prod!)
docker exec -it dev-mongo1 mongosh --eval "rs.stepDown()"
```

### Datos corruptos

**Sintomas:**
- Errores de checksum
- Colecciones no accesibles

**Solucion (dev only):**
```bash
# Limpiar y reiniciar
task dev:down
docker volume rm cinema_mongo1_data cinema_mongo2_data cinema_mongo3_data
task dev:up
```

---

## Problemas de Redis

### No conecta

**Diagnostico:**
```bash
docker exec -it dev-redis redis-cli ping
```

**Solucion:**
```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml restart redis-dev
```

### Memory full

**Diagnostico:**
```bash
docker exec -it dev-redis redis-cli INFO memory
```

**Solucion:**
```bash
# Limpiar keys expiradas
docker exec -it dev-redis redis-cli FLUSHDB

# O aumentar limite
docker exec -it dev-redis redis-cli CONFIG SET maxmemory 512mb
```

### TTL no expira

**Diagnostico:**
```bash
docker exec -it dev-redis redis-cli DEBUG SLEEP 0
docker exec -it dev-redis redis-cli TTL seat:hold:sht_001:A1
```

**Nota:** Redis expira keys de forma lazy. El TTL puede mostrarse pero la key expira en el proximo acceso.

---

## Problemas de NATS

### No conecta

**Diagnostico:**
```bash
curl http://localhost:8222/healthz
```

**Solucion:**
```bash
docker compose -f platform/deploy/docker-compose/docker-compose.yml restart nats
```

### JetStream no disponible

**Diagnostico:**
```bash
nats server info -s localhost:4222 | grep jetstream
```

**Solucion:**
```bash
# Verificar que JetStream esta habilitado
docker logs cinema-nats | grep -i jetstream
```

---

## Problemas de Red

### Contenedores no se comunican

**Diagnostico:**
```bash
# Verificar red
docker network inspect cinema-dev-network

# Ping entre contenedores
docker exec cinema-booking ping -c 3 payment
```

**Solucion:**
```bash
# Recrear red
docker network rm cinema-dev-network
task dev:up
```

### DNS no resuelve

**Diagnostico:**
```bash
docker exec cinema-booking nslookup mongo1
```

**Solucion:**
```bash
# Restart con --force-recreate
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d --force-recreate
```

---

## Problemas de E2E Tests

### Tests timeout

**Causas:**
1. Servicios no healthy antes de tests
2. MongoDB no inicializado

**Diagnostico:**
```bash
# Ver logs del runner
docker logs test-e2e-runner
```

**Solucion:**
```bash
# Aumentar timeout de espera en test-e2e.sh
# O verificar manualmente:
task dev:up
curl http://localhost:8082/health
task test:e2e
```

### Test de hold falla

**Sintomas:**
- Test05_HoldSeats o Test09_ConcurrentSeatHolds falla

**Diagnostico:**
```bash
# Verificar Redis
docker exec -it test-redis redis-cli KEYS "seat:hold:*"
```

**Causas:**
- Hold previo no expirado
- Redis no limpio

**Solucion:**
```bash
# Limpiar Redis
docker exec -it test-redis redis-cli FLUSHALL
```

---

## Comandos Utiles

### Estado general

```bash
# Todo de un vistazo
task dev:status
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev ps

# Consumo de recursos
docker stats --no-stream

# Logs en vivo
task dev:log
```

### MongoDB

```bash
# Shell
task dev:mongo

# Queries utiles
docker exec -it dev-mongo1 mongosh --eval "db.adminCommand('listDatabases')"
docker exec -it dev-mongo1 mongosh --eval "rs.status().members.map(m => ({name: m.name, state: m.stateStr}))"
```

### Redis

```bash
# Shell
task dev:redis

# Ver todas las keys
docker exec -it dev-redis redis-cli KEYS "*"

# Monitor en vivo
docker exec -it dev-redis redis-cli MONITOR
```

### NATS

```bash
# Info del servidor
nats server info -s localhost:4222

# Subscribir a eventos
nats sub ">" -s localhost:4222
```

### Servicios

```bash
# Shell en un servicio
task dev:shell SERVICE=booking

# Ver logs de un servicio
task dev:log SERVICE=booking

# Rebuild un servicio
docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev up -d --build booking
```

### Limpieza total

```bash
# Parar todo
task dev:down

# Limpiar volumenes
docker volume prune -f

# Limpiar imagenes
docker image prune -f

# Limpiar redes
docker network prune -f

# Reiniciar limpio
task dev:up
```

---

## Escalacion

Si los pasos anteriores no resuelven el problema:

1. **Recopilar informacion:**
   ```bash
   docker compose -f platform/deploy/docker-compose/docker-compose.yml --profile dev logs > debug-logs.txt
   docker inspect $(docker ps -q) > debug-inspect.txt
   ```

2. **Crear issue** en el repositorio con:
   - Descripcion del problema
   - Pasos para reproducir
   - Logs relevantes
   - Output de `docker compose ps`
