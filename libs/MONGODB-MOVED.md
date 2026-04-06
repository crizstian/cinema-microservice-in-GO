# MongoDB Configuration - Moved

## ⚠️ Aviso Importante

La carpeta `libs/cinemas-db/` ha sido **eliminada** como parte de la reorganización del monorepo.

## 📍 Nueva Ubicación

La configuración de MongoDB ahora se encuentra en:

### Para Desarrollo Local (Docker Compose)

```
platform/deploy/docker-compose/
├── docker-compose.yml              # Usa imagen oficial mongo:7.0
├── scripts/
│   └── init-replica.sh            # Inicialización simplificada
└── MONGODB-SETUP.md               # Documentación completa
```

**Uso:**
```bash
cd platform/deploy/docker-compose
docker compose up -d
```

Ver: `platform/deploy/docker-compose/MONGODB-SETUP.md`

### Para Producción (Nomad/Consul/Vault)

```
platform/docker/mongodb/
├── Dockerfile                      # Imagen custom con Consul/Vault
├── Dockerfile.local                # Imagen simplificada para local
├── files/
│   ├── admin.js.ctmpl
│   ├── replica.js.ctmpl
│   └── ...
└── startup/
    ├── pre-start.sh               # Integración Vault
    ├── mongoStart.sh
    └── ...
```

## ❓ Razón del Cambio

La carpeta `libs/` debe contener **código reutilizable de aplicación** (Go clients, helpers, etc.), no configuración de infraestructura.

La configuración de Docker, scripts de despliegue y Dockerfiles pertenecen a `platform/`.

## 🔄 Migración

Si tienes referencias a `libs/cinemas-db/`:

**Antes:**
```bash
# Build desde libs
cd libs/cinemas-db
./create-image.sh
```

**Ahora:**
```bash
# Para desarrollo local
cd platform/deploy/docker-compose
docker compose up -d

# Para build de imagen custom (producción)
cd platform/docker/mongodb
docker build -t crizstian/cinema/mongodb:v0.2 .
```

## 📚 Referencias

- Configuración local: `platform/deploy/docker-compose/MONGODB-SETUP.md`
- Dockerfile producción: `platform/docker/mongodb/Dockerfile`
- Validación: `platform/scripts/validation/05-validate-mongodb.sh`

---

**Fecha de cambio**: 2026-01-23
**Versión del monorepo**: post-refactor
