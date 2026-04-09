# Repeatable CI/CD Lab System

> Sistema de laboratorio repetible para demos, pruebas y ejercicios de Harness CI/CD

## Tabla de Contenidos

1. [Vision General](#vision-general)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Escenarios de Demo](#escenarios-de-demo)
4. [Comandos de Reset](#comandos-de-reset)
5. [Ejercicios Guiados](#ejercicios-guiados)
6. [Validacion Automatica](#validacion-automatica)

---

## Vision General

### Problema

Las demos y ejercicios de CI/CD requieren:
- Estado inicial conocido y repetible
- Cambios predefinidos que triggeen pipelines
- Resultados predecibles para validar
- Capacidad de resetear y repetir

### Solucion

Un sistema de **Demo Scenarios** con:

```
┌─────────────────────────────────────────────────────────────────┐
│                    REPEATABLE LAB SYSTEM                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │   RESET     │────>│   SETUP     │────>│   EXECUTE   │       │
│  │  Baseline   │     │  Scenario   │     │    Demo     │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│         │                   │                   │               │
│         v                   v                   v               │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐       │
│  │  Clean git  │     │ Apply diff  │     │ Push + CI   │       │
│  │  branches   │     │ Load data   │     │ Validate    │       │
│  └─────────────┘     └─────────────┘     └─────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Arquitectura del Sistema

### Branches de Demo

| Branch | Proposito | Estado |
|--------|-----------|--------|
| `step-1` | Baseline limpio | Main estable |
| `demo/scenario-01-basic-ci` | Demo basico de CI | Pre-configurado |
| `demo/scenario-02-monorepo` | Demo de looping strategy | Pre-configurado |
| `demo/scenario-03-security` | Demo de shift-left security | Pre-configurado |
| `demo/scenario-04-ai-devops` | Demo de MCP + Claude | Pre-configurado |
| `exercise/*` | Branches para ejercicios | Reseteable |

### Estructura de Escenarios

```
docs/demo-blocks/CI/
├── REPEATABLE_LAB_SYSTEM.md      # Este documento
├── scenarios/
│   ├── 01-basic-ci/
│   │   ├── README.md             # Instrucciones
│   │   ├── setup.sh              # Script de setup
│   │   ├── changes.patch         # Diff a aplicar
│   │   ├── expected-results.json # Resultados esperados
│   │   └── validate.sh           # Script de validacion
│   ├── 02-monorepo-looping/
│   ├── 03-security-gates/
│   ├── 04-ai-devops-mcp/
│   └── 05-full-pipeline/
├── fixtures/
│   ├── services/                 # Archivos de prueba
│   └── data/                     # Datos de seed
└── scripts/
    ├── reset-lab.sh              # Reset completo
    ├── setup-scenario.sh         # Setup de escenario
    └── validate-scenario.sh      # Validacion
```

---

## Escenarios de Demo

### Scenario 01: Basic CI Pipeline

**Objetivo**: Demostrar pipeline basico de CI con format, lint, test, build.

**Duracion**: 10 minutos

**Audiencia**: Equipos nuevos en CI/CD

```bash
# Setup
task demo:setup SCENARIO=01-basic-ci

# Cambios que se aplican automaticamente:
# - Modifica services/movie/internal/api/movie.go (fix typo)
# - Agrega un test en services/movie/internal/api/movie_test.go

# Ejecutar demo
task demo:run SCENARIO=01-basic-ci

# El pipeline debe:
# 1. Detectar cambio en movie service
# 2. Ejecutar Complexity Analysis (pass)
# 3. Ejecutar Code Duplication (pass)
# 4. Ejecutar Unit Tests (pass)
# 5. Build exitoso

# Validar resultado
task demo:validate SCENARIO=01-basic-ci
```

**Puntos Clave a Destacar**:
- Pipeline se ejecuta automaticamente por PR trigger
- Variables nativas de Harness (no scripts bash)
- Test Intelligence selecciona solo tests relevantes
- JUnit reports integrados

---

### Scenario 02: Monorepo Looping Strategy

**Objetivo**: Demostrar como un pipeline procesa multiples servicios en paralelo.

**Duracion**: 15 minutos

**Audiencia**: Platform teams con monorepos

```bash
# Setup
task demo:setup SCENARIO=02-monorepo-looping

# Cambios que se aplican:
# - Modifica services/movie/internal/api/movie.go
# - Modifica services/booking/internal/api/booking.go
# - Modifica services/payment/internal/api/payment.go

# Ejecutar demo
task demo:run SCENARIO=02-monorepo-looping

# El pipeline debe:
# 1. Orchestrator detecta 3 servicios: movie, booking, payment
# 2. Classifica todos como Go (manifest detection)
# 3. Child pipeline CI_Golang_v2 recibe SERVICES_JSON
# 4. Ejecuta Code Quality en paralelo (maxConcurrency: 4)
# 5. Ejecuta Security Scans por servicio (workspace scoped)
# 6. Ejecuta Tests por servicio

# Validar
task demo:validate SCENARIO=02-monorepo-looping
```

**Puntos Clave a Destacar**:
- Un pipeline, N servicios (vs N workflows duplicados)
- Repeat strategy con maxConcurrency
- workspace: services/<+repeat.item> para scans
- Fallo parcial no detiene otros servicios

---

### Scenario 03: Shift-Left Security Gates

**Objetivo**: Demostrar como el pipeline bloquea vulnerabilidades antes del merge.

**Duracion**: 15 minutos

**Audiencia**: Security teams, DevSecOps

```bash
# Setup - incluye vulnerabilidad intencional
task demo:setup SCENARIO=03-security-gates

# Cambios que se aplican:
# - Agrega dependencia vulnerable en services/payment/go.mod
# - Agrega codigo con SQL injection en payment.go

# Ejecutar demo
task demo:run SCENARIO=03-security-gates

# El pipeline debe:
# 1. SAST detecta SQL injection - FAIL (bloqueante)
# 2. SCA detecta CVE en dependencia - FAIL (bloqueante)
# 3. Pipeline se detiene con mensaje claro
# 4. PR comment muestra detalles del fallo

# Mostrar resolucion
task demo:fix SCENARIO=03-security-gates
task demo:run SCENARIO=03-security-gates  # Ahora pasa

# Validar
task demo:validate SCENARIO=03-security-gates
```

**Puntos Clave a Destacar**:
- Vulnerabilidades bloqueadas ANTES de merge
- fail_on_severity: high para SAST/SCA
- Escaneo por servicio, no de todo el repo
- PR comment con detalles accionables

---

### Scenario 04: AI-Assisted DevOps (MCP)

**Objetivo**: Demostrar creacion y diagnostico de pipelines con lenguaje natural.

**Duracion**: 20 minutos

**Audiencia**: Innovation teams, CTOs

```bash
# Setup
task demo:setup SCENARIO=04-ai-devops-mcp

# Este escenario se ejecuta interactivamente en VS Code
# Ver: docs/demo-blocks/CI/HARNESS_SE_DEMO_PLAYBOOK.md (Demo Avanzado)

# Pasos:
# 1. Abrir VS Code con Claude Code
# 2. Ejecutar prompts predefinidos
# 3. Mostrar MCP tools en accion

# Prompts predefinidos:
cat docs/demo-blocks/CI/scenarios/04-ai-devops-mcp/prompts.md
```

**Puntos Clave a Destacar**:
- Lenguaje natural → Pipeline YAML
- Diagnostico automatico de fallos
- Ejecucion directa desde editor
- Exclusivo de Harness + Claude

---

### Scenario 05: Full Pipeline (Build + Release)

**Objetivo**: Demostrar el ciclo completo de CI hasta release con semantic versioning.

**Duracion**: 20 minutos

**Audiencia**: Engineering managers, release teams

```bash
# Setup
task demo:setup SCENARIO=05-full-pipeline

# Cambios que se aplican:
# - feat(movie): add new endpoint for recommendations
# - Commit message con conventional commits

# Ejecutar demo (simular PR merge)
task demo:run SCENARIO=05-full-pipeline --merged

# El pipeline debe:
# 1. Detectar PR merged
# 2. Semantic Version: feat(movie) → MINOR bump
# 3. Build binary
# 4. Build + Push Docker image
# 5. Container SCA scan
# 6. Create git tag: movie-v0.2.0
# 7. PR comment con resumen

# Validar
task demo:validate SCENARIO=05-full-pipeline
```

**Puntos Clave a Destacar**:
- Semantic versioning automatico por servicio
- Conventional commits con scope
- Tags independientes por servicio
- Container security scan post-build

---

## Comandos de Reset

### Reset Completo

```bash
# Resetear todo el lab a estado inicial
task lab:reset

# Esto hace:
# 1. git checkout step-1
# 2. git clean -fd
# 3. Eliminar branches exercise/*
# 4. Limpiar datos de Harness (optional)
```

### Reset de Escenario Especifico

```bash
# Resetear solo un escenario
task lab:reset SCENARIO=01-basic-ci

# Resetear y re-setup
task lab:restart SCENARIO=01-basic-ci
```

### Reset de Datos

```bash
# Resetear solo datos (MongoDB, Redis)
task lab:reset:data

# Resetear solo pipelines en Harness
task lab:reset:pipelines
```

---

## Ejercicios Guiados

### Ejercicio 1: Agregar Nuevo Servicio al CI

**Objetivo**: El participante agrega un nuevo servicio al monorepo y verifica que el CI lo detecta.

**Tiempo**: 30 minutos

**Instrucciones**:

```bash
# 1. Setup del ejercicio
task exercise:start NAME=add-new-service

# 2. Crear nuevo servicio
mkdir -p services/recommendation
cat > services/recommendation/go.mod << 'EOF'
module github.com/cinema/recommendation
go 1.22
EOF

# 3. Agregar codigo basico
# ... (instrucciones detalladas en ejercicio)

# 4. Crear PR y verificar que CI lo detecta
git add services/recommendation
git commit -m "feat(recommendation): add new recommendation service"
git push origin exercise/add-new-service

# 5. Verificar en Harness:
# - CI_Orchestrator detecta services/recommendation/*
# - Classifica como Go (go.mod found)
# - CI_Golang_v2 ejecuta con SERVICES_JSON=["recommendation"]

# 6. Validar
task exercise:validate NAME=add-new-service
```

---

### Ejercicio 2: Configurar Quality Gates

**Objetivo**: Modificar thresholds de complejidad y duplicacion.

**Tiempo**: 20 minutos

**Instrucciones**:

```bash
# 1. Setup
task exercise:start NAME=quality-gates

# 2. Modificar pipeline local
# Cambiar MAX_COMPLEXITY de 15 a 10
# Cambiar Code Duplication de warning a fail

# 3. Agregar codigo complejo que exceda threshold
# ... (instrucciones en ejercicio)

# 4. Ejecutar y verificar que falla
# 5. Corregir y ejecutar de nuevo

# 6. Validar
task exercise:validate NAME=quality-gates
```

---

### Ejercicio 3: Implementar Rollback

**Objetivo**: Configurar rollback automatico en caso de fallo de health check.

**Tiempo**: 45 minutos

**Instrucciones detalladas en**:
```
docs/demo-blocks/CI/exercises/03-rollback/README.md
```

---

## Validacion Automatica

### Script de Validacion

```bash
#!/bin/bash
# validate-scenario.sh

SCENARIO=$1

case $SCENARIO in
  "01-basic-ci")
    # Verificar que pipeline ejecuto
    EXECUTION=$(harness_list execution --pipeline CI_Golang_v2 --limit 1)
    STATUS=$(echo $EXECUTION | jq -r '.status')
    
    if [ "$STATUS" == "Success" ]; then
      echo "PASS: Pipeline executed successfully"
    else
      echo "FAIL: Pipeline status is $STATUS"
      exit 1
    fi
    
    # Verificar que solo movie service fue procesado
    SERVICES=$(echo $EXECUTION | jq -r '.inputs.SERVICES_JSON')
    if [ "$SERVICES" == '["movie"]' ]; then
      echo "PASS: Correct service detected"
    else
      echo "FAIL: Expected [movie], got $SERVICES"
      exit 1
    fi
    ;;
    
  "02-monorepo-looping")
    # Verificar 3 servicios
    # ...
    ;;
    
  *)
    echo "Unknown scenario: $SCENARIO"
    exit 1
    ;;
esac
```

### Criterios de Validacion por Escenario

| Scenario | Criterios |
|----------|-----------|
| 01-basic-ci | Pipeline Success, 1 service, Tests passed |
| 02-monorepo-looping | 3 services detected, Parallel execution, All pass |
| 03-security-gates | SAST/SCA fail, then pass after fix |
| 04-ai-devops-mcp | Pipeline created via MCP, Execution successful |
| 05-full-pipeline | Tag created, Image pushed, Version bumped |

---

## Quick Reference

### Taskfile Commands

```bash
# Demo commands
task demo:list                    # Listar escenarios disponibles
task demo:setup SCENARIO=XX       # Setup de escenario
task demo:run SCENARIO=XX         # Ejecutar demo
task demo:validate SCENARIO=XX    # Validar resultado
task demo:reset SCENARIO=XX       # Reset de escenario

# Exercise commands
task exercise:start NAME=XX       # Iniciar ejercicio
task exercise:hint NAME=XX        # Mostrar pista
task exercise:solution NAME=XX    # Mostrar solucion
task exercise:validate NAME=XX    # Validar ejercicio

# Lab commands
task lab:reset                    # Reset completo
task lab:status                   # Estado actual del lab
task lab:cleanup                  # Limpiar recursos
```

### Checklist Pre-Demo

- [ ] `task lab:reset` ejecutado
- [ ] VS Code con Claude Code instalado
- [ ] Harness MCP Server conectado
- [ ] Terminal visible para comandos
- [ ] Harness UI abierto en browser
- [ ] Escenario correcto seleccionado

---

*Sistema de laboratorio para Cinema Microservices CI/CD*
*Ultima actualizacion: 2026-04-09*
