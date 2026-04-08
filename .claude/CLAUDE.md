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
