# Contexto del proyecto

Este proyecto usa Harness CI/CD. Tienes acceso al Harness MCP Server (harness-mcp-v2).

## Reglas de comportamiento para pipelines

1. **Antes de ejecutar cualquier pipeline**, siempre verifica el estado actual con:
   `harness_status(org_id="default", project_id="TU_PROJECT_ID")`

2. **Después de ejecutar un pipeline**, monitorea usando:
   `harness_list(resource_type="execution", filters={"pipelineIdentifier": "PIPELINE_ID"})`

3. **Si un pipeline falla**, diagnostica inmediatamente con:
   `harness_diagnose(execution_id="EXECUTION_ID")`
   - Analiza el stage/step que falló
   - Revisa logs con `harness_list(resource_type="execution_log")`
   - Propón y aplica la corrección necesaria
   - Re-ejecuta con `harness_execute(resource_type="pipeline", action="retry", resource_id="PIPELINE_ID")`

4. **Para reintentar**, usa `action="retry"` cuando el pipeline tiene lógica de reintento,
   o `action="run"` para una ejecución limpia.

5. **Nunca elimines recursos de Harness** sin confirmación explícita.

## Variables de entorno disponibles

- HARNESS_API_KEY: en ~/.env
- HARNESS_DEFAULT_PROJECT_ID: tu-proyecto
- HARNESS_DEFAULT_ORG_ID: default

## Stack del proyecto

- Go (golang:alpine)
- Kubernetes (kubectl disponible)
- Terraform
- gcloud CLI

## Harness Skills disponibles

- /run-pipeline — Ejecutar pipeline y monitorear progreso
- /debug-pipeline — Analizar fallos con causa raíz
- /create-pipeline — Generar pipeline YAML desde descripción natural
- /manage-delegates — Verificar salud de delegates
- /analyze-costs — Optimización de costos en cloud
- /dora-metrics — Métricas DORA del equipo

## GitHub workflow rules

- Usa `git` para operaciones locales: status, diff, branch, commit.
- Usa `gh` para operaciones GitHub rápidas desde terminal: PR status, issue view, checks.
- Usa el GitHub MCP server para operaciones remotas estructuradas sobre PRs, issues, repos y metadatos cuando necesites contexto enriquecido.
- Antes de crear un PR:
  1. revisa `git diff --stat`,
  2. ejecuta tests relevantes,
  3. genera un resumen técnico claro,
  4. crea el PR con título y descripción concretos.
- No cierres issues ni hagas merge sin instrucción explícita.

## Tool selection rules

- Para pipelines, ejecuciones, fallos, diagnósticos y reintentos en Harness, usa las herramientas MCP de Harness antes de usar curl o llamadas REST manuales.
- Para repositorios, pull requests, issues y metadata de GitHub, usa las herramientas MCP de GitHub antes de usar la API REST manual.
- Usa `gh` para operaciones rápidas de CLI y fallback local.
- Usa `git` para estado local, diffs, branches y commits.
- Si una herramienta MCP no está disponible en la sesión, indícalo explícitamente y valida si el servidor está cargado antes de continuar con un workaround.

## Web search rules

- Para cualquier búsqueda de información en la web, noticias recientes, documentación externa o datos no presentes en este repo:
  - Usa primero las herramientas MCP del servidor `perplexity` (por ejemplo `perplexity_search` o `perplexity_deep_research`), en lugar de intentar responder sin herramientas.
- Solo responde sin usar Perplexity cuando:
  - La respuesta se pueda deducir completamente del contexto local del proyecto (código, docs, etc.).
- Cuando uses Perplexity:
  1. Formula una query clara y específica.
  2. Resume los hallazgos relevantes para la tarea actual.
  3. Referencia explícitamente si la información es reciente o puede estar sujeta a cambios.

---

## CI/CD Pipeline Architecture (v3.3)

### Pipeline Overview

El pipeline `CI-Unified-v3` está optimizado para monorepo de microservicios Go.

**Flujo simplificado:**
```
PR Open → Validate Code (no container)
PR Merge → Build + Scan + Conditional Push
```

### Stages

| Stage | Trigger | Duración | Descripción |
|-------|---------|----------|-------------|
| Validate Code | `RUN_MODE=validate` | ~3-5 min | Lint, security, tests per-service |
| Build and Release | `RUN_MODE=full` | ~5-8 min | Build, scan, push (si pasa gate) |

### Security Scanners (7 total)

**Code Security (Stage 1):**
- Harness SAST (Semgrep) - vulnerabilidades de código
- Snyk SAST - vulnerabilidades de código (segundo opinion)
- Harness SCA - dependencias
- Snyk SCA - dependencias (segundo opinion)  
- Gitleaks - secretos en código

**Container Security (Stage 2):**
- Trivy - vulnerabilidades de imagen + SBOM
- Harness Container - vulnerabilidades de imagen

### Security Gate

```
Critical: 0 (bloquea)
High: ≤5 (permite)
```

Si falla: imagen NO se publica, PR recibe comentario con detalles.

### Variables de Pipeline

| Variable | Valores | Descripción |
|----------|---------|-------------|
| `RUN_MODE` | validate, full | Modo de ejecución |
| `SERVICES` | booking,movie,... | Servicios a procesar (CSV) |
| `COVERAGE_THRESHOLD` | 80 | Cobertura mínima (%) |
| `SECURITY_GATE_CRITICAL` | 0 | Vulnerabilidades critical permitidas |
| `SECURITY_GATE_HIGH` | 5 | Vulnerabilidades high permitidas |

### Semantic Versioning

El pipeline determina el bump automáticamente según el prefijo del branch:

| Prefijo | Bump | Ejemplo |
|---------|------|---------|
| `major/`, `breaking/` | major | v1.0.0 → v2.0.0 |
| `feature/`, `feat/` | minor | v1.0.0 → v1.1.0 |
| `fix/`, otros | patch | v1.0.0 → v1.0.1 |

### Looping Strategy (Monorepo)

Cada StepGroup itera sobre `SERVICES.split(",")` con concurrency controlada:
- Code Quality: `maxConcurrency: 3`
- Code Security: `maxConcurrency: 2`
- Tests: `maxConcurrency: 3`
- Build & Publish: `maxConcurrency: 2`

### Archivos Clave

- Pipeline: `.harness/pipelines/CI/CI-Unified-v3.yaml`
- Dockerfile: `platform/docker/go-service/Dockerfile`
- Strategy: `docs/operations/ci-cd-strategy.md`
- Runbook: `docs/operations/ci-runbook.md`

---

## Template Architecture (Multi-Language)

### Estructura de Templates

```
.harness/templates/
├── stages/
│   ├── security-scan-code.yaml    # Compartido (cualquier lenguaje)
│   └── container-scan.yaml        # Compartido (cualquier imagen)
├── steps/
│   ├── build-go.yaml              # Go: go build, go test, golint
│   ├── build-java.yaml            # Java: maven/gradle, junit
│   ├── build-node.yaml            # Node: npm/yarn/pnpm, jest
│   └── build-python.yaml          # Python: pip/poetry, pytest
├── pipelines/
│   └── ci-template-go.yaml        # Ejemplo de pipeline con templates
└── policies/
    └── require-security-scans.rego # OPA Policy para gobernanza
```

### Estrategia de Reutilización

| Componente | Tipo | Reutilización |
|------------|------|---------------|
| Security Scan Code | Stage Template | 100% (language-agnostic) |
| Container Scan | Stage Template | 100% (image-agnostic) |
| Build Steps | Step Template | Por lenguaje |
| Evaluate Gates | Inline en Stage | 100% (en stage template) |
| Policy Enforcement | OPA Policy | 100% (forzado) |

### OPA Policies Requeridas

Las siguientes policies deben estar configuradas:

```rego
# require-security-scans.rego
- Pipeline debe tener SecurityTests stage
- Docker builds requieren container scan
- Gitleaks es obligatorio
- Security stages necesitan policySetRef
- ManualIntervention en security gates
- Solo templates aprobados
```

### Usar Templates en Pipelines

```yaml
# Referencia a Stage Template
- stage:
    name: Security Scan - Code
    template:
      templateRef: security_scan_code
      versionLabel: "1.0.0"
      templateInputs:
        spec:
          execution:
            steps:
              - stepGroup:
                  identifier: SCA
                  strategy:
                    repeat:
                      items: <+pipeline.variables.SERVICES.split(",")>

# Referencia a Step Template
- step:
    name: Build Go
    template:
      templateRef: build_go
      versionLabel: "1.0.0"
```
