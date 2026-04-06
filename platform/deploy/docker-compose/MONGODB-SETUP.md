# MongoDB Replica Set - Guía de Configuración Local

## 📋 Descripción

Esta configuración proporciona un **MongoDB Replica Set de 3 nodos** para desarrollo local usando Docker Compose, completamente independiente de Consul/Nomad/Vault.

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────┐
│                Docker Compose                        │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │  mongo1  │  │  mongo2  │  │  mongo3  │          │
│  │ PRIMARY  │  │SECONDARY │  │SECONDARY │          │
│  │:27017    │  │:27017    │  │:27017    │          │
│  │10.7.0.3  │  │10.7.0.4  │  │10.7.0.5  │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│       │             │             │                 │
│       └─────────────┴─────────────┘                 │
│              Replica Set: rs1                       │
│                                                      │
│  ┌────────────────────────────────────┐             │
│  │       mongo-init                   │             │
│  │  (inicialización one-time)         │             │
│  │  - rs.initiate()                   │             │
│  │  - Crear usuarios                  │             │
│  │  - Cargar datos de prueba          │             │
│  └────────────────────────────────────┘             │
└─────────────────────────────────────────────────────┘
```

## ✅ Características

- ✅ **Replica Set de 3 nodos** (1 PRIMARY + 2 SECONDARY)
- ✅ **Persistencia de datos** con volúmenes Docker
- ✅ **Healthchecks** integrados
- ✅ **Auto-inicialización** del replica set
- ✅ **Datos de prueba** precargados
- ✅ **Sin dependencias** de Consul/Nomad/Vault
- ✅ **Restart automático** en caso de fallos

## 🚀 Inicio Rápido

### 1. Levantar el Stack Completo

```bash
cd platform/deploy/docker-compose
docker compose up -d
```

Esto iniciará:
1. Los 3 nodos MongoDB (mongo1, mongo2, mongo3)
2. El servicio de inicialización (mongo-init) que configurará el replica set

### 2. Verificar Estado

Esperar ~60 segundos para que se complete la inicialización, luego:

```bash
# Verificar que los contenedores estén corriendo
docker compose ps

# Verificar logs de inicialización
docker compose logs mongo-init

# Verificar estado del replica set
docker exec mongo1 mongosh --quiet --eval "rs.status()"
```

### 3. Verificar Nodos del Replica Set

```bash
docker exec mongo1 mongosh --quiet --eval "
rs.status().members.forEach(function(member) {
  print(member.name + ' - ' + member.stateStr + ' (health: ' + member.health + ')');
})
"
```

**Salida esperada:**
```
mongo1:27017 - PRIMARY (health: 1)
mongo2:27017 - SECONDARY (health: 1)
mongo3:27017 - SECONDARY (health: 1)
```

## 🔧 Configuración

### Credenciales

**Usuario Administrador:**
- Usuario: `cristian`
- Password: `cristianPassword2017`
- Roles: `userAdminAnyDatabase`, `readWriteAnyDatabase`

**Usuario Replica Set:**
- Usuario: `replicaAdmin`
- Password: `replicaAdminPassword2017`
- Roles: `clusterAdmin`

⚠️ **IMPORTANTE**: Cambiar estas credenciales antes de usar en producción.

### Puertos Expuestos

| Servicio | Puerto Host | Puerto Contenedor |
|----------|-------------|-------------------|
| mongo1   | 27017       | 27017             |
| mongo2   | 27018       | 27017             |
| mongo3   | 27019       | 27017             |

### Connection Strings

**Desde host:**
```bash
# Conexión directa (modo standalone - no recomendado)
mongodb://cristian:cristianPassword2017@localhost:27017/cinemas

# Conexión con replica set (recomendado)
mongodb://cristian:cristianPassword2017@localhost:27017,localhost:27018,localhost:27019/cinemas?replicaSet=rs1
```

**Desde servicios en Docker Compose:**
```bash
# Usando hostnames internos
mongodb://cristian:cristianPassword2017@mongo1:27017,mongo2:27017,mongo3:27017/cinemas?replicaSet=rs1
```

## 📊 Datos de Prueba

El script de inicialización carga 5 películas de ejemplo en la base de datos `cinemas`:

```bash
# Ver películas cargadas
docker exec mongo1 mongosh cinemas -u cristian -p cristianPassword2017 --authenticationDatabase admin --quiet --eval "db.movies.find().pretty()"


docker exec mongo1 mongosh "mongodb://cristian:cristianPassword2017@10.7.0.3:27017,10.7.0.4:27017,10.7.0.5:27017/movies?replicaSet=rs1&authSource=admin"
```

## 🧪 Validación Completa

### Opción 1: Script de Validación Automática

```bash
cd /workspace
make validate-mongodb
```

O directamente:

```bash
bash platform/scripts/validation/05-validate-mongodb.sh
```

Este script valida:
- ✅ Contenedores corriendo
- ✅ Healthchecks
- ✅ Estado del replica set
- ✅ Topología (1 PRIMARY + 2 SECONDARY)
- ✅ Datos de prueba
- ✅ Escritura/lectura

### Opción 2: Validación Manual

#### 1. Verificar Contenedores

```bash
docker compose ps
```

Todos deben estar en estado `Up (healthy)`.

#### 2. Verificar Replica Set

```bash
docker exec mongo1 mongosh --quiet --eval "rs.status().ok"
```

Debe retornar: `1`

#### 3. Probar Conexión

```bash
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 --authenticationDatabase admin --eval "db.adminCommand({listDatabases: 1})"
```

#### 4. Probar Escritura/Lectura

```bash
# Insertar documento
docker exec mongo1 mongosh cinemas -u cristian -p cristianPassword2017 --authenticationDatabase admin --quiet --eval '
db.test.insertOne({message: "Hello from MongoDB!", timestamp: new Date()})
'

# Leer documento
docker exec mongo1 mongosh cinemas -u cristian -p cristianPassword2017 --authenticationDatabase admin --quiet --eval '
db.test.findOne({message: "Hello from MongoDB!"})
'

# Cleanup
docker exec mongo1 mongosh cinemas -u cristian -p cristianPassword2017 --authenticationDatabase admin --quiet --eval 'db.test.drop()'
```

## 🔄 Operaciones Comunes

### Reiniciar el Stack

```bash
docker compose restart
```

### Detener el Stack

```bash
docker compose down
```

⚠️ **Nota**: Esto detiene los contenedores pero **preserva** los volúmenes de datos.

### Limpiar Todo (Eliminar Datos)

```bash
# ⚠️ PELIGRO: Esto elimina todos los datos
docker compose down -v
```

### Rebuild desde Cero

```bash
# Detener y limpiar
docker compose down -v

# Limpiar volúmenes huérfanos
docker volume prune -f

# Levantar de nuevo
docker compose up -d

# Esperar inicialización (60s)
sleep 60

# Verificar
docker compose logs mongo-init
```

### Ver Logs en Tiempo Real

```bash
# Todos los servicios
docker compose logs -f

# Solo MongoDB
docker compose logs -f mongo1 mongo2 mongo3

# Solo inicialización
docker compose logs -f mongo-init
```

## 🧪 Test de Failover

Prueba la resiliencia del replica set:

```bash
# 1. Identificar PRIMARY actual
docker exec mongo1 mongosh -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --quiet --eval "
rs.status().members.forEach(m => print(m.name, m.stateStr))
"

# 2. Detener PRIMARY (asumiendo que es mongo1)
docker compose stop mongo1

# 3. Esperar nueva elección (10-30 segundos)
sleep 30

# 4. Verificar nuevo PRIMARY
docker exec mongo2 mongosh -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --quiet --eval "
rs.status().members.forEach(m => print(m.name, m.stateStr))
"

# 5. Restaurar nodo
docker compose start mongo1

# 6. Verificar que se reintegra como SECONDARY
sleep 10
docker exec mongo1 mongosh -u replicaAdmin -p replicaAdminPassword2017 --authenticationDatabase admin --quiet --eval "rs.status().myState"
```

## 🐛 Troubleshooting

### Problema: Replica set no se inicializa

**Síntomas:**
```bash
docker compose logs mongo-init
# Error: NotYetInitialized
```

**Solución:**
```bash
# Reiniciar el servicio de inicialización
docker compose restart mongo-init

# O ejecutar manualmente
docker compose run --rm mongo-init bash /init-replica.sh
```

### Problema: "MongoNetworkError: connect ECONNREFUSED"

**Causa:** Los servicios intentan conectar antes de que MongoDB esté listo.

**Solución:**
- Verificar que los healthchecks estén funcionando
- Aumentar el `start_period` en el healthcheck
- Asegurarse de que los servicios usan `depends_on` con `condition: service_healthy`

### Problema: "Authentication failed"

**Causa:** Usuarios no creados correctamente.

**Solución:**
```bash
# Verificar que mongo-init terminó correctamente
docker compose logs mongo-init | grep "Replica set inicializado"

# Si no, ejecutar nuevamente
docker compose down -v
docker compose up -d
```

### Problema: Volúmenes con datos corruptos

**Solución:**
```bash
# Limpiar todo y empezar de cero
docker compose down -v
docker volume prune -f
docker compose up -d
```

## 📁 Estructura de Archivos

```
platform/deploy/docker-compose/
├── docker-compose.yml          # Configuración principal
├── scripts/
│   └── init-replica.sh         # Script de inicialización
├── MONGODB-SETUP.md            # Esta guía
└── readme.md                   # README general
```

## 🔗 Referencias

- [MongoDB Docker Hub](https://hub.docker.com/_/mongo)
- [MongoDB Replica Set Deployment](https://www.mongodb.com/docs/manual/tutorial/deploy-replica-set/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [MongoDB Connection String](https://www.mongodb.com/docs/manual/reference/connection-string/)

## 📝 Notas

### Diferencias con Configuración de Producción

Esta configuración está optimizada para **desarrollo local**:

| Aspecto | Desarrollo | Producción |
|---------|------------|------------|
| Autenticación | Credenciales hardcodeadas | Vault/Secrets Manager |
| Keyfile | No usado | Requerido para auth entre nodos |
| TLS/SSL | Deshabilitado | Habilitado |
| Resource Limits | Ninguno | CPU/Memory limits |
| Backups | Manual | Automatizados |
| Monitoring | Logs básicos | Prometheus + Grafana |

### Imagen Docker

La configuración usa **`mongo:7.0` oficial** en lugar de la imagen custom `crizstian/cinema/cinemas-db:v0.1` porque:

1. ✅ **Simplicidad**: No requiere Consul/Nomad/Vault
2. ✅ **Mantenimiento**: MongoDB Inc. mantiene la imagen
3. ✅ **Seguridad**: Parches de seguridad regulares
4. ✅ **Documentación**: Ampliamente documentada

La imagen custom en `platform/docker/mongodb/` se mantiene para despliegues con Nomad/Consul.

---

**Última actualización**: 2026-01-23
**Versión**: 2.0
