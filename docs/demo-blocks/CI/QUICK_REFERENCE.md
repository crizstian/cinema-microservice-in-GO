# CI/CD Demo Quick Reference Card

> Cheat sheet para demos y ejercicios de Harness CI/CD

## Comandos Principales

```bash
# Ver escenarios disponibles
task demo:list

# Ejecutar demo completo
task demo:setup SCENARIO=01-basic-ci
task demo:run SCENARIO=01-basic-ci
task demo:validate SCENARIO=01-basic-ci

# Resetear
task demo:reset SCENARIO=01-basic-ci
task lab:reset  # Reset todo

# Ejecucion manual del pipeline
task pipeline:run SERVICE=booking              # Validate stage
task pipeline:run SERVICE=movie STAGE=build    # Build stage
task pipeline:run:multi SERVICES=booking,movie # Multiple services
task pipeline:status EXEC_ID=xxxxx             # Check status
```

## Escenarios Disponibles

| ID | Nombre | Duracion | Audiencia |
|----|--------|----------|-----------|
| `01-basic-ci` | Basic CI Pipeline | 10 min | Nuevos en CI/CD |
| `02-monorepo-looping` | Monorepo Looping | 15 min | Platform teams |
| `03-security-gates` | Security Gates | 15 min | DevSecOps |
| `04-ai-devops-mcp` | AI-Assisted DevOps | 20 min | CTOs, Innovation |
| `05-full-pipeline` | Full Pipeline | 20 min | Release teams |

## Workflow de Demo

```
┌─────────────────────────────────────────────────────────┐
│  1. SETUP                                               │
│     task demo:setup SCENARIO=XX                         │
│     - Crea branch demo/scenario-XX                      │
│     - Aplica cambios predefinidos                       │
└──────────────────────────┬──────────────────────────────┘
                           │
                           v
┌─────────────────────────────────────────────────────────┐
│  2. RUN                                                 │
│     task demo:run SCENARIO=XX                           │
│     - Push branch                                       │
│     - Crea PR                                           │
│     - Trigger pipeline                                  │
└──────────────────────────┬──────────────────────────────┘
                           │
                           v
┌─────────────────────────────────────────────────────────┐
│  3. OBSERVE (Harness UI)                                │
│     - Navegar a Pipelines                               │
│     - Ver CI_Orchestrator                               │
│     - Ver CI_Golang_v2 (child)                          │
│     - Destacar puntos clave                             │
└──────────────────────────┬──────────────────────────────┘
                           │
                           v
┌─────────────────────────────────────────────────────────┐
│  4. VALIDATE                                            │
│     task demo:validate SCENARIO=XX                      │
│     - Verifica resultados esperados                     │
│     - Muestra metricas                                  │
└──────────────────────────┬──────────────────────────────┘
                           │
                           v
┌─────────────────────────────────────────────────────────┐
│  5. RESET (para siguiente demo)                         │
│     task demo:reset SCENARIO=XX                         │
└─────────────────────────────────────────────────────────┘
```

## Checklist Pre-Demo

```
[ ] task lab:reset ejecutado
[ ] Harness UI abierto
[ ] VS Code con Claude Code (para MCP demo)
[ ] Terminal visible
[ ] Conexion a internet estable
[ ] Harness MCP Server conectado
```

## Puntos Clave por Escenario

### 01-basic-ci
- Pipeline detecta automaticamente servicio modificado
- Test Intelligence reduce tests ejecutados
- JUnit reports integrados

### 02-monorepo-looping
- Un pipeline, N servicios
- Repeat strategy con maxConcurrency
- Fallo parcial no detiene otros

### 03-security-gates
- SAST/SCA bloquean vulnerabilidades
- Escaneo scoped por servicio
- PR comment con detalles

### 04-ai-devops-mcp
- Lenguaje natural → Pipeline
- Diagnostico automatico
- Exclusivo Harness + Claude

### 05-full-pipeline
- Semantic versioning por servicio
- Conventional commits con scope
- Tags independientes

## Troubleshooting Rapido

| Problema | Solucion |
|----------|----------|
| Pipeline no triggerea | Verificar trigger YAML y pattern |
| PR no se crea | `gh auth login` |
| MCP no conecta | Verificar `claude mcp list` |
| Branch existe | `task demo:reset SCENARIO=XX` |

## URLs Importantes

- **Harness UI**: https://app.harness.io/ng/
- **Pipeline Studio**: Pipelines → CI_Golang_v2 → Edit
- **Executions**: Pipelines → Executions

## Contacto

Para issues o mejoras del lab system:
- Ver: `docs/demo-blocks/CI/REPEATABLE_LAB_SYSTEM.md`
- Archivo de scripts: `platform/scripts/taskfile/demo-lab.sh`
