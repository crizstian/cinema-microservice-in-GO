## DevContainer + Claude Code + MCP Setup (Harness + GitHub)

Este documento resume el setup completo para trabajar con Claude Code dentro de un DevContainer, usando MCP servers de Harness y GitHub como fuente principal de verdad para pipelines, PRs y diagnósticos.

---

## Tech Stack

- **Base OS**: `golang:alpine` (Dockerfile custom)
- **Lenguaje principal**: Go
- **Tooling en imagen**:
  - `git`, `bash`, `curl`, `wget`, `jq`, `yq`, `make`, `build-base`
  - `nodejs`, `npm`, `npx`
  - `docker-cli`
  - `golangci-lint`, `gopls`, `dlv`, `tfenv` + Terraform
  - `kubectl`
  - `gcloud` + `gke-gcloud-auth-plugin`
  - **Claude Code CLI**: `@anthropic-ai/claude-code` (global via npm)
  - **Harness MCP Server v2**: `harness-mcp-v2` (global via npm)
  - **GitHub CLI**: `gh` (instalado por distro en host o Dockerfile)
- **Repos auxiliares**:
  - `harness-skills` clonado en `/.harness-skills` dentro del contenedor

---

## Estructura de archivos relevante

```text
.devcontainer/
  devcontainer.json
  docker-compose.devcontainer.yml   # (opcional)
  scripts/
    post-create.sh                  # bootstrap one-shot
    post-start.sh                   # validación en cada arranque

.claude/
  CLAUDE.md                         # reglas de comportamiento
  settings.json                     # permisos, hooks, allowed tools
  settings.local.json               # overrides locales (no versionar)
  commands/
    create-pr.md
    triage-issue.md
  hooks/
    post-edit-format.sh
    prepare-pr-context.sh
    pre-commit-checks.sh

.mcp.json                           # MCP servers scope proyecto (opcional)
~/.claude.json                      # MCP servers scope usuario
```

---

## 1. Dockerfile del DevContainer

### Objetivo

Definir una imagen autosuficiente con Go + toolchain + CLIs de IA/MCP necesarias.

### Puntos clave

- Basado en `golang:alpine`.
- Instala `git`, `bash`, `curl`, `nodejs`, `npm`, `docker-cli`, `kubectl`, `gcloud`, `tfenv`, linters.
- Instala **Claude Code CLI** y **Harness MCP Server v2** globalmente con npm.
- Crea usuario no-root `devuser` con `bash` como shell.
- Prepara `GOPATH`, `GOMODCACHE`, `PATH` y `/workspace`.

### Fragmento relevante (resumen)

```Dockerfile
FROM golang:alpine

USER root
ENV GO111MODULE=on

# Herramientas base
RUN apk upgrade --no-cache && \
    apk add --no-cache \
      git build-base findutils make \
      bat exa coreutils wget curl bash \
      binutils jq sudo g++ py3-pip yq \
      nodejs npm shadow docker-cli ca-certificates

# Usuario no root
RUN useradd -m -s /bin/bash devuser && \
    echo "devuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# GOPATH
RUN mkdir -p /home/devuser/go/pkg/mod /home/devuser/go/bin && \
    chown -R devuser:devuser /home/devuser/go
ENV GOPATH=/home/devuser/go
ENV GOMODCACHE=/home/devuser/go/pkg/mod
ENV PATH="${PATH}:/home/devuser/go/bin"

# gcloud, kubectl, tfenv, linters, etc (omitido por brevedad)

# Claude Code CLI + Harness MCP v2
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g harness-mcp-v2

# Harness skills
RUN git clone --depth=1 https://github.com/harness/harness-skills.git .harness-skills

RUN mkdir -p /workspace && chown -R devuser:devuser /workspace
USER devuser
WORKDIR /workspace

CMD ["bash"]
```

---

## 2. Variables de entorno y Compose

### Variables `.devcontainer/devcontainer.env`

```env
HARNESS_API_KEY=pat.xxx.xxx.xxx
HARNESS_DEFAULT_ORG_ID=orgId
HARNESS_DEFAULT_PROJECT_ID=projectId
HARNESS_BASE_URL=https://app.harness.io
HARNESS_TOOLSETS=cd,ff,sto

GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxxxxxxxxxxxxxxxx
GH_TOKEN=ghp_xxxxxxxxxxxxxxxxx
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxx
```

### `docker-compose.devcontainer.yml` (montajes recomendados)

```yaml
services:
  devcontainer:
    environment:
      HARNESS_API_KEY: ${HARNESS_API_KEY}
      HARNESS_DEFAULT_ORG_ID: ${HARNESS_DEFAULT_ORG_ID}
      HARNESS_DEFAULT_PROJECT_ID: ${HARNESS_DEFAULT_PROJECT_ID}
      HARNESS_BASE_URL: ${HARNESS_BASE_URL}
      HARNESS_TOOLSETS: ${HARNESS_TOOLSETS}
      GITHUB_PERSONAL_ACCESS_TOKEN: ${GITHUB_PERSONAL_ACCESS_TOKEN}
      GH_TOKEN: ${GH_TOKEN}
      GITHUB_TOKEN: ${GITHUB_PERSONAL_ACCESS_TOKEN}
    volumes:
      - ../:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
      - ${HOME}/.config/gcloud:/home/devuser/.config/gcloud:rw
      - ${HOME}/.config/gh:/home/devuser/.config/gh:rw
      - ${HOME}/.claude:/home/devuser/.claude:rw # opcional
      - ${HOME}/.claude.json:/home/devuser/.claude.json:rw
```

---

## 3. `devcontainer.json`

### Puntos clave

- Usa la imagen build del Dockerfile.
- Inyecta variables de entorno.
- Configura MCP servers para VS Code en el DevContainer.
- Conecta scripts de lifecycle (`postCreateCommand`, `postStartCommand`).

### Ejemplo

```json
{
  "name": "Go + Claude Code + Harness MCP",
  "build": {
    "dockerfile": ".devcontainer/Dockerfile"
  },
  "runArgs": [
    "--env-file",
    "${localWorkspaceFolder}/.devcontainer/devcontainer.env"
  ],
  "remoteEnv": {
    "HARNESS_API_KEY": "${containerEnv:HARNESS_API_KEY}",
    "HARNESS_DEFAULT_ORG_ID": "${containerEnv:HARNESS_DEFAULT_ORG_ID}",
    "HARNESS_DEFAULT_PROJECT_ID": "${containerEnv:HARNESS_DEFAULT_PROJECT_ID}",
    "HARNESS_BASE_URL": "${containerEnv:HARNESS_BASE_URL}",
    "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}",
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}",
    "GH_TOKEN": "${containerEnv:GH_TOKEN}",
    "GITHUB_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}"
  },
  "customizations": {
    "vscode": {
      "extensions": [
        "anthropic.claude-code",
        "golang.go",
        "redhat.vscode-yaml",
        "humao.rest-client",
        "ms-vscode-remote.remote-containers"
      ],
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
              "HARNESS_TOOLSETS": "${containerEnv:HARNESS_TOOLSETS}"
            }
          },
          "github": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {
              "GITHUB_PERSONAL_ACCESS_TOKEN": "${containerEnv:GITHUB_PERSONAL_ACCESS_TOKEN}",
              "GH_TOKEN": "${containerEnv:GH_TOKEN}"
            }
          }
        }
      }
    }
  },
  "postCreateCommand": "sh /workspace/.devcontainer/scripts/post-create.sh",
  "postStartCommand": "sh /workspace/.devcontainer/scripts/post-start.sh"
}
```

---

## 4. Scripts de lifecycle

### `.devcontainer/scripts/post-create.sh` (one-shot)

```sh
#!/bin/sh
set -e

# Config git global si falta
if ! git config --global user.name >/dev/null 2>&1; then
  git config --global user.name "TU NOMBRE"
fi

if ! git config --global user.email >/dev/null 2>&1; then
  git config --global user.email "tu-correo@dominio.com"
fi

echo "[post-create] bootstrap inicial completado"
```

### `.devcontainer/scripts/post-start.sh` (cada arranque)

```sh
#!/bin/sh
set -e

echo "[post-start] validating devtoolchain..."

# Binarios clave
for cmd in claude harness-mcp-v2 gh gcloud kubectl terraform; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "WARN: $cmd not found in PATH"
  fi
done

# Vars Harness
[ -n "$HARNESS_API_KEY" ] || echo "WARN: HARNESS_API_KEY is empty"
[ -n "$HARNESS_DEFAULT_ORG_ID" ] || echo "WARN: HARNESS_DEFAULT_ORG_ID is empty"
[ -n "$HARNESS_DEFAULT_PROJECT_ID" ] || echo "WARN: HARNESS_DEFAULT_PROJECT_ID is empty"
[ -n "$HARNESS_BASE_URL" ] || echo "WARN: HARNESS_BASE_URL is empty"

# Vars GitHub
[ -n "$GITHUB_PERSONAL_ACCESS_TOKEN" ] || echo "WARN: GITHUB_PERSONAL_ACCESS_TOKEN is empty"
[ -n "$GH_TOKEN" ] || echo "WARN: GH_TOKEN is empty"

# Smoke test MCP Harness
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","clientInfo":{"name":"devcontainer-check","version":"1.0.0"},"capabilities":{}}}' \
  | harness-mcp-v2 >/dev/null 2>&1 || echo "WARN: harness-mcp-v2 initialize failed"

echo "[post-start] done"
```

---

## 5. Configuración MCP para Claude Code

Hay dos sistemas MCP:

- **VS Code MCP (DevContainer)** → configurado en `devcontainer.json`.
- **Claude Code MCP (cliente)** → se configura en `~/.claude.json` o `.mcp.json` en la raíz del proyecto.

### Opción A: `~/.claude.json` (scope usuario)

```json
{
  "mcpServers": {
    "harness": {
      "type": "stdio",
      "command": "harness-mcp-v2",
      "args": [],
      "env": {
        "HARNESS_API_KEY": "${env:HARNESS_API_KEY}",
        "HARNESS_DEFAULT_ORG_ID": "${env:HARNESS_DEFAULT_ORG_ID}",
        "HARNESS_DEFAULT_PROJECT_ID": "${env:HARNESS_DEFAULT_PROJECT_ID}",
        "HARNESS_BASE_URL": "${env:HARNESS_BASE_URL}",
        "HARNESS_TOOLSETS": "${env:HARNESS_TOOLSETS}"
      }
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${env:GITHUB_PERSONAL_ACCESS_TOKEN}",
        "GH_TOKEN": "${env:GH_TOKEN}"
      }
    }
  }
}
```

> Nota: `.mcp.json` de proyecto va en la **raíz del repo**, no dentro de `.claude/`.

---

## 6. `.claude/settings.json` (permisos y hooks)

### Permisos MCP y herramientas locales

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "Bash(git:*)",
      "Bash(gh:*)",
      "mcp__harness__*",
      "mcp__github__*"
    ],
    "deny": [
      "Read(.env*)",
      "Read(secrets/**)",
      "Bash(rm -rf:*)",
      "Bash(sudo:*)"
    ]
  },
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "sh /workspace/.claude/hooks/post-edit-format.sh"
          }
        ]
      }
    ]
  }
}
```

### Hooks `.claude/hooks/`

- `post-edit-format.sh`: formateo posterior a ediciones (Go / Prettier).
- `prepare-pr-context.sh`: mostrar `git status`, `git diff --stat`, `gh pr status`.
- `pre-commit-checks.sh`: correr `go test`, `terraform fmt -check`, etc.

Ejemplo simple de `post-edit-format.sh`:

```sh
#!/bin/sh
set -e

if command -v gofmt >/dev/null 2>&1; then
  find . -name "*.go" -type f -exec gofmt -w {} \; || true
fi

if command -v prettier >/dev/null 2>&1; then
  prettier --write . >/dev/null 2>&1 || true
fi
```

---

## 7. `CLAUDE.md` (reglas de comportamiento)

Contenido sugerido:

```markdown
## Tool selection rules

- Para pipelines, ejecuciones, fallos, diagnósticos y reintentos en Harness:
  - Usa primero las herramientas MCP de Harness (`mcp__harness__*`).
  - Solo usa `curl` directo contra la REST API como fallback cuando MCP no esté disponible.
- Para repositorios, PRs e issues de GitHub:
  - Usa primero las herramientas MCP de GitHub (`mcp__github__*`).
  - Usa `gh` para operaciones rápidas de CLI y fallback local.
  - Usa `git` para estado local, diffs, branches y commits.

## Workflow de PR

Antes de crear un PR:

1. Revisa `git status --short` y `git diff --stat`.
2. Ejecuta los tests relevantes (`go test ./...`, etc.).
3. Genera un resumen técnico claro de los cambios.
4. Crea el PR usando MCP de GitHub o `gh pr create` con título y descripción concretos.
5. Referencia issues relacionadas si aplica.

## Harness pipelines

- Siempre que un pipeline falle:
  1. Usa MCP de Harness para obtener el estado y logs del pipeline.
  2. Explica la causa raíz.
  3. Propón cambios de código/infra necesarios.
  4. Aplique la corrección y vuelva a ejecutar el pipeline.
```

---

## 8. Slash commands (`.claude/commands/`)

### `create-pr.md`

```markdown
---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git add:*), Bash(git commit:*), Bash(gh pr create:*), mcp__github__*
description: Create a GitHub PR from current branch
---

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status --short`
- Diff summary: !`git diff --stat`

## Task

1. Review current changes.
2. Generate a clear commit message if needed.
3. Ensure branch is pushed.
4. Create a GitHub pull request with a concise title and description.
5. Reference related issues if applicable.
```

---

## 9. Checklist de validación

### DevContainer

- [ ] `devcontainer.json` usa la imagen del Dockerfile.
- [ ] `postCreateCommand` apunta a `scripts/post-create.sh`.
- [ ] `postStartCommand` apunta a `scripts/post-start.sh`.
- [ ] MCP servers configurados en `customizations.vscode.mcp.servers.harness` y `.github`.

### Dentro del contenedor

- [ ] `which claude` devuelve ruta válida.
- [ ] `which harness-mcp-v2` devuelve ruta válida.
- [ ] `gh --version` funciona.
- [ ] `env | grep HARNESS` muestra todas las `HARNESS_*`.
- [ ] `env | grep GITHUB` muestra `GITHUB_PERSONAL_ACCESS_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`.
- [ ] `echo '{"...initialize..."}' | harness-mcp-v2` responde sin error.

### Claude Code / MCP

- [ ] `~/.claude.json` (o `.mcp.json` en raíz) define `mcpServers.harness` y `mcpServers.github`.
- [ ] `.claude/settings.json` incluye `mcp__harness__*` y `mcp__github__*` en `permissions.allow`.
- [ ] Al iniciar Claude Code:
  - [ ] “What MCP servers are available?” lista `harness` y `github`.
  - [ ] Claude puede llamar tools de Harness y GitHub sin pedir configuración extra.

### Workflow

- [ ] `.claude/CLAUDE.md` describe reglas para usar MCP como fuente primaria.
- [ ] Hooks en `.claude/hooks/` ejecutan formateo y checks básicos.
- [ ] Slash commands (`create-pr`, `triage-issue`) funcionan y usan MCP/gh/git según lo esperado.

---

Este README resume el setup completo para que cada sesión en el DevContainer tenga:

- todas las CLIs instaladas,
- variables de entorno cargadas,
- MCP servers de Harness y GitHub disponibles tanto para VS Code como para Claude Code,
- y un workflow de trabajo guiado por MCP en lugar de llamadas manuales.
