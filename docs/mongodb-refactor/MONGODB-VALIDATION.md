# Validación MongoDB Replica Set - Análisis y Recomendaciones

## 📋 Resumen Ejecutivo

Este documento analiza la configuración del MongoDB Replica Set de 3 nodos utilizado por el sistema de microservicios de cinemas.

**Estado General**: ⚠️ Funcional con issues críticos que requieren corrección

---

## 🔍 Análisis de Componentes

### 1. Configuración del Replica Set (docker-compose.yml)

#### Topología Actual

```yaml
mongo1: 10.7.0.3 (puerto 27017) - IS_PRIMARY: false
mongo2: 10.7.0.4 (puerto 27018) - IS_PRIMARY: false
mongo3: 10.7.0.5 (puerto 27019) - IS_PRIMARY: true
```

#### ✅ Aspectos Correctos

- Replica set name consistente: `rs1`
- Credenciales uniformes entre los 3 nodos
- Red aislada con subnet estática (10.7.0.0/16)
- Dependencias correctas (mongo3 depends_on mongo1, mongo2)

#### ❌ Issues Críticos

**CRÍTICO: Configuración de IPs invertida en mongo3**

```yaml
# mongo3 (líneas 54-56) - INCORRECTO ❌
DB3: "10.7.0.3"  # Debería ser DB1
DB2: "10.7.0.4"  # Correcto
DB1: "10.7.0.5"  # Debería ser DB3
```

**Correcto debería ser:**
```yaml
DB1: "10.7.0.3"
DB2: "10.7.0.4"
DB3: "10.7.0.5"
```

**Impacto**:
- Confusión en la topología del cluster
- Dificultad para debugging y troubleshooting
- Riesgo de errores al añadir réplicas

---

### 2. Inicialización del Replica Set

#### Archivos Clave

```
cinemas-db/
├── startup/
│   ├── pre-start.sh          # Entrypoint principal
│   ├── startProcess.sh       # Obtiene keyfile, inicia mongod
│   ├── mongoStart.sh         # Coordinación con Consul
│   ├── initMongo.sh          # Lógica de inicialización
│   └── startWithConfig.sh    # Inicia mongod con keyfile
└── files/
    ├── replica.js.ctmpl      # Template rs.initiate()
    ├── admin.js.ctmpl        # Creación de usuarios admin
    └── grantRole.js.ctmpl    # Permisos root
```

#### Flujo de Inicialización

```
1. pre-start.sh
   └─> Integración con Consul/Vault (opcional)
       └─> startProcess.sh
           ├─> Genera keyfile desde $MONG_KEYFILE
           ├─> startWithConfig.sh (mongod en background)
           └─> mongoStart.sh
               ├─> Espera a que 3 nodos estén "started" en Consul
               ├─> Genera admin.js, replica.js, grantRole.js
               └─> initMongo.sh
                   ├─> rs.initiate() en nodo actual
                   ├─> Crea usuarios admin y replicaAdmin
                   ├─> rs.add() para DB1, DB2, DB3
                   ├─> Crea usuarios de aplicación
                   └─> Inserta datos iniciales (movies.js)
```

#### ⚠️ Issues de Robustez

**1. Timeouts hardcodeados sin validación**

```bash
# initMongo.sh línea 5
sleep 2  # ❌ No valida que el comando anterior terminó correctamente
```

**2. Función de healthcheck deshabilitada**

```bash
# initMongo.sh líneas 27-42
# function wait_for {
#   ...  ❌ Comentada, no se usa TCP check real
# }
```

**3. Lógica de `add_replicas` asume orden**

```bash
# initMongo.sh líneas 16-19
for server in $DB1 $DB2 $DB3; do
  rs.add('$server')  # ❌ Añade el nodo desde el cual se ejecuta también
done
```

**Problema**: Si initMongo.sh se ejecuta desde mongo3 (10.7.0.5), añade:
- 10.7.0.3 ✅
- 10.7.0.4 ✅
- 10.7.0.5 ⚠️ Se añade a sí mismo (ya está en rs.initiate)

---

### 3. Conexión desde Microservicios

#### Patrón de Conexión Estándar

```go
// URL de conexión (común a todos)
mongodb://<user>:<pass>@10.7.0.3:27017,10.7.0.4:27017,10.7.0.5:27017/<db>?replicaSet=rs1&authSource=admin
```

#### Comparativa de Implementaciones

| Servicio | Patrón | Error Handling | Struct MongoConnection |
|----------|--------|----------------|------------------------|
| **booking-service** | Parámetros explícitos | os.Exit(1) | DB, Session, **Err** ✅ |
| **movie-service** | init() con env vars | No maneja (panic implícito) | DB, Session, **Err** ✅ |
| **payment-service** | Parámetros explícitos | os.Exit(1) | DB, Session ❌ (sin Err) |

#### ❌ Inconsistencias

**1. payment-service: Struct incompleto**

```go
// payment-service/src/db/mgo.go línea 20-24
type MongoConnection struct {
    DB      *mgo.Database
    Session *mgo.Session
    // ❌ Falta campo Err
}
```

**Otros servicios tienen:**
```go
type MongoConnection struct {
    DB      *mgo.Database
    Session *mgo.Session
    Err     error  // ✅ Permite propagar errores sin panic
}
```

**2. movie-service: No valida env vars obligatorias**

```go
// movie-service/src/db/mgo.go líneas 31-45
if !uok {
    fmt.Println("No DB user specified")  // ❌ Solo imprime, no falla
}
// ... continúa con valores vacíos potencialmente
```

**3. Diferentes firmas de función**

```go
// booking-service y payment-service
func MongoDB(options MongoReplicaSet, c chan *MongoConnection)

// movie-service
func MongoDB(c chan *MongoConnection)  // Lee opciones de init()
```

---

## 🎯 Recomendaciones Prioritarias

### Prioridad ALTA (Corrección Inmediata)

#### 1. Corregir configuración de IPs en mongo3

**Archivo**: `deploy/docker-compose/docker-compose.yml`

```yaml
# ANTES (líneas 54-56) ❌
mongo3:
  environment:
    DB3: "10.7.0.3"
    DB2: "10.7.0.4"
    DB1: "10.7.0.5"

# DESPUÉS ✅
mongo3:
  environment:
    DB1: "10.7.0.3"
    DB2: "10.7.0.4"
    DB3: "10.7.0.5"
```

#### 2. Estandarizar struct MongoConnection

**Archivo**: `payment-service/src/db/mgo.go`

```go
// ANTES (línea 20) ❌
type MongoConnection struct {
    DB      *mgo.Database
    Session *mgo.Session
}

// DESPUÉS ✅
type MongoConnection struct {
    DB      *mgo.Database
    Session *mgo.Session
    Err     error
}
```

#### 3. Añadir healthchecks a MongoDB en docker-compose

```yaml
mongo1:
  image: crizstian/cinema/cinemas-db:v0.1
  healthcheck:
    test: ["CMD", "mongo", "--eval", "db.adminCommand('ping')"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 40s
  # ... resto de configuración
```

### Prioridad MEDIA

#### 4. Validar env vars obligatorias en movie-service

```go
// movie-service/src/db/mgo.go (después de línea 45)
if !uok || !pok || !sok || !nok || !rok {
    log.Fatal("Missing required MongoDB environment variables")
}
```

#### 5. Reemplazar sleeps por health checks reales

**Archivo**: `cinemas-db/startup/initMongo.sh`

```bash
# Descomentar y usar wait_for function
function wait_for_databases {
  for ip in $@; do
    echo "Waiting for MongoDB at $ip:$DB_PORT"
    while ! nc -z $ip $DB_PORT; do
      sleep 1
    done
    echo "$ip is ready"
  done
}

# Usar antes de add_replicas
wait_for_databases $DB1 $DB2 $DB3
```

#### 6. Añadir restart policies a MongoDB

```yaml
mongo1:
  restart: unless-stopped  # ✅ Evita pérdida de datos en crash
```

### Prioridad BAJA (Mejoras Futuras)

#### 7. Añadir resource limits

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

#### 8. Estandarizar logging estructurado en conexiones DB

Todos los servicios deberían usar logrus con campos estructurados:

```go
log.WithFields(log.Fields{
    "replica_set": options.ReplicaSet,
    "servers":     options.Servers,
}).Info("Connecting to MongoDB replica set")
```

---

## ✅ Comandos de Validación

### Verificar estado del Replica Set

```bash
# Desde el host
docker exec -it <container-id> mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.status()"

# Verificar configuración
docker exec -it <container-id> mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.conf()"

# Ver si todos los nodos están sincronizados
docker exec -it <container-id> mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.printReplicationInfo()"
```

### Verificar conexión desde microservicios

```bash
# Ver logs de conexión
docker-compose logs booking | grep -i "connecting to"
docker-compose logs movie | grep -i "connecting to"
docker-compose logs payment | grep -i "connecting to"

# Verificar que los servicios pueden escribir
docker exec -it <booking-container> curl -X POST http://localhost:8000/bookings -d '{"test":"data"}'
```

### Probar failover

```bash
# 1. Identificar el PRIMARY actual
docker exec mongo3 mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.status().members.forEach(m => print(m.name, m.stateStr))"

# 2. Detener el PRIMARY
docker-compose stop mongo3

# 3. Verificar que se eligió nuevo PRIMARY (tarda ~10-30s)
docker exec mongo1 mongo -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --eval "rs.status()" | grep stateStr

# 4. Verificar que los servicios siguen funcionando
curl http://localhost:8000/api/movies
curl http://localhost:8300/api/bookings

# 5. Levantar el nodo caído
docker-compose start mongo3
```

---

## 📊 Matriz de Riesgos

| Issue | Probabilidad | Impacto | Prioridad | Esfuerzo |
|-------|--------------|---------|-----------|----------|
| IPs invertidas en mongo3 | Alta | Medio | 🔴 Alta | Bajo (1 línea) |
| payment-service sin campo Err | Media | Alto | 🔴 Alta | Bajo (1 línea) |
| Sin healthchecks en MongoDB | Alta | Alto | 🔴 Alta | Medio (9 líneas) |
| movie-service no valida env vars | Media | Alto | 🟡 Media | Bajo (2 líneas) |
| Sleeps sin validación | Media | Medio | 🟡 Media | Medio (función) |
| Sin restart policies | Baja | Alto | 🟡 Media | Bajo (1 línea x3) |
| Sin resource limits | Baja | Medio | 🟢 Baja | Bajo (5 líneas x3) |

---

## 📚 Referencias

- [MongoDB Replica Set Deployment](https://www.mongodb.com/docs/manual/tutorial/deploy-replica-set/)
- [Docker Compose Healthchecks](https://docs.docker.com/compose/compose-file/05-services/#healthcheck)
- [mgo Driver (legacy)](https://pkg.go.dev/gopkg.in/mgo.v2)

---

## 🔧 Próximos Pasos

1. ✅ Aplicar correcciones de prioridad ALTA
2. ✅ Ejecutar suite de validación completa
3. ✅ Probar failover manual
4. ⏭️ Aplicar mejoras de prioridad MEDIA
5. ⏭️ Documentar runbook de operaciones
6. ⏭️ Considerar migración a driver oficial MongoDB Go (opcional)
