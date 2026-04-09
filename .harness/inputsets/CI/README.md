# CI Pipeline InputSets

> Presets para ejecución manual del pipeline CI_Golang_v2

## Variables del Pipeline (v2.7)

| Variable | Tipo | Descripción | Valores |
|----------|------|-------------|---------|
| `RUN_MODE` | required | Qué ejecutar | `validate`, `build`, `full` |
| `SERVICES` | required | Servicios a procesar | `booking` o `booking,movie,payment` |
| `GO_VERSION` | optional | Versión de Go | Default: `1.24` |
| `COVERAGE_THRESHOLD` | optional | Threshold de coverage | Default: `80` |
| `VERSION_BUMP` | optional | Tipo de bump (build) | `patch`, `minor`, `major` |

## InputSets Disponibles

| InputSet | RUN_MODE | Descripción |
|----------|----------|-------------|
| `validate_service` | validate | Code quality, security, tests |
| `build_service` | build | Docker build, push, tags |
| `full_pipeline` | full | Ambos stages |

## Stage Execution Logic

```
RUN_MODE=validate  → Stage "Validate and Secure" runs
RUN_MODE=build     → Stage "Build and Release" runs  
RUN_MODE=full      → Both stages run
```

## Ejemplos de Uso

### Desde Harness UI

1. Pipelines → CI_Golang_v2 → Run
2. Seleccionar InputSet (ej: `Validate Service`)
3. Completar:
   - Branch: `step-1`
   - SERVICES: `booking`
4. Run Pipeline

### Desde CLI (Taskfile)

```bash
# Validar un servicio
task pipeline:run SERVICE=booking BRANCH=step-1

# Validar múltiples servicios
task pipeline:run SERVICE=booking,movie,payment

# Build con minor bump
task pipeline:run SERVICE=booking STAGE=build VERSION_BUMP=minor
```

### Desde Harness MCP

```python
harness_execute(
  resource_type="pipeline",
  resource_id="CI_Golang_v2",
  action="run",
  input_set_ids=["validate_service"],
  inputs={
    "branch": "step-1",
    "SERVICES": "booking,movie"
  }
)
```

## Compatibilidad: Manual vs Automático

El pipeline funciona igual para ambos modos:

| Modo | RUN_MODE | SERVICES | Quién lo setea |
|------|----------|----------|----------------|
| **Manual** | Usuario elige | Usuario escribe | InputSet + UI |
| **Automático** | Orquestador pasa | Orquestador detecta | CI_Orchestrator |

El orquestador (CI_Orchestrator) mapea:
- PR opened/synchronize → `RUN_MODE=validate`
- PR merged → `RUN_MODE=build`

## Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Stage skipped | RUN_MODE incorrecto | Verificar valor: validate/build/full |
| Service not found | Nombre incorrecto | Usar: booking, movie, payment, notification, user |
| No services parsed | SERVICES vacío | Escribir al menos un servicio |
