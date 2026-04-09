# CI/CD Demo Blocks - Harness

> Recursos completos para demos, pruebas y ejercicios de Harness CI/CD

## Quick Start

```bash
# Ver escenarios disponibles
task demo:list

# Ejecutar un demo (ejemplo: basic CI)
task demo:setup SCENARIO=01-basic-ci
task demo:run SCENARIO=01-basic-ci
task demo:validate SCENARIO=01-basic-ci

# Resetear cuando termine
task demo:reset SCENARIO=01-basic-ci
```

## Contenido

| Documento | Descripcion |
|-----------|-------------|
| [QUICK_REFERENCE.md](./QUICK_REFERENCE.md) | Cheat sheet para demos |
| [REPEATABLE_LAB_SYSTEM.md](./REPEATABLE_LAB_SYSTEM.md) | Sistema completo de laboratorio |
| [HARNESS_SE_DEMO_PLAYBOOK.md](./HARNESS_SE_DEMO_PLAYBOOK.md) | Playbook detallado para SEs |
| [HARNESS_DEMO_PROMPTS.md](./HARNESS_DEMO_PROMPTS.md) | Prompts para Claude/MCP |
| [HARNESS_DEMO_CONTEXT.md](./HARNESS_DEMO_CONTEXT.md) | Contexto del repositorio |

## Escenarios Disponibles

### Demo Scenarios

| Scenario | Duracion | Descripcion |
|----------|----------|-------------|
| `01-basic-ci` | 10 min | Pipeline basico con format, test, build |
| `02-monorepo-looping` | 15 min | Multiple servicios en paralelo |
| `03-security-gates` | 15 min | Shift-left security con SAST/SCA |
| `04-ai-devops-mcp` | 20 min | AI-Assisted DevOps con MCP |
| `05-full-pipeline` | 20 min | Build + Release + Semantic versioning |

### Ejercicios

| Ejercicio | Tiempo | Descripcion |
|-----------|--------|-------------|
| `add-new-service` | 30 min | Agregar servicio al monorepo |
| `quality-gates` | 20 min | Configurar thresholds |
| `rollback` | 45 min | Implementar rollback automatico |

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                    REPEATABLE LAB SYSTEM                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   step-1 (baseline)                                         │
│      │                                                      │
│      ├── demo/scenario-01-basic-ci                          │
│      ├── demo/scenario-02-monorepo-looping                  │
│      ├── demo/scenario-03-security-gates                    │
│      ├── demo/scenario-04-ai-devops-mcp                     │
│      ├── demo/scenario-05-full-pipeline                     │
│      │                                                      │
│      └── exercise/* (user branches)                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Pipeline Architecture

```
┌────────────────────┐
│   PR Trigger       │
│   ^services/.+     │
└─────────┬──────────┘
          │
          v
┌────────────────────┐
│  CI_Orchestrator   │  Language Agnostic
│  - Detect changes  │
│  - Classify by     │
│    manifest files  │
└─────────┬──────────┘
          │
          v
┌────────────────────┐
│  CI_Golang_v2      │  Go Services
│  - Code Quality    │
│  - Security Scans  │
│  - Tests           │
│  - Build & Release │
└────────────────────┘
```

## Comandos Taskfile

```bash
# Demo
task demo:list                    # Listar escenarios
task demo:setup SCENARIO=XX       # Setup
task demo:run SCENARIO=XX         # Ejecutar
task demo:validate SCENARIO=XX    # Validar
task demo:reset SCENARIO=XX       # Reset
task demo:fix SCENARIO=03-*       # Fix (security)

# Lab
task lab:reset                    # Reset completo
task lab:status                   # Estado actual
task lab:cleanup                  # Limpiar recursos

# Exercise
task exercise:start NAME=XX       # Iniciar ejercicio
task exercise:validate NAME=XX    # Validar
task exercise:solution NAME=XX    # Ver solucion
```

## Documentacion Relacionada

- [CI Monorepo Strategy](/docs/architecture/ci-monorepo-strategy.md)
- [Development Guide](/docs/development/README.md)
- [dev:up Laboratory](/docs/development/dev-up-laboratory.md)

---

*Sistema de demos para Cinema Microservices - Harness CI/CD*
*Ultima actualizacion: 2026-04-09*
