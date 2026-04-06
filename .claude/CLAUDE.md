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