# DevContainer + Claude Code + Vertex AI + Harness MCP

Este documento describe la configuración completa del entorno de desarrollo:

- VS Code DevContainer
- Claude Code usando **Google Vertex AI**
- **Harness MCP Server v2** para orquestar pipelines
- Tooling de Go, Terraform, kubectl, gcloud
- Formateo automático de código al guardar

Audiencia: equipo técnico (DevEx, Platform, DevOps, SEs).

---

## 1. Tech stack

### Herramientas principales

- **VS Code**
  - Dev Containers
  - Extensiones:
    - `anthropic.claude-code` — Claude Code en VS Code.
    - `golang.go` — soporte Go, `gofmt`/`goimports`.
    - `redhat.vscode-yaml` — YAML con validación de esquemas.
    - `humao.rest-client` — pruebas de APIs.
    - `ms-vscode-remote.remote-containers` — DevContainer runtime.
    - `esbenp.prettier-vscode` — formatter para JS/TS/JSON/YAML/Markdown.

- **Contenedor de desarrollo**
  - Basado en imagen Go (golang) con:
    - `node`/`npm` (para `claude-code` CLI y `harness-mcp-v2`).
    - `gcloud` (ADC configurado con `gcloud auth application-default login`).
    - `kubectl`, `terraform` y herramientas de CLI necesarias.

- **Claude Code**
  - Ejecutándose dentro del DevContainer.
  - Backend: **Google Vertex AI** (Claude 3/4 vía Vertex).
  - Usa Application Default Credentials (ADC) de GCP montadas desde el host.

- **Harness MCP Server v2**
  - Servidor MCP para interactuar con Harness Platform.
  - Usa `HARNESS_API_KEY` y contexto de org/proyecto.
  - Tools clave:
    - `harness_status`, `harness_list`, `harness_get`,
    - `harness_diagnose`, `harness_execute`, etc.

---

## 2. Estructura de archivos

```txt
repo-root/
├── .devcontainer/
│   ├── devcontainer.json
│   ├── docker-compose.devcontainer.yml
│   └── devcontainer.env            # variables para DevContainer
├── platform/
│   └── docker/
│       └── devcontainer/
│           └── Dockerfile          # imagen base del DevContainer
├── .claude/
│   ├── settings.json               # (opcional) configuración avanzada de Claude
│   └── CLAUDE.md                   # (opcional) instrucciones del proyecto
└── ... código de la app ...
```

---

## 3. Variables de entorno

El archivo **.devcontainer/devcontainer.env** es la fuente de verdad para la configuración del DevContainer.

### Ejemplo de `devcontainer.env`

```env
# Harness
HARNESS_API_KEY=pat.xxx.yyy.zzz
HARNESS_DEFAULT_ORG_ID=default
HARNESS_DEFAULT_PROJECT_ID=cinemas
HARNESS_BASE_URL=https://app.harness.io
HARNESS_TOOLSETS=pipelines,services,connectors,logs,delegates
HARNESS_SKIP_ELICITATION=false

# Vertex / GCP
CLAUDE_CODE_USE_VERTEX=1
ANTHROPIC_VERTEX_PROJECT_ID=tu-project-id
GOOGLE_CLOUD_PROJECT=tu-project-id
CLOUD_ML_REGION=global
```

> Nota: este archivo NO se debe commitear si contiene secretos. Añadirlo a `.gitignore` o usar un `.env` privado equivalente.

---

## 4. docker-compose.devcontainer.yml

Archivo: `.devcontainer/docker-compose.devcontainer.yml`

```yaml
version: "3.8"

services:
  cinemas_microservice_go:
    build:
      context: ../platform/docker/devcontainer
      dockerfile: Dockerfile
    cap_add:
      - SYS_PTRACE
    security_opt:
      - seccomp:unconfined
    env_file:
      - devcontainer.env
    environment:
      # Defaults / overrides
      HARNESS_BASE_URL: ${HARNESS_BASE_URL:-https://app.harness.io}
      HARNESS_SKIP_ELICITATION: ${HARNESS_SKIP_ELICITATION:-false}

      CLAUDE_CODE_USE_VERTEX: ${CLAUDE_CODE_USE_VERTEX:-1}
      ANTHROPIC_VERTEX_PROJECT_ID: ${ANTHROPIC_VERTEX_PROJECT_ID}
      GOOGLE_CLOUD_PROJECT: ${GOOGLE_CLOUD_PROJECT:-${ANTHROPIC_VERTEX_PROJECT_ID}}
      CLOUD_ML_REGION: ${CLOUD_ML_REGION:-global}

      GOOGLE_APPLICATION_CREDENTIALS: /home/devuser/.config/gcloud/application_default_credentials.json

    volumes:
      - ../:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
      - ${HOME}/.config/gcloud:/home/devuser/.config/gcloud:rw

    working_dir: /workspace
    user: devuser
    container_name: cinemas_microservice_go
    command: /bin/sh -c "while sleep 1000; do :; done"
```

Puntos clave:

- `env_file: devcontainer.env` carga todas las variables para el servicio.
- `GOOGLE_APPLICATION_CREDENTIALS` apunta a las ADC montadas desde el host.
- Volume `${HOME}/.config/gcloud` permite que el contenedor use las credenciales de `gcloud auth application-default login`.

---

## 5. devcontainer.json

Archivo: `.devcontainer/devcontainer.json`

```json
{
  "name": "cinemas_microservice_go",
  "dockerComposeFile": ["docker-compose.devcontainer.yml"],
  "service": "cinemas_microservice_go",
  "workspaceFolder": "/workspace",

  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "golang.go",
        "redhat.vscode-yaml",
        "humao.rest-client",
        "ms-vscode-remote.remote-containers",
        "esbenp.prettier-vscode"
      ],
      "settings": {
        "terminal.integrated.defaultProfile.linux": "sh",
        "go.toolsManagement.autoUpdate": true,

        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
          "source.organizeImports": "explicit"
        },

        "[go]": {
          "editor.defaultFormatter": "golang.go"
        },
        "[javascript]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[typescript]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[json]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[jsonc]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[yaml]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        },
        "[markdown]": {
          "editor.defaultFormatter": "esbenp.prettier-vscode"
        }
      },

      "mcp": {
        "servers": {
          "harness": {
            "command": "harness-mcp-v2",
            "args": [],
            "env": {
              "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
              "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
              "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
              "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
              "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}",
              "HARNESS_SKIP_ELICITATION": "false"
            }
          }
        }
      }
    }
  },

  "remoteEnv": {
    "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
    "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
    "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
    "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
    "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}",

    "CLAUDE_CODE_USE_VERTEX": "${containerEnv:CLAUDE_CODE_USE_VERTEX}",
    "ANTHROPIC_VERTEX_PROJECT_ID": "${containerEnv:ANTHROPIC_VERTEX_PROJECT_ID}",
    "GOOGLE_CLOUD_PROJECT": "${containerEnv:GOOGLE_CLOUD_PROJECT}",
    "CLOUD_ML_REGION": "${containerEnv:CLOUD_ML_REGION}",
    "GOOGLE_APPLICATION_CREDENTIALS": "${containerEnv:GOOGLE_APPLICATION_CREDENTIALS}"
  },

  "remoteUser": "devuser"
}
```

---

## 6. Configuración de Claude Code + Vertex AI

### En el host (una sola vez)

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project TU_PROJECT_ID
```

### En el DevContainer

Gracias al volumen de `~/.config/gcloud` y a `GOOGLE_APPLICATION_CREDENTIALS`, dentro del contenedor:

- `gcloud auth application-default print-access-token` debe funcionar.
- `ANTHROPIC_VERTEX_PROJECT_ID`, `CLAUDE_CODE_USE_VERTEX`, `CLOUD_ML_REGION` llegan via `env_file` y se exponen a VS Code mediante `remoteEnv`.

Claude Code detecta:

```bash
CLAUDE_CODE_USE_VERTEX=1
ANTHROPIC_VERTEX_PROJECT_ID=tu-project-id
CLOUD_ML_REGION=global
```

y usa Vertex AI como backend para los modelos Claude.

---

## 7. Configuración de Harness MCP Server v2

### Instalación en el DevContainer

En el Dockerfile o `postCreateCommand` (según cómo gestiones herramientas globales):

```bash
npm install -g harness-mcp-v2
```

### Variables clave (desde `devcontainer.env`)

- `HARNESS_API_KEY` — PAT de Harness.
- `HARNESS_DEFAULT_ORG_ID`
- `HARNESS_DEFAULT_PROJECT_ID`
- `HARNESS_BASE_URL`
- `HARNESS_TOOLSETS` — ej. `pipelines,services,connectors,logs,delegates`.

El bloque `mcp.servers.harness` en `devcontainer.json` define cómo se lanza el servidor MCP y qué variables utiliza.

---

## 8. Paso a paso para levantar el entorno

1. **Preparar credenciales GCP en el host**
   - Ejecutar:
     ```bash
     gcloud auth login
     gcloud auth application-default login
     gcloud config set project TU_PROJECT_ID
     ```
   - Confirmar:
     ```bash
     ls ~/.config/gcloud/application_default_credentials.json
     ```

2. **Crear `.devcontainer/devcontainer.env`**
   - Definir todas las variables Harness y Vertex según tu entorno.
   - Asegurarse de no commitearlo si contiene secretos.

3. **Revisar/crear `docker-compose.devcontainer.yml`**
   - Confirmar que contiene `env_file: devcontainer.env`.
   - Confirmar volumen de `~/.config/gcloud`.

4. **Revisar/crear `devcontainer.json`**
   - Extensiones VS Code necesarias.
   - Bloque `mcp` para Harness.
   - Bloque `remoteEnv` con variables GCP y Harness.

5. **Abrir el repo en VS Code**
   - Aceptar el mensaje de “Reopen in Container”.
   - O usar el comando: `Dev Containers: Rebuild and Reopen in Container`.

6. **Validar dentro del DevContainer**
   - En una terminal remota:
     ```bash
     env | grep -E 'HARNESS|ANTHROPIC_VERTEX|GOOGLE_CLOUD|CLOUD_ML'
     which harness-mcp-v2
     ```
   - Verificar que las variables tengan valores correctos y que `harness-mcp-v2` esté en el PATH.

7. **Validar Claude Code**
   - Abrir el panel de Claude Code en VS Code.
   - Pedirle: “¿Puedes listar el estado de los pipelines en Harness para este proyecto?”.
   - Confirmar que:
     - No pide login directo a Anthropic;
     - Usa Vertex AI (según configuración);
     - Puede usar las tools MCP de Harness (estado de pipelines, diagnósticos, reintentos).

---

## 9. Uso típico en el día a día

- Editar código Go / YAML / Terraform → guardas → se formatea automáticamente (Go con `gofmt`, lo demás con Prettier).
- Desde Claude Code:
  - Pedir generación o ajuste de pipelines Harness (YAML).
  - Ejecutar pipelines y monitorear estado.
  - Si falla, pedir:
    > “Diagnostica el error del último pipeline fallido y corrige el código/YAML necesario; luego reintenta.”

Claude, vía Harness MCP y Vertex AI, se encarga de:

1. Detectar la ejecución y su resultado.
2. Llamar a `harness_diagnose` para root cause.
3. Proponer y aplicar el cambio en el repo.
4. Volver a ejecutar el pipeline con `harness_execute`.

---

## 10. Notas y buenas prácticas

- Mantener `.devcontainer/devcontainer.env` fuera de git si contiene secretos.
- Centrarse en `containerEnv`/`remoteEnv` para variables que debe ver VS Code y Claude.
- Cada vez que cambies `devcontainer.env`, rehacer:
  - `Dev Containers: Rebuild and Reopen in Container`.
- Para debug de variables:
  - `env | grep HARNESS`
  - `env | grep ANTHROPIC_VERTEX`
  - `gcloud auth application-default print-access-token | head -c 20`
