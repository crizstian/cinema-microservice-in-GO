# Platform Docker - Índice

Índice de todos los componentes Docker centralizados en este directorio.

## 📁 Estructura

```
platform/docker/
├── INDEX.md                   # Este archivo
├── README.md                  # Guía general de uso
│
├── go-service/                # Dockerfile genérico para servicios Go
│   ├── Dockerfile
│   ├── .dockerignore
│   └── README.md
│
├── devcontainer/              # Contenedor de desarrollo
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── devcontainer.json
│   └── README.md
│
├── base/                      # Imagen base Alpine (Consul/Vault opcional)
│   └── Dockerfile
│
├── mongodb/                   # MongoDB Replica Set
│   ├── Dockerfile
│   ├── Dockerfile.optimized
│   ├── startup/
│   └── files/
│
└── webserver/                 # Nginx reverse proxy
    ├── Dockerfile
    ├── Dockerfile.optimized
    ├── startup/
    └── files/
```

## 🚀 Acceso Rápido

### Servicios Go
- **Uso**: [go-service/README.md](./go-service/README.md)
- **Dockerfile**: [go-service/Dockerfile](./go-service/Dockerfile)
- **Build**: `SERVICE=booking platform/scripts/build-go-service.sh`

### Desarrollo Local
- **Guía**: [devcontainer/README.md](./devcontainer/README.md)
- **Setup VS Code**: Abrir proyecto → F1 → "Reopen in Container"

### Infraestructura
- **MongoDB**: [mongodb/](./mongodb/)
- **Webserver**: [webserver/](./webserver/)
- **Base Image**: [base/](./base/)

## 📋 Por Tipo de Tarea

### Quiero construir un servicio Go
→ Ver [go-service/README.md](./go-service/README.md)

### Quiero desarrollar localmente
→ Ver [devcontainer/README.md](./devcontainer/README.md)

### Quiero entender la arquitectura Docker
→ Ver [README.md](./README.md)

### Quiero optimizar MongoDB
→ Ver [mongodb/Dockerfile.optimized](./mongodb/Dockerfile.optimized)

### Quiero optimizar Webserver
→ Ver [webserver/Dockerfile.optimized](./webserver/Dockerfile.optimized)

## 📚 Documentación Relacionada

- [Análisis de Dockerfiles](../../docs/DOCKERFILE-ANALYSIS.md)
- [Mejoras Implementadas](../../docs/DOCKERFILE-IMPROVEMENTS.md)
- [Centralización](../../docs/DOCKER-CENTRALIZATION.md)
- [README Principal](../../README.md)

---

**Última actualización**: 2026-01-23
