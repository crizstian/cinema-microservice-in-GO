# 🚀 Ejecución de Tests Modernos - MongoDB

## ✅ Estado Actual

| Componente | Estado | Versión |
|------------|--------|---------|
| MongoDB Driver | ✅ Modernizado | v1.17.7 (Enero 2026) |
| MongoDB Server | ✅ Actualizado | 8.0 |
| Go | ✅ Actualizado | 1.23 |
| Código | ✅ Compilando | Sin errores |
| Tests | ✅ Listos | 33 tests (11x3) |

## 🔧 Preparación (OBLIGATORIO)

### Paso 1: Resolver Hostnames de MongoDB

El replica set de MongoDB usa hostnames internos (`mongo1`, `mongo2`, `mongo3`). Necesitas resolver este problema eligiendo UNA de estas opciones:

#### **Opción A: /etc/hosts** (⚡ Más Rápida - 30 segundos)

```bash
sudo ./platform/scripts/setup-mongodb-hosts.sh 192.168.68.104
```

Esto agrega al `/etc/hosts`:
```
192.168.68.104  mongo1
192.168.68.104  mongo2
192.168.68.104  mongo3
```

**Verificar**:
```bash
ping -c 1 mongo1
# Debería responder desde 192.168.68.104
```

#### **Opción B: Reconfigurar Replica Set** (🔒 Permanente - 2 minutos)

```bash
./platform/deploy/docker-compose/scripts/reconfigure-replica-with-ips.sh
```

Esto cambia la configuración del replica set para usar IPs en lugar de hostnames.

**Verificar**:
```bash
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 \
  --authenticationDatabase admin \
  --eval "rs.conf().members.forEach(m => print(m.host))"

# Debería mostrar:
# 192.168.68.104:27017
# 192.168.68.104:27018
# 192.168.68.104:27019
```

### Paso 2: Verificar que MongoDB está corriendo

```bash
# Verificar contenedores
docker ps | grep mongo

# Debería mostrar 4 contenedores: mongo1, mongo2, mongo3, mongo-init

# Verificar conectividad
telnet 192.168.68.104 27017
telnet 192.168.68.104 27018
telnet 192.168.68.104 27019
```

Si MongoDB no está corriendo:

```bash
cd platform/deploy/docker-compose
docker-compose up -d mongo1 mongo2 mongo3
sleep 15  # Esperar que inicien
docker-compose up mongo-init  # Inicializar replica set
```

## 🧪 Ejecutar Tests

### Tests Rápidos (Unit Tests - Sin MongoDB)

Estos tests NO requieren MongoDB funcionando:

```bash
# Movie service
cd services/movie
go test -short -v ./internal/db/

# Booking service
cd services/booking
go test -short -v ./internal/db/

# Payment service
cd services/payment
go test -short -v ./internal/db/
```

**Resultado esperado**:
```
=== RUN   TestLoadConfigFromEnv
--- PASS: TestLoadConfigFromEnv (0.00s)
=== RUN   TestLoadConfigFromEnv_MissingVars
--- PASS: TestLoadConfigFromEnv_MissingVars (0.00s)
PASS
ok      cinemas/services/movie/internal/db      0.123s
```

### Tests de Integración (Con MongoDB Real)

Estos tests SI requieren MongoDB funcionando:

```bash
# Test individual (Movie service)
cd services/movie
export DB_USER="cristian"
export DB_PASS="cristianPassword2017"
export DB_SERVERS="192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019"
export DB_NAME="movies"
export DB_REPLICA="rs1"
go test -v -timeout 120s ./internal/db/

# Todos los servicios (usando script)
./platform/scripts/test-mongodb-connection.sh
```

**Resultado esperado**:
```
=== RUN   TestConnect_Success
    INFO[0000] Initializing MongoDB connection...
    INFO[0000] Connecting to MongoDB: mongodb://cristian:****@192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019/movies?replicaSet=rs1
    INFO[0000] Establishing MongoDB connection...
    INFO[0002] Pinging MongoDB to verify connection...
    INFO[0003] Successfully connected to MongoDB!
--- PASS: TestConnect_Success (3.45s)
=== RUN   TestConnect_WithOperations
--- PASS: TestConnect_WithOperations (2.12s)
...
PASS
ok      cinemas/services/movie/internal/db      45.123s
```

### Test Específico

```bash
# Solo el test de conexión exitosa
cd services/movie
go test -v -run TestConnect_Success ./internal/db/

# Solo tests de credenciales inválidas
go test -v -run Invalid ./internal/db/
```

## 📊 Tests Disponibles

| Test | Descripción | Requiere MongoDB |
|------|-------------|------------------|
| `TestLoadConfigFromEnv` | Carga configuración | ❌ No |
| `TestLoadConfigFromEnv_MissingVars` | Validación de vars | ❌ No |
| `TestConnect_Success` | Conexión exitosa | ✅ Sí |
| `TestConnect_WithOperations` | CRUD operations | ✅ Sí |
| `TestConnect_InvalidCredentials` | Credenciales inválidas | ✅ Sí |
| `TestConnect_InvalidServer` | Servidor inexistente | ✅ Sí |
| `TestHealthCheck` | Health check | ✅ Sí |
| `TestHealthCheck_NilClient` | Health check con nil | ❌ No |
| `TestDisconnect_NilClient` | Disconnect seguro | ❌ No |
| `TestMongoDB_ChannelLegacy` | API legacy | ✅ Sí |
| `TestConnect_MultipleConnections` | 5 conexiones concurrentes | ✅ Sí |

## 🐛 Solución de Problemas

### Error: "lookup mongo1: no such host"

**Causa**: No has configurado /etc/hosts o no has reconfigurado el replica set.

**Solución**:
```bash
sudo ./platform/scripts/setup-mongodb-hosts.sh 192.168.68.104
```

### Error: "connection timeout"

**Causa**: MongoDB no está corriendo o no es accesible.

**Solución**:
```bash
# Verificar contenedores
docker ps | grep mongo

# Reiniciar si es necesario
cd platform/deploy/docker-compose
docker-compose restart mongo1 mongo2 mongo3
sleep 10
```

### Error: "authentication failed"

**Causa**: Credenciales incorrectas o usuario no existe.

**Solución**:
```bash
# Verificar usuario
docker exec -it mongo1 mongosh -u cristian -p cristianPassword2017 --authenticationDatabase admin --eval "db.runCommand({connectionStatus: 1})"

# Si falla, recrear usuario
docker exec -it mongo1 mongosh --eval "
use admin
db.createUser({
  user: 'cristian',
  pwd: 'cristianPassword2017',
  roles: ['root']
})
"
```

### Error: "server selection timeout"

**Causa**: Replica set no está inicializado o configurado correctamente.

**Solución**:
```bash
# Ver estado del replica set
docker exec mongo1 mongosh -u cristian -p cristianPassword2017 --authenticationDatabase admin --eval "rs.status()"

# Si no está inicializado, ejecutar init
cd platform/deploy/docker-compose
docker-compose up mongo-init
```

### Tests muy lentos (> 60 segundos cada uno)

**Causa**: Timeouts muy largos o problemas de red.

**Solución**:
```bash
# Ejecutar solo tests unitarios (rápidos)
go test -short -v ./internal/db/
```

### Error: "context deadline exceeded"

**Causa**: MongoDB está muy lento o timeouts demasiado cortos.

**Solución**:
```bash
# Aumentar timeout del test
go test -v -timeout 300s ./internal/db/
```

## ✅ Verificación Final

Ejecuta este comando para verificar que todo funciona:

```bash
# Test rápido de conectividad
cd services/movie
go test -v -run TestConnect_Success -timeout 60s ./internal/db/
```

Si este test pasa, **¡todo está funcionando correctamente!** ✅

## 📈 Siguiente Paso: Integración CI/CD

Una vez que todos los tests pasen localmente:

1. **Reconstruir imágenes Docker**:
```bash
cd services/movie
docker build -t crizstian/cinema/movie:v0.3 .

cd ../booking
docker build -t crizstian/cinema/booking:v0.3 .

cd ../payment
docker build -t crizstian/cinema/payment:v0.3 .
```

2. **Actualizar docker-compose.yml** (versión v0.2 → v0.3)

3. **Desplegar**:
```bash
cd platform/deploy/docker-compose
docker-compose down
docker-compose up -d
```

4. **Verificar logs**:
```bash
docker logs movie -f
# Debería mostrar: "Successfully connected to MongoDB!"
```

## 🎉 Resumen

- ✅ Driver MongoDB completamente modernizado (v1.17.7)
- ✅ MongoDB actualizado a versión 8.0
- ✅ 33 tests unitarios y de integración
- ✅ Código robusto con retry automático
- ✅ Pool de conexiones optimizado
- ✅ Compresión automática
- ✅ Health checks
- ✅ Logs detallados

**¡El stack de MongoDB ahora es profesional y listo para producción!** 🚀
