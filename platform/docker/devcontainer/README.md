# Development Container

Contenedor de desarrollo para el monorepo Cinemas con todas las herramientas necesarias.

## 🚀 Inicio Rápido

### Opción 1: VS Code Dev Containers (Recomendado)

1. **Requisitos**:
   - [Docker Desktop](https://www.docker.com/products/docker-desktop)
   - [VS Code](https://code.visualstudio.com/)
   - [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

2. **Configurar en VS Code**:

   Crear `.devcontainer/devcontainer.json` en la raíz del proyecto:

   ```json
   {
     "name": "Cinemas Monorepo",
     "dockerComposeFile": "platform/docker/devcontainer/docker-compose.yml",
     "service": "devcontainer",
     "workspaceFolder": "/workspace",
     "forwardPorts": [8000, 8100, 8200, 8300, 27017, 27018, 27019],
     "postCreateCommand": "go work sync",
     "remoteUser": "vscode",
     "customizations": {
       "vscode": {
         "extensions": [
           "golang.go",
           "ms-azuretools.vscode-docker"
         ]
       }
     }
   }
   ```

3. **Abrir en Container**:
   - Presiona `F1` → `Dev Containers: Reopen in Container`
   - Espera a que el contenedor se construya (~3-5 minutos primera vez)
   - ¡Listo! Entorno completo con Go 1.21 y todas las herramientas

### Opción 2: Docker Compose Manual

```bash
# Desde la raíz del proyecto
cd platform/docker/devcontainer

# Build y ejecutar
docker-compose up -d

# Entrar al contenedor
docker-compose exec devcontainer bash

# Dentro del contenedor
cd /workspace
go work sync
```

## 🛠️ Herramientas Incluidas

### Go Development
- **Go 1.21**: Lenguaje y toolchain completo
- **golangci-lint**: Linter (40+ linters)
- **goimports**: Auto-formatter y organizador de imports
- **dlv (Delve)**: Debugger de Go
- **air**: Hot reload para desarrollo

### Docker
- **Docker-in-Docker**: Construir imágenes desde el contenedor
- **docker-compose**: Orquestación de servicios

### Databases
- **mongo**: Cliente MongoDB para réplica set
- **psql**: Cliente PostgreSQL (por si migras)

### Utilidades
- **git**: Control de versiones
- **gh**: GitHub CLI
- **jq**: Procesador JSON
- **make**: Build automation
- **curl/wget**: HTTP clients

### VS Code Extensions (Auto-instaladas)
- **Go** - Soporte oficial de Go
- **Docker** - Gestión de contenedores
- **YAML** - Validación de YAML
- **GitLens** - Git supercharged
- **Makefile Tools** - Soporte para Makefiles

## 📂 Estructura de Volúmenes

```
volumes:
  go-modules:        # Cache de go mod (persiste entre recreaciones)
  command-history:   # Historial de bash (persiste entre sesiones)
```

**Beneficio**: Instalaciones de dependencias solo se hacen una vez.

## 🔌 Puertos Expuestos

El devcontainer auto-expone estos puertos:

| Puerto | Servicio | URL |
|--------|----------|-----|
| 8000 | movie-service | http://localhost:8000 |
| 8100 | payment-service | http://localhost:8100 |
| 8200 | notification-service | http://localhost:8200 |
| 8300 | booking-service | http://localhost:8300 |
| 27017 | MongoDB (mongo1) | mongodb://localhost:27017 |
| 27018 | MongoDB (mongo2) | mongodb://localhost:27018 |
| 27019 | MongoDB (mongo3) | mongodb://localhost:27019 |

## 📋 Uso Común

### Ejecutar un Servicio
```bash
cd services/booking
go run ./cmd/booking
```

### Ejecutar Tests
```bash
# Unit tests
go test ./services/booking/internal/...

# Integration tests (requiere MongoDB)
docker compose -f platform/deploy/docker-compose/docker-compose.yml up -d mongo1 mongo2 mongo3
go test -tags=integration ./...
```

### Build Docker Images
```bash
# Desde dentro del devcontainer
docker build -f platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME=booking \
  -t booking:dev services/booking/
```

### Linting
```bash
# Lint todo el monorepo
golangci-lint run ./...

# Lint un servicio específico
golangci-lint run ./services/booking/...
```

### Hot Reload con Air
```bash
cd services/booking
air  # Lee .air.toml si existe, o usa defaults
```

### Debugging
1. Abre un archivo `.go`
2. Pon un breakpoint (click en número de línea)
3. Presiona `F5` para iniciar debug
4. Usa la consola de debug

## 🎯 Comandos Post-Create

Al abrir el devcontainer, automáticamente ejecuta:
```bash
go work sync && echo '✅ Development container ready!'
```

Esto sincroniza todos los módulos Go del workspace.

## 🚨 Troubleshooting

### El contenedor no inicia
```bash
# Verificar Docker
docker ps

# Reconstruir contenedor
cd platform/docker/devcontainer
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

### Go modules no se descargan
```bash
# Limpiar cache
go clean -modcache

# Re-sincronizar
go work sync
go mod download
```

### Permisos de archivos
```bash
# Verificar usuario
whoami  # Debería ser 'vscode'

# Si hay problemas de permisos en archivos creados
sudo chown -R vscode:vscode /workspace
```

### Docker-in-Docker no funciona
Verifica que el docker socket esté montado:
```bash
ls -la /var/run/docker.sock
docker ps  # Debería mostrar contenedores del host
```

## 🔧 Personalización

### Agregar Herramientas
Edita `Dockerfile` y agrega al `apt-get install`:
```dockerfile
RUN apt-get install -y \
  git \
  curl \
  tu-herramienta-aqui
```

### Agregar Extensions de VS Code
Edita `devcontainer.json`:
```json
"extensions": [
  "golang.go",
  "tu-extension-aqui"
]
```

### Cambiar Versión de Go
Edita `Dockerfile`:
```dockerfile
FROM mcr.microsoft.com/devcontainers/go:1.22-bullseye
```

## 📊 Comparación vs Local

| Aspecto | Desarrollo Local | DevContainer |
|---------|------------------|--------------|
| **Setup** | Instalar Go, Docker, tools | Un click |
| **Consistencia** | Depende de cada dev | Idéntico para todos ✅ |
| **Onboarding** | 1-2 horas | 5 minutos ✅ |
| **Aislamiento** | Mezcla con sistema | Completamente aislado ✅ |
| **Portabilidad** | Difícil reproducir | Funciona en cualquier OS ✅ |

## 🔗 Referencias

- [VS Code Dev Containers Docs](https://code.visualstudio.com/docs/devcontainers/containers)
- [Go in VS Code](https://code.visualstudio.com/docs/languages/go)
- [Docker Compose](https://docs.docker.com/compose/)

---

**Ubicación**: `platform/docker/devcontainer/`
**Última actualización**: 2026-01-23
