# MongoDB Replica Set - Cambios Aplicados

## 📋 Resumen

Este documento detalla los cambios aplicados para corregir y mejorar la configuración del MongoDB Replica Set basado en el análisis documentado en [MONGODB-VALIDATION.md](./MONGODB-VALIDATION.md).

**Fecha**: 2026-01-23
**Branch**: step12-multi-vm-cluster

---

## ✅ Cambios Aplicados

### 🔴 Prioridad ALTA (Completados)

#### 1. Corregir configuración de IPs en mongo3

**Archivo**: `deploy/docker-compose/docker-compose.yml`

**Problema**: Las variables de entorno DB1, DB2, DB3 estaban en orden inverso en el nodo mongo3.

```diff
  mongo3:
    environment:
-     DB3: "10.7.0.3"
-     DB2: "10.7.0.4"
-     DB1: "10.7.0.5"
+     DB1: "10.7.0.3"
+     DB2: "10.7.0.4"
+     DB3: "10.7.0.5"
```

**Impacto**: Elimina confusión en la topología del cluster y facilita el debugging.

---

#### 2. Añadir healthchecks a contenedores MongoDB

**Archivo**: `deploy/docker-compose/docker-compose.yml`

**Cambio**: Agregado healthcheck a los 3 nodos MongoDB (mongo1, mongo2, mongo3).

```yaml
healthcheck:
  test: ["CMD", "mongo", "--eval", "db.adminCommand('ping')"]
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 40s
```

**Beneficios**:
- Docker Compose espera a que MongoDB esté listo antes de marcar el contenedor como "healthy"
- Facilita orquestación con depends_on: condition: service_healthy
- Permite monitoreo del estado de salud desde Docker

---

#### 3. Añadir restart policies a MongoDB

**Archivo**: `deploy/docker-compose/docker-compose.yml`

**Cambio**: Agregado `restart: unless-stopped` a los 3 nodos.

```yaml
mongo1:
  restart: unless-stopped
```

**Beneficio**: Los contenedores MongoDB se reinician automáticamente en caso de crash, aumentando la disponibilidad.

---

#### 4. Corregir struct MongoConnection en payment-service

**Archivo**: `payment-service/src/db/mgo.go`

**Problema**: El struct MongoConnection no incluía el campo `Err`, a diferencia de booking-service y movie-service.

```diff
  type MongoConnection struct {
      DB      *mgo.Database
      Session *mgo.Session
+     Err     error
  }
```

**Cambio en función MongoDB**:

```diff
  c <- &MongoConnection{
      Session: session,
      DB:      session.DB(options.Db),
+     Err:     err,
  }
```

**Beneficio**: Consistencia entre servicios y permite manejar errores de conexión sin panic.

---

### 🟡 Prioridad MEDIA (Completados)

#### 5. Validar env vars obligatorias en movie-service

**Archivo**: `movie-service/src/db/mgo.go`

**Problema**: El servicio imprimía warnings pero continuaba ejecutando con valores vacíos.

```diff
  if !uok {
      fmt.Println("No DB user specified")
  }
  // ... más checks individuales

+ if !uok || !pok || !sok || !nok || !rok {
+     log.Fatal("Missing required MongoDB environment variables")
+ }

  conn.User = u
  conn.Pass = p
  // ...
```

**Beneficio**: El servicio falla rápido (fail-fast) si faltan variables críticas, evitando errores confusos más adelante.

---

#### 6. Mejorar health checks en initMongo.sh

**Archivo**: `cinemas-db/startup/initMongo.sh`

**Cambio 1**: Descomentar y mejorar función `wait_for`

```diff
- # function wait_for {
- #   echo ">>>>>>>>>>> waiting for mongodb"
- #   ...
- # }
+ function wait_for {
+   echo ">>>>>>>>>>> waiting for mongodb at $1:$2"
+   start_ts=$(date +%s)
+   while :
+   do
+     (echo > /dev/tcp/$1/$2) >/dev/null 2>&1
+     result=$?
+     if [[ $result -eq 0 ]]; then
+         end_ts=$(date +%s)
+         echo "<<<<< $1:$2 is available after $((end_ts - start_ts)) seconds"
+         sleep 3
+         break
+     fi
+     sleep 2
+   done
+ }
```

**Cambio 2**: Mejorar función `wait_for_databases`

```diff
  function wait_for_databases {
-   # make tcp call
-   echo "IP == $IP PORT == $DB_PORT"
-   # wait_for "$IP" $DB_PORT
+   # Wait for all provided MongoDB instances
+   for ip in "$@"; do
+     # Extract IP without port
+     server_ip=$(echo $ip | cut -d':' -f1)
+     echo "Waiting for MongoDB at $server_ip:$DB_PORT"
+     wait_for "$server_ip" "$DB_PORT"
+   done
+   echo "All MongoDB instances are ready"
  }
```

**Cambio 3**: Usar health checks antes de añadir réplicas

```diff
  function add_replicas {
    echo '·· adding replicas >>>> ··'

+   # Wait for all nodes to be ready first
+   wait_for_databases $DB1 $DB2 $DB3
+
    # add nuppdb replicas
    for server in $DB1 $DB2 $DB3
    do
      rs="rs.add('$server')"
      add='mongo --eval "'$rs'" -u '$DB_REPLICA_ADMIN' -p '$DB_REPLICA_ADMIN_PASS' --authenticationDatabase="admin"'
-     echo ">>>>>>>>>>> waiting for mongodb server $server to be ready"
-     sleep 5
-     wait_for_databases $server
+     echo ">>>>>>>>>>> adding mongodb server $server to replica set"
      bash -c "$add"
+     sleep 2
    done
  }
```

**Beneficios**:
- Reemplaza sleeps arbitrarios por health checks reales basados en TCP
- Espera a que TODOS los nodos estén listos antes de iniciar rs.add()
- Reduce race conditions durante la inicialización
- Logs más informativos con timestamps

---

### 🆕 Nuevos Archivos Creados

#### 7. Script de validación MongoDB

**Archivo**: `scripts/validate-mongodb.sh`

Script automatizado que verifica:
1. ✅ Contenedores MongoDB corriendo
2. ✅ Estado de health checks
3. ✅ Replica set inicializado (rs.status().ok == 1)
4. ✅ Configuración del replica set (nombre, miembros)
5. ✅ Estados de miembros (PRIMARY/SECONDARY)
6. ✅ Conexión desde microservicios

**Uso**:
```bash
bash scripts/validate-mongodb.sh
```

**Salida esperada**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Validación MongoDB Replica Set - Cinemas Microservices
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1/6] Verificando contenedores MongoDB...
✅ 3 contenedores MongoDB encontrados

[2/6] Verificando health checks...
   ✅ mongo1: healthy
   ✅ mongo2: healthy
   ✅ mongo3: healthy

[3/6] Verificando estado del replica set...
✅ Replica set inicializado correctamente

[4/6] Verificando configuración del replica set...
Replica Set Name: rs1
Members:
  - 10.7.0.5:27017 (priority: 1)
  - 10.7.0.3:27017 (priority: 1)
  - 10.7.0.4:27017 (priority: 1)

[5/6] Verificando miembros del replica set...
   ✅ 10.7.0.5:27017 | PRIMARY | health:1
   ✅ 10.7.0.3:27017 | SECONDARY | health:1
   ✅ 10.7.0.4:27017 | SECONDARY | health:1

[6/6] Verificando conexión desde microservicios...
   ✅ movie: conexión detectada
   ✅ payment: conexión detectada
   ✅ booking: conexión detectada

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Validación completada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

#### 8. Documentación de validación

**Archivo**: `docs/MONGODB-VALIDATION.md`

Análisis completo que incluye:
- 🔍 Análisis de la configuración actual
- ❌ Issues críticos identificados
- ✅ Aspectos correctos
- 🎯 Recomendaciones priorizadas (ALTA/MEDIA/BAJA)
- ✅ Comandos de validación
- 📊 Matriz de riesgos
- 📚 Referencias

---

## 📊 Resumen de Impacto

| Componente | Archivos Modificados | Líneas Cambiadas | Impacto |
|------------|---------------------|------------------|---------|
| **Docker Compose** | 1 | +15 líneas | 🔴 ALTO - Healthchecks + restart policies |
| **payment-service** | 1 | +2 líneas | 🔴 ALTO - Consistencia de structs |
| **movie-service** | 1 | +4 líneas | 🟡 MEDIO - Fail-fast en config |
| **cinemas-db init** | 1 | ~30 líneas | 🟡 MEDIO - Health checks reales |
| **Scripts** | 1 nuevo | +140 líneas | 🟢 BAJO - Tooling de validación |
| **Docs** | 2 nuevos | +500 líneas | 🟢 BAJO - Documentación |

**Total**: 7 archivos afectados, ~191 líneas de código productivo, ~500 líneas de documentación.

---

## 🧪 Testing Recomendado

### 1. Test básico de inicialización

```bash
# 1. Limpiar estado anterior
cd deploy/docker-compose
docker-compose down -v

# 2. Levantar cluster
docker-compose up -d mongo1 mongo2 mongo3

# 3. Esperar a healthchecks (40s start_period + tiempo de init)
sleep 60

# 4. Validar
bash ../../scripts/validate-mongodb.sh
```

### 2. Test de failover

```bash
# 1. Identificar PRIMARY actual
docker exec $(docker-compose ps -q mongo3) mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"

# 2. Detener PRIMARY (asumiendo que es mongo3)
docker-compose stop mongo3

# 3. Esperar elección (~10-30s)
sleep 30

# 4. Verificar nuevo PRIMARY
docker exec $(docker-compose ps -q mongo1) mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"

# 5. Verificar que servicios siguen funcionando
curl http://localhost:8000/api/movies
curl http://localhost:8300/api/bookings

# 6. Restaurar cluster
docker-compose start mongo3
```

### 3. Test de conexión de servicios

```bash
# Levantar stack completo
docker-compose up -d

# Verificar logs de conexión
docker-compose logs booking | grep -i "connecting"
docker-compose logs movie | grep -i "connecting"
docker-compose logs payment | grep -i "connecting"

# Probar endpoints
curl http://localhost:8000/api/movies
curl http://localhost:8100/payments
curl http://localhost:8300/bookings
```

---

## 🚀 Próximos Pasos Sugeridos

### Mejoras Futuras (No implementadas)

#### 1. Resource Limits (Prioridad BAJA)

```yaml
mongo1:
  deploy:
    resources:
      limits:
        cpus: '1'
        memory: 1G
      reservations:
        memory: 512M
```

#### 2. TLS/SSL para conexiones (Prioridad BAJA)

- Requerir certificados para autenticación client-server
- Ver: https://www.mongodb.com/docs/manual/tutorial/configure-ssl/

#### 3. Migrar a driver oficial MongoDB Go (Prioridad BAJA)

El driver `mgo.v2` está deprecado. Considerar migración a:
```go
go.mongodb.org/mongo-driver/mongo
```

#### 4. Monitoring con Prometheus + Grafana (Prioridad BAJA)

- Descomentar servicios en docker-compose.yml
- Configurar MongoDB exporter
- Crear dashboards de métricas del replica set

---

## 📝 Notas Finales

### Compatibilidad Backward

✅ **Todos los cambios son backward compatible**:
- Docker Compose sigue funcionando igual
- Servicios usan mismas variables de entorno
- No se modificó lógica de negocio

### Validación Pre-Deploy

Antes de hacer deploy a producción:

1. ✅ Ejecutar `bash scripts/validate-mongodb.sh`
2. ✅ Probar failover manual
3. ✅ Verificar backups de MongoDB funcionan
4. ✅ Documentar runbook de operaciones
5. ⚠️ Cambiar credenciales hardcodeadas por secrets management (Vault)

### Referencias Cruzadas

- Análisis completo: [docs/MONGODB-VALIDATION.md](./MONGODB-VALIDATION.md)
- Build de imágenes: [docs/DOCKER-BUILD.md](./DOCKER-BUILD.md)
- README principal: [README.md](../README.md)

---

**Autor**: Claude Sonnet 4.5
**Proyecto**: Cinemas Microservices - Go Monorepo
**Versión**: 1.0
