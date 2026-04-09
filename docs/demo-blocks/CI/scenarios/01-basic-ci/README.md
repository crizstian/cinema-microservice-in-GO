# Scenario 01: Basic CI Pipeline

> Demo de pipeline basico de CI con Harness

## Objetivo

Demostrar un pipeline de CI que:
1. Detecta cambios en un servicio
2. Ejecuta analisis de codigo (Complexity, Duplication)
3. Ejecuta tests unitarios
4. Genera reportes JUnit

## Audiencia

- Equipos comenzando con CI/CD
- Developers nuevos en Harness
- Comparacion vs GitHub Actions

## Duracion

10-15 minutos

---

## Setup

```bash
# Desde el directorio raiz del repo
task demo:setup SCENARIO=01-basic-ci
```

### Que hace el setup?

1. Crea branch `demo/scenario-01-basic-ci` desde `step-1`
2. Aplica cambios predefinidos en `services/movie/`
3. Prepara el PR (sin push)

### Cambios aplicados

```diff
# services/movie/internal/api/movie.go
- // GetMovie returns a movie by ID
+ // GetMovie retrieves a movie by its unique identifier
  func (h *Handler) GetMovie(w http.ResponseWriter, r *http.Request) {

# services/movie/internal/api/movie_test.go
+ func TestGetMovie_NotFound(t *testing.T) {
+     // New test case added
+ }
```

---

## Ejecucion

### Paso 1: Crear PR

```bash
task demo:run SCENARIO=01-basic-ci
```

Esto:
1. Push del branch a origin
2. Crea PR via `gh pr create`
3. Trigger automatico del CI_Orchestrator

### Paso 2: Observar Pipeline (Harness UI)

1. Abrir Harness UI → Pipelines → CI_Orchestrator
2. Ver ejecucion en progreso

**Puntos a destacar**:

| Paso | Que mostrar | Diferenciador |
|------|-------------|---------------|
| Detect | Logs de deteccion | Native Harness expressions |
| Classify | "Go (go.mod found)" | Manifest file detection |
| Trigger Child | Pipeline chaining | No API calls needed |

3. Navegar a CI_Golang_v2 (child pipeline)

**Puntos a destacar**:

| Step | Que mostrar |
|------|-------------|
| Complexity Analysis | gocyclo output, threshold check |
| Code Duplication | dupl output, warning mode |
| Unit Tests | JUnit report integrado |
| Test Intelligence | "Tests Selected: 12" vs "Tests Total: 36" |

### Paso 3: Mostrar Resultados

```bash
# Ver PR comment automatico
gh pr view --comments

# Ver Test Intelligence metrics
# En Harness UI: Tests tab → Selection stats
```

---

## Validacion

```bash
task demo:validate SCENARIO=01-basic-ci
```

### Criterios de Exito

| Criterio | Esperado |
|----------|----------|
| Pipeline Status | Success |
| Services Detected | `["movie"]` |
| Complexity Analysis | Pass (no functions > 15) |
| Unit Tests | Pass |
| JUnit Report | Generated |
| PR Comment | Posted |

---

## Puntos Clave (Tell)

### Antes (Tell - 2 min)

> "En GitHub Actions, para lograr esto necesitarian un workflow de ~80 lineas, configurar actions de terceros para reportes JUnit, y no tendrian Test Intelligence. Ademas, cada servicio requeriria su propio workflow."

### Durante (Show - 8 min)

1. "Observen como el Orchestrator detecta automaticamente que solo `movie` cambio"
2. "El Child Pipeline recibe la lista de servicios como INPUT, no la detecta de nuevo"
3. "Complexity Analysis falla si alguna funcion excede 15 - esto es configurable"
4. "Test Intelligence selecciono solo 12 de 36 tests - 66% de ahorro"

### Despues (Tell - 2 min)

> "Lo que vieron en 5 minutos es un pipeline de CI completo que escala automaticamente. Cuando agreguen el servicio 9, no necesitan modificar nada - el Orchestrator lo detectara y procesara."

---

## Troubleshooting

### Pipeline no se triggerea

```bash
# Verificar trigger configuration
cat .harness/pipelines/CI/ci-orchestrator-trigger.yaml

# Verificar que el PR tiene archivos en services/*
gh pr view --json files
```

### Test Intelligence no selecciona tests

```bash
# Verificar que buildIntelligence esta habilitado
grep -A 2 "buildIntelligence" .harness/pipelines/CI/CI-Golang-v2.yaml
```

---

## Reset

```bash
# Volver al estado inicial
task demo:reset SCENARIO=01-basic-ci

# Esto elimina:
# - Branch demo/scenario-01-basic-ci
# - PR asociado (si existe)
```

---

## Archivos Relacionados

- [CI_Orchestrator.yaml](/.harness/pipelines/CI/CI-Orchestrator.yaml)
- [CI-Golang-v2.yaml](/.harness/pipelines/CI/CI-Golang-v2.yaml)
- [ci-monorepo-strategy.md](/docs/architecture/ci-monorepo-strategy.md)
