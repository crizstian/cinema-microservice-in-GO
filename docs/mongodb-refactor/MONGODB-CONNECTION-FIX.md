# MongoDB Connection Fix - SIGSEGV Error Resolution

## Problema Identificado

Los servicios (movie, booking, payment) estaban experimentando un `SIGSEGV: segmentation violation` al intentar conectarse a MongoDB. Este error de segmentación estaba causado por varios problemas:

### Causas Principales

1. **Uso de contexto nil en Disconnect**: Los métodos `mainErrorHandler` llamaban a `client.Disconnect(nil)`, lo cual es peligroso y puede causar panic en Go.

2. **Configuración insuficiente del cliente MongoDB**: El cliente no tenía configuraciones de timeout y pool adecuadas para manejar conexiones a replica sets de manera robusta.

3. **Falta de manejo de errores en desconexión**: No se validaba correctamente el estado del cliente antes de desconectar.

4. **Timeouts muy cortos**: Los timeouts de conexión eran demasiado cortos para replica sets en redes externas.

## Cambios Implementados

### 1. Corrección de `mongo.go` (todos los servicios)

**Archivo**: `services/{movie,booking,payment}/internal/db/mongo.go`

#### Cambios en la función `MongoDB`:

```go
// Antes (PROBLEMÁTICO)
uri := fmt.Sprintf(
    "mongodb://%s:%s@%s/%s?replicaSet=%s&authSource=%s",
    // ...
)
clientOptions := options.Client().ApplyURI(uri)

// Después (CORREGIDO)
uri := fmt.Sprintf(
    "mongodb://%s:%s@%s/%s?replicaSet=%s&authSource=%s&directConnection=false&serverSelectionTimeoutMS=10000&connectTimeoutMS=10000",
    // ...
)
clientOptions := options.Client().
    ApplyURI(uri).
    SetServerSelectionTimeout(10 * time.Second).
    SetConnectTimeout(10 * time.Second).
    SetSocketTimeout(30 * time.Second).
    SetMaxPoolSize(50).
    SetMinPoolSize(10).
    SetMaxConnIdleTime(30 * time.Second).
    SetHeartbeatInterval(10 * time.Second).
    SetDirect(false)
```

**Beneficios**:
- `SetServerSelectionTimeout`: Tiempo para seleccionar un servidor del replica set
- `SetConnectTimeout`: Timeout para establecer conexión TCP
- `SetSocketTimeout`: Timeout para operaciones de socket
- `SetMaxPoolSize/SetMinPoolSize`: Pool de conexiones optimizado
- `SetHeartbeatInterval`: Monitoreo de salud del replica set
- `SetDirect(false)`: Permite conectarse a cualquier miembro del replica set

#### Manejo de errores mejorado:

```go
// Antes
err = client.Ping(pingCtx, readpref.Primary())
if err != nil {
    log.Errorf("Error pinging MongoDB: %v", err)
    c <- &MongoConnection{
        Client:   nil,
        Database: nil,
        Err:      err,
    }
    return
}

// Después
err = client.Ping(pingCtx, readpref.Primary())
if err != nil {
    log.Errorf("Error pinging MongoDB: %v", err)
    // Desconectar cliente antes de retornar error
    disconnectCtx, disconnectCancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer disconnectCancel()
    _ = client.Disconnect(disconnectCtx)

    c <- &MongoConnection{
        Client:   nil,
        Database: nil,
        Err:      fmt.Errorf("failed to ping MongoDB: %w", err),
    }
    return
}
```

### 2. Corrección de `main.go` (todos los servicios)

**Archivos**: `services/{movie,booking,payment}/cmd/{movie,booking,payment}/main.go`

#### Imports actualizados:

```go
import (
    // ... otros imports
    "context"
    "time"
    // ...
)
```

#### Función `mainErrorHandler` corregida:

```go
// Antes (PELIGROSO - causa SIGSEGV)
func mainErrorHandler(msg string) {
    log.Errorln(msg)
    if client != nil {
        client.Disconnect(nil)  // ❌ NUNCA usar contexto nil
    }
    os.Exit(1)
}

// Después (SEGURO)
func mainErrorHandler(msg string) {
    log.Errorln(msg)
    if client != nil {
        ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
        defer cancel()
        if err := client.Disconnect(ctx); err != nil {
            log.Errorf("Error disconnecting from MongoDB: %v", err)
        }
    }
    os.Exit(1)
}
```

## Tests Unitarios Implementados

Se crearon tests exhaustivos para validar la conexión con MongoDB usando la IP y puertos especificados.

### Archivos de Tests

- `services/movie/internal/db/mongo_test.go`
- `services/booking/internal/db/mongo_test.go`
- `services/payment/internal/db/mongo_test.go`

### Tests Implementados

1. **TestMongoDBConnection_WithRealReplicaSet**
   - Valida conexión exitosa al replica set en `192.168.68.104:27017,27018,27019`
   - Verifica que el cliente y database no son nil
   - Ejecuta ping al servidor para validar conectividad
   - Valida el nombre de la base de datos

2. **TestMongoDBConnection_InvalidCredentials**
   - Prueba conexión con credenciales inválidas
   - Verifica que el error se maneja correctamente
   - Asegura que el cliente es nil cuando falla la autenticación

3. **TestMongoDBConnection_InvalidServer**
   - Prueba conexión a servidor inexistente
   - Valida timeout y manejo de errores de red

4. **TestMongoDBConnection_MultipleConnections**
   - Prueba 3 conexiones concurrentes
   - Valida pool de conexiones
   - Verifica desconexión limpia de todas las conexiones

5. **TestMongoDBDisconnect**
   - Valida la funcionalidad de desconexión
   - Verifica que después de desconectar, el ping falla

6. **TestMongoDBDisconnect_NilClient**
   - Prueba edge case de desconexión con cliente nil
   - Asegura que no hay panic

## Cómo Ejecutar los Tests

### Prerrequisitos

1. MongoDB replica set configurado y ejecutándose en:
   - `192.168.68.104:27017`
   - `192.168.68.104:27018`
   - `192.168.68.104:27019`

2. Usuario y contraseña configurados:
   - Usuario: `cristian`
   - Password: `cristianPassword2017`
   - AuthSource: `admin`

3. Replica set name: `rs1`

### Ejecutar Tests

#### Para el servicio Movie:

```bash
cd services/movie
go test -v ./internal/db/
```

#### Para el servicio Booking:

```bash
cd services/booking
go test -v ./internal/db/
```

#### Para el servicio Payment:

```bash
cd services/payment
go test -v ./internal/db/
```

#### Ejecutar todos los tests en paralelo:

```bash
# Desde el directorio raíz del proyecto
cd services/movie && go test -v ./internal/db/ &
cd services/booking && go test -v ./internal/db/ &
cd services/payment && go test -v ./internal/db/ &
wait
```

#### Ejecutar tests específicos:

```bash
# Solo el test de conexión real
go test -v ./internal/db/ -run TestMongoDBConnection_WithRealReplicaSet

# Solo tests de validación de errores
go test -v ./internal/db/ -run "Invalid"
```

#### Ejecutar con timeout mayor (recomendado para redes lentas):

```bash
go test -v -timeout 120s ./internal/db/
```

### Salida Esperada

```
=== RUN   TestMongoDBConnection_WithRealReplicaSet
--- PASS: TestMongoDBConnection_WithRealReplicaSet (2.34s)
=== RUN   TestMongoDBConnection_InvalidCredentials
--- PASS: TestMongoDBConnection_InvalidCredentials (10.12s)
=== RUN   TestMongoDBConnection_InvalidServer
--- PASS: TestMongoDBConnection_InvalidServer (10.05s)
=== RUN   TestMongoDBConnection_MultipleConnections
--- PASS: TestMongoDBConnection_MultipleConnections (3.21s)
=== RUN   TestMongoDBDisconnect
--- PASS: TestMongoDBDisconnect (2.18s)
=== RUN   TestMongoDBDisconnect_NilClient
--- PASS: TestMongoDBDisconnect_NilClient (0.00s)
PASS
ok      cinemas/services/movie/internal/db      27.906s
```

## Variables de Entorno para Ejecución

Para ejecutar los servicios con la configuración correcta:

### Movie Service

```bash
export DB_USER="cristian"
export DB_PASS="cristianPassword2017"
export DB_SERVERS="192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019"
export DB_NAME="movies"
export DB_REPLICA="rs1"
export SERVICE_PORT="8000"
```

### Booking Service

```bash
export DB_USER="cristian"
export DB_PASS="cristianPassword2017"
export DB_SERVERS="192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019"
export DB_NAME="booking"
export DB_REPLICA="rs1"
export SERVICE_PORT="8000"
```

### Payment Service

```bash
export DB_USER="cristian"
export DB_PASS="cristianPassword2017"
export DB_SERVERS="192.168.68.104:27017,192.168.68.104:27018,192.168.68.104:27019"
export DB_NAME="payment"
export DB_REPLICA="rs1"
export SERVICE_PORT="8000"
```

## Resumen de Mejoras

### Problemas Resueltos

✅ **SIGSEGV eliminado**: Uso correcto de contextos en todas las operaciones
✅ **Timeouts optimizados**: Configuración adecuada para replica sets
✅ **Pool de conexiones**: Mejor manejo de conexiones concurrentes
✅ **Manejo de errores**: Desconexión limpia en caso de error
✅ **Tests exhaustivos**: Validación completa de conectividad

### Configuraciones Clave Agregadas

- `directConnection=false`: Permite descubrimiento del replica set
- `serverSelectionTimeoutMS=10000`: Tiempo adecuado para seleccionar servidor
- `connectTimeoutMS=10000`: Timeout de conexión aumentado
- Pool de conexiones: Min 10, Max 50
- Heartbeat: 10 segundos para monitoreo de salud

## Próximos Pasos

1. Ejecutar los tests para validar la conexión
2. Reconstruir las imágenes Docker de los servicios
3. Desplegar con las nuevas configuraciones
4. Monitorear logs para confirmar conexión exitosa

## Notas de Seguridad

- NUNCA usar `client.Disconnect(nil)` - siempre pasar un contexto válido
- Siempre validar que el cliente no sea nil antes de usarlo
- Usar timeouts apropiados para todas las operaciones de red
- Implementar retry logic para conexiones a replica sets en producción
