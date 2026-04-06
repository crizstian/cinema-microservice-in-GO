# MongoDB Replica Set - Solución de Resolución de Nombres

## Problema

Al ejecutar los tests, aparece el siguiente error:

```
Error pinging MongoDB: server selection error: server selection timeout
current topology: { Type: ReplicaSetNoPrimary, Servers: [
  { Addr: mongo1:27017, Type: Unknown, Last error: dial tcp: lookup mongo1 on 127.0.0.11:53: no such host },
  { Addr: mongo2:27017, Type: Unknown, Last error: dial tcp: lookup mongo2 on 127.0.0.11:53: no such host },
  { Addr: mongo3:27017, Type: Unknown, Last error: dial tcp: lookup mongo3 on 127.0.0.11:53: no such host }
]}
```

### Causa Raíz

Cuando te conectas a un replica set de MongoDB, aunque uses IPs (ej: `192.168.68.104:27017`), MongoDB devuelve la configuración interna del replica set que contiene los hostnames configurados (`mongo1:27017`, `mongo2:27017`, `mongo3:27017`).

El cliente de MongoDB intenta conectarse usando esos hostnames, pero desde fuera del entorno Docker, esos nombres no pueden ser resueltos por DNS.

## Soluciones

Hay **3 soluciones posibles**. Elige la que mejor se adapte a tu situación:

---

## Solución 1: Reconfigurar el Replica Set (RECOMENDADA)

Esta solución reconfigura el replica set para usar IPs en lugar de hostnames.

### Pasos:

1. **Ejecutar el script de reconfiguración:**

```bash
./platform/deploy/docker-compose/scripts/reconfigure-replica-with-ips.sh
```

O con parámetros personalizados:

```bash
./platform/deploy/docker-compose/scripts/reconfigure-replica-with-ips.sh \
  cristian \
  cristianPassword2017 \
  192.168.68.104 \
  rs1
```

2. **Verificar la configuración:**

```bash
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 --authenticationDatabase admin --eval "rs.conf()"
```

Deberías ver:

```javascript
members: [
  { _id: 0, host: '192.168.68.104:27017', ... },
  { _id: 1, host: '192.168.68.104:27018', ... },
  { _id: 2, host: '192.168.68.104:27019', ... }
]
```

3. **Ejecutar los tests:**

```bash
./platform/scripts/test-mongodb-connection.sh
```

### Ventajas:
- ✅ Solución permanente
- ✅ Funciona desde cualquier máquina
- ✅ No requiere modificar /etc/hosts

### Desventajas:
- ❌ Requiere reconfigurar el replica set (operación delicada)

---

## Solución 2: Configurar /etc/hosts (RÁPIDA)

Esta solución agrega entradas al archivo `/etc/hosts` para resolver los nombres `mongo1`, `mongo2`, `mongo3`.

### Pasos:

1. **Ejecutar el script (requiere sudo):**

```bash
sudo ./platform/scripts/setup-mongodb-hosts.sh 192.168.68.104
```

2. **Verificar:**

```bash
cat /etc/hosts | grep -A 3 "MongoDB Replica Set"
```

Deberías ver:

```
# MongoDB Replica Set Entries
192.168.68.104  mongo1
192.168.68.104  mongo2
192.168.68.104  mongo3
# End MongoDB Entries
```

3. **Probar resolución:**

```bash
ping -c 1 mongo1
ping -c 1 mongo2
ping -c 1 mongo3
```

4. **Ejecutar los tests:**

```bash
./platform/scripts/test-mongodb-connection.sh
```

### Ventajas:
- ✅ Solución rápida y simple
- ✅ No modifica MongoDB
- ✅ Fácil de revertir

### Desventajas:
- ❌ Debe hacerse en cada máquina que ejecute los tests
- ❌ Requiere permisos de root

---

## Solución 3: Reinicializar con IPs desde el Inicio

Si estás configurando MongoDB desde cero, usa el script de inicialización mejorado.

### Pasos:

1. **Detener y limpiar MongoDB actual:**

```bash
cd platform/deploy/docker-compose
docker-compose down -v
```

⚠️ **ADVERTENCIA**: Esto eliminará todos los datos de MongoDB.

2. **Actualizar docker-compose.yml** para usar el nuevo script:

```yaml
mongo-init:
  # ... (misma configuración)
  environment:
    DB_ADMIN_USER: "cristian"
    DB_ADMIN_PASS: "cristianPassword2017"
    DB_REPLICA_ADMIN: "replicaAdmin"
    DB_REPLICA_ADMIN_PASS: "replicaAdminPassword2017"
    DB_REPLSET_NAME: "rs1"
    MONGO_HOST_IP: "192.168.68.104"  # AGREGAR ESTA LÍNEA
  volumes:
    - ./scripts/init-replica-with-ips.sh:/init-replica.sh  # CAMBIAR SCRIPT
  command: bash /init-replica.sh
```

3. **Iniciar MongoDB:**

```bash
docker-compose up -d
```

4. **Verificar logs:**

```bash
docker logs mongo-init -f
```

5. **Ejecutar tests:**

```bash
./platform/scripts/test-mongodb-connection.sh
```

### Ventajas:
- ✅ Configuración correcta desde el inicio
- ✅ No requiere reconfiguración posterior

### Desventajas:
- ❌ Solo útil para nuevas instalaciones
- ❌ Requiere limpiar datos existentes

---

## Verificación Final

Después de aplicar cualquiera de las soluciones, verifica que funcione:

### 1. Verificar configuración del replica set:

```bash
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 \
  --authenticationDatabase admin \
  --eval "rs.status().members.forEach(m => print(m.name + ' - ' + m.stateStr))"
```

Deberías ver IPs en lugar de hostnames:

```
192.168.68.104:27017 - PRIMARY
192.168.68.104:27018 - SECONDARY
192.168.68.104:27019 - SECONDARY
```

O si usaste Solución 2:

```
mongo1:27017 - PRIMARY (resolviendo a 192.168.68.104)
mongo2:27017 - SECONDARY (resolviendo a 192.168.68.104)
mongo3:27017 - SECONDARY (resolviendo a 192.168.68.104)
```

### 2. Ejecutar tests unitarios:

```bash
# Test rápido
./platform/scripts/test-mongodb-connection.sh -q

# Todos los tests
./platform/scripts/test-mongodb-connection.sh
```

### 3. Probar conexión manual:

```bash
cd services/movie
export DB_USER="cristian"
export DB_PASS="cristianPassword2017"
export DB_SERVERS="192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019"
export DB_NAME="movies"
export DB_REPLICA="rs1"
go test -v -timeout 120s ./internal/db/ -run TestMongoDBConnection_WithRealReplicaSet
```

---

## Solución de Problemas

### Error: "no reachable servers"

**Causa**: MongoDB no está escuchando en la IP externa.

**Solución**: Verificar que los contenedores expongan los puertos correctamente:

```bash
docker ps | grep mongo
netstat -tulpn | grep 27017
```

### Error: "authentication failed"

**Causa**: Credenciales incorrectas o usuario no creado.

**Solución**: Recrear usuarios:

```bash
docker exec -it mongo1 mongosh --eval "
  use admin
  db.createUser({
    user: 'cristian',
    pwd: 'cristianPassword2017',
    roles: ['root']
  })
"
```

### Error: "replica set not initialized"

**Causa**: El replica set no fue inicializado correctamente.

**Solución**: Verificar estado:

```bash
docker exec mongo1 mongosh --eval "rs.status()"
```

---

## Recomendación

Para **desarrollo local**: Usar **Solución 2** (/etc/hosts) - Es rápida y no afecta la configuración de MongoDB.

Para **producción o CI/CD**: Usar **Solución 1** (reconfigurar replica set) - Es permanente y no requiere modificar cada máquina.

Para **nuevas instalaciones**: Usar **Solución 3** (inicializar con IPs) - Configuración correcta desde el inicio.

---

## Scripts Disponibles

| Script | Ubicación | Descripción |
|--------|-----------|-------------|
| `reconfigure-replica-with-ips.sh` | `platform/deploy/docker-compose/scripts/` | Reconfigura replica set existente con IPs |
| `setup-mongodb-hosts.sh` | `platform/scripts/` | Agrega entradas a /etc/hosts |
| `init-replica-with-ips.sh` | `platform/deploy/docker-compose/scripts/` | Inicializa nuevo replica set con IPs |
| `test-mongodb-connection.sh` | `platform/scripts/` | Ejecuta tests de conexión |

---

## Resumen Rápido

```bash
# OPCIÓN 1: Reconfigurar (recomendada para producción)
./platform/deploy/docker-compose/scripts/reconfigure-replica-with-ips.sh

# OPCIÓN 2: /etc/hosts (rápida para desarrollo)
sudo ./platform/scripts/setup-mongodb-hosts.sh 192.168.68.104

# OPCIÓN 3: Reinicializar (solo nuevas instalaciones)
# Modificar docker-compose.yml y reiniciar
```

Después de aplicar cualquier solución:

```bash
# Verificar
./platform/scripts/test-mongodb-connection.sh -q
```

¡Listo! 🎉
