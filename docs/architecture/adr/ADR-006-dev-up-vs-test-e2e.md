# ADR-006: Perfiles de Entorno - dev:up vs test:e2e

## Estado
Aceptado

## Fecha
2026-04-08

## Contexto

El proyecto Cinema Microservices requiere diferentes configuraciones de entorno para:

1. **Desarrollo iterativo**: Los desarrolladores necesitan un entorno persistente donde puedan hacer cambios, debuggear, y mantener datos entre sesiones.

2. **Testing automatizado**: El CI/CD necesita un entorno efimero, rapido, y determinista para ejecutar tests E2E.

3. **Pruebas de resiliencia**: Se requiere validar comportamiento ante fallos de infraestructura (MongoDB failover, etc).

## Decision

Implementamos dos perfiles de Docker Compose con caracteristicas distintas:

### Profile: `dev` (task dev:up)

```yaml
MongoDB: 3 replicas con volumenes persistentes
Redis: Volumen persistente
NATS: JetStream con storage
Servicios: 8 microservicios con rebuild automatico
```

**Caracteristicas:**
- Datos persisten entre reinicios
- Replica set completo para probar failover
- ~30s startup, ~45-50GB disk
- Ideal para debugging con Delve
- Permite pruebas manuales prolongadas

### Profile: `test` (task test:e2e)

```yaml
MongoDB: 1 nodo con tmpfs (memoria)
Redis: tmpfs
NATS: Sin persistencia
Servicios: 8 microservicios
E2E Runner: Contenedor dedicado
```

**Caracteristicas:**
- Datos efimeros (se borran al terminar)
- Startup rapido (~15s)
- Bajo consumo (~5-10GB RAM)
- Determinista (siempre estado limpio)
- Ideal para CI/CD

## Matriz de Casos de Uso

| Caso de Uso | dev:up | test:e2e |
|-------------|--------|----------|
| Desarrollo iterativo | Si | No |
| Debugging con Delve | Si | No |
| Inspeccion MongoDB/Redis | Si | No |
| Pruebas manuales con curl/Postman | Si | No |
| Failover MongoDB | Si | No |
| Performance testing | Si | No |
| Seed data persistente | Si | No |
| CI/CD automatizado | No | Si |
| Tests deterministas | No | Si |
| Validacion pre-merge | No | Si |

## Consecuencias

### Positivas

1. **Separacion clara de responsabilidades**: Cada perfil optimizado para su caso de uso.
2. **CI rapido**: El perfil test minimiza tiempo de ejecucion.
3. **Fidelidad en dev**: El perfil dev replica produccion (replica set).
4. **Flexibilidad**: Los desarrolladores pueden elegir segun necesidad.

### Negativas

1. **Divergencia potencial**: Los dos perfiles pueden comportarse diferente.
2. **Mantenimiento doble**: Cambios en servicios requieren validar ambos perfiles.

### Mitigaciones

1. **Tests E2E identicos**: El mismo codigo de test corre en ambos perfiles.
2. **Docker Compose unificado**: Un solo archivo con profiles en vez de archivos separados.
3. **Health checks compartidos**: Misma logica de validacion.

## Alternativas Consideradas

### 1. Un solo perfil configurable

**Rechazada**: Complejidad de configuracion y dificil optimizar para ambos casos.

### 2. Archivos docker-compose separados

**Rechazada**: Duplicacion de codigo y drift entre configuraciones.

### 3. Solo profile test

**Rechazada**: No permite debugging efectivo ni pruebas de resiliencia.

## Notas de Implementacion

### Variables de entorno clave

```bash
# dev:up
ENV_PREFIX=dev
MONGO_SERVERS=mongo1:27017,mongo2:27017,mongo3:27017

# test:e2e
ENV_PREFIX=test
MONGO_SERVERS=mongo:27017
```

### Comandos

```bash
# Desarrollo
task dev:up
task dev:down
task dev:log SERVICE=booking

# Testing
task test:e2e
```

## Referencias

- [docker-compose.yml](../../../platform/deploy/docker-compose/docker-compose.yml)
- [Lab Guide dev:up](../../development/dev-up-laboratory.md)
- [ADR-002: Redis para seat holds](./ADR-002-redis-seat-holds.md)
