# ⚡ Implementación Rápida - Solución SIGSEGV Docker + MongoDB

## 🎯 Resumen Ejecutivo

**Problema**: SIGSEGV en `runtime.netpoll_epoll.go` cuando los servicios corren en Docker

**Causa**:
- DB_SERVERS mal configurado (puerto repetido 3 veces)
- Uso de IP externa desde dentro de Docker
- Sin retry logic ni validación de DNS
- Timeouts muy cortos

**Solución**: Driver MongoDB robusto + Docker Compose corregido + Dockerfiles optimizados

## 🚀 Implementación en 5 Pasos (15 minutos)

### Paso 1: Aplicar el driver mejorado ✅ LISTO
```bash
# Ya está aplicado en:
# - services/movie/internal/db/mongo.go
# - services/booking/internal/db/mongo.go
# - services/payment/internal/db/mongo.go
```

### Paso 2: Crear Dockerfiles ✅ LISTO
```bash
# Ya están creados:
# - services/movie/Dockerfile
# - services/booking/Dockerfile
# - services/payment/Dockerfile
```

### Paso 3: Aplicar docker-compose corregido
```bash
cd platform/deploy/docker-compose

# Backup del actual
cp docker-compose.yml docker-compose.backup.yml

# Aplicar el corregido
cp docker-compose.fixed.yml docker-compose.yml
```

### Paso 4: Rebuild y Deploy
```bash
# Opción A: Usar script automático (RECOMENDADO)
cd /workspace
./deploy-fixed.sh

# Opción B: Manual
cd platform/deploy/docker-compose

# Detener todo
docker-compose down

# Rebuild sin caché
docker-compose build --no-cache movie payment booking

# Iniciar MongoDB
docker-compose up -d mongo1 mongo2 mongo3
sleep 20
docker-compose up mongo-init

# Iniciar servicios
docker-compose up -d movie payment booking notification
```

### Paso 5: Verificar
```bash
# Ver estado
docker-compose ps

# Health checks
curl http://localhost:8000/health  # movie
curl http://localhost:8100/health  # payment
curl http://localhost:8300/health  # booking

# Verificar logs (NO debe haber SIGSEGV)
docker-compose logs movie | grep -i sigsegv
docker-compose logs movie | grep "Successfully connected"

# Deberías ver:
# INFO Successfully connected to MongoDB primary (attempt 1)
# INFO Successfully connected to MongoDB!
```

## 📋 Cambios Principales

### 1. DB_SERVERS Corregido

**❌ ANTES**:
```yaml
environment:
  DB_SERVERS: "192.168.68.104:27017,192.168.68.104:27017,192.168.68.104:27017"
```

**✅ AHORA**:
```yaml
environment:
  DB_SERVERS: "mongo1:27017,mongo2:27017,mongo3:27017"  # Nombres de servicio Docker
```

### 2. Driver con Retry Logic

```go
// 3 intentos con fallback strategy
for attempt := 1; attempt <= 3; attempt++ {
    // 1. Try Primary
    pingErr = client.Ping(pingCtx, readpref.Primary())

    // 2. Try PrimaryPreferred
    if pingErr != nil {
        pingErr = client.Ping(pingCtx, readpref.PrimaryPreferred())
    }

    // 3. Try Nearest
    if pingErr != nil {
        pingErr = client.Ping(pingCtx, readpref.Nearest())
    }

    if pingErr == nil {
        break  // Success!
    }

    time.Sleep(2 * time.Second)
}
```

### 3. Validación de DNS

```go
// Validar que los hosts sean resolvibles ANTES de conectar
for _, server := range serverList {
    if err := validateHost(host); err != nil {
        log.Warnf("Server %s might not be reachable: %v", server, err)
    }
}
```

### 4. Health Checks en Docker

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 5. Dependencias Correctas

```yaml
depends_on:
  mongo-init:
    condition: service_completed_successfully  # Espera a que termine la init
  payment:
    condition: service_healthy  # Espera a que esté healthy
```

## 🔍 Verificación de Éxito

### ✅ Checklist
- [ ] No hay SIGSEGV en logs: `docker-compose logs movie | grep SIGSEGV` (sin resultados)
- [ ] Conexión exitosa: `docker-compose logs movie | grep "Successfully connected"`
- [ ] Health checks pasan: `curl http://localhost:8000/health` → 200 OK
- [ ] Servicios healthy: `docker-compose ps` → (healthy) para todos
- [ ] MongoDB replica set OK: `docker exec mongo1 mongosh -u cristian -p cristianPassword2017 --authenticationDatabase admin --eval "rs.status()"`

### 📊 Logs Esperados

**✅ Correcto**:
```
INFO Connecting to MongoDB: mongodb://cristian:****@mongo1:27017,mongo2:27017,mongo3:27017/movies?replicaSet=rs1
INFO Establishing MongoDB connection...
INFO Pinging MongoDB to verify connection...
INFO Successfully connected to MongoDB primary (attempt 1)
INFO Successfully connected to MongoDB!
INFO Connected to DB
INFO Starting Movie Service now ...
```

**❌ Incorrecto** (Si sigues viendo esto, hay un problema):
```
INFO Connecting to MongoDB...
INFO Pinging MongoDB...
SIGSEGV: segmentation violation
PC=0x43116e m=8 sigcode=1
```

## 🛠️ Troubleshooting Rápido

### Problema: "no such host: mongo1"
```bash
# Verificar que está en la misma red
docker network inspect docker-compose_dc1

# Debería mostrar mongo1, mongo2, mongo3, movie, etc.
```

### Problema: "authentication failed"
```bash
# Reinicializar MongoDB
docker-compose down -v
docker-compose up -d mongo1 mongo2 mongo3
sleep 20
docker-compose up mongo-init
```

### Problema: SIGSEGV persiste
```bash
# Limpiar TODO
docker-compose down -v
docker system prune -af --volumes
docker-compose build --no-cache
docker-compose up
```

### Problema: Timeouts
```bash
# Aumentar timeouts en el código (ya están en 30s/60s)
# Verificar que MongoDB está realmente listo
docker exec mongo1 mongosh --eval "rs.status()"
```

## 📁 Archivos Importantes

| Archivo | Propósito |
|---------|-----------|
| `services/*/internal/db/mongo.go` | Driver MongoDB mejorado |
| `services/*/Dockerfile` | Build optimizado multi-stage |
| `docker-compose.fixed.yml` | Configuración corregida |
| `deploy-fixed.sh` | Script de deployment automático |
| `SOLUCION-DOCKER-MONGODB.md` | Documentación completa |
| `.env.example` | Variables de entorno |

## ⚠️ IMPORTANTE

1. **Usar nombres de servicio en Docker**: `mongo1:27017` NO `192.168.68.104:27017`
2. **Esperar a mongo-init**: Usar `condition: service_completed_successfully`
3. **Health checks**: Todos los servicios deben tener health check
4. **Retry logic**: El driver ahora hace 3 intentos automáticamente
5. **Logs**: Verificar siempre los logs después del deploy

## 🎉 Resultado Final

```bash
$ docker-compose ps
NAME         STATUS              PORTS
mongo1       Up (healthy)        0.0.0.0:27017->27017/tcp
mongo2       Up (healthy)        0.0.0.0:27018->27017/tcp
mongo3       Up (healthy)        0.0.0.0:27019->27017/tcp
movie        Up (healthy)        0.0.0.0:8000->8000/tcp
payment      Up (healthy)        0.0.0.0:8100->8000/tcp
booking      Up (healthy)        0.0.0.0:8300->8000/tcp

$ curl http://localhost:8000/health
{"status":"ok"}

$ docker logs movie 2>&1 | grep -E "(SIGSEGV|Successfully)"
INFO Successfully connected to MongoDB primary (attempt 1)
INFO Successfully connected to MongoDB!
```

**✅ Sin SIGSEGV, con conexión exitosa = PROBLEMA RESUELTO** 🚀
