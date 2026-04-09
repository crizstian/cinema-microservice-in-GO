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
