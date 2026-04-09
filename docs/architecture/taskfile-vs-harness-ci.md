# Comparación: Taskfile vs Harness CI Pipeline

Este documento describe la paridad de funcionalidades entre el Taskfile local y el pipeline de Harness CI, incluyendo la justificación de por qué cada tarea pertenece a uno, otro, o ambos.

## Principios de Diseño

| Contexto | Propósito | Características |
|----------|-----------|-----------------|
| **Taskfile** | Desarrollo local, iteración rápida | Sin dependencias externas, feedback inmediato, reproducible en laptop |
| **Harness CI** | Validación oficial, gate de calidad | Autoritativo, auditable, bloquea merge, genera artefactos oficiales |

### Regla General

- **Solo Taskfile**: Tareas de desarrollo local que no tienen sentido en CI (ambiente dev, shells, seeds)
- **Solo Harness**: Tareas que requieren infraestructura CI, secretos, o son gates oficiales de release
- **Ambos**: Validaciones que el desarrollador debe correr localmente Y que CI debe verificar como gate

---

## Matriz de Comparación

### Code Quality

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| Complexity Analysis (gocyclo) | ❌ | ✅ | **Agregar a Taskfile**: El desarrollador debe detectar funciones complejas antes de hacer push. Evita ciclos de PR rechazado. |
| Code Duplication (dupl) | ❌ | ✅ | **Agregar a Taskfile**: Warning local ayuda a refactorizar temprano. En CI es solo informativo (no bloquea). |
| Lint (golangci-lint) | ✅ | ❌ | **Agregar a Harness**: Gate crítico. Si pasa local pero no CI, indica inconsistencia de configuración. Debe estar en ambos. |

### Security

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| SAST Scan | ❌ | ✅ | **Solo Harness**: HarnessSAST es un producto integrado con dashboards, tracking de vulnerabilidades, y políticas organizacionales. Localmente se puede usar `gosec` como aproximación, pero el gate oficial es Harness. |
| SCA Scan (dependencias) | ❌ | ✅ | **Solo Harness**: HarnessSCA tiene base de datos de CVEs actualizada y políticas centralizadas. Localmente `govulncheck` es útil pero no reemplaza el gate oficial. |
| Container SCA | ❌ | ✅ | **Solo Harness**: Requiere imagen construida y pusheada. El escaneo de contenedor solo tiene sentido post-build en CI. |
| Secrets Detection | ❌ | ❌ | **Agregar a ambos**: Taskfile con `gitleaks` pre-commit, Harness como gate. Crítico detectar antes de push. |

### Testing

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| Unit Tests | ✅ | ✅ | **Ambos**: Desarrollador corre tests constantemente. CI es gate oficial con reportes JUnit. |
| Coverage Check | ✅ | ✅ | **Ambos**: Threshold debe ser idéntico (80%). Local da feedback inmediato, CI bloquea si no cumple. |
| Contract Tests | ✅ | ✅ | **Ambos**: Pact tests deben correr local para iterar. CI verifica contratos antes de merge. |
| Benchmark Tests | ❌ | ✅ | **Agregar a Taskfile**: Detectar regresiones de performance localmente. CI registra baseline oficial. |
| E2E Tests | ✅ | ❌ | **Agregar a Harness**: E2E es validación crítica pre-merge. Requiere ambiente completo que CI puede provisionar consistentemente. |
| JUnit Reports | ❌ | ✅ | **Solo Harness**: Reportes XML son para dashboards CI, históricos, y Test Intelligence. Localmente el output de terminal es suficiente. |

### API Validation

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| OpenAPI Snapshot | ✅ | ❌ | **Solo Taskfile**: Snapshots son para desarrollo - detectar cambios breaking durante coding. CI asume spec ya actualizado. |
| Spectral OpenAPI Lint | ❌ | ✅ | **Agregar a Taskfile**: Validar spec contra estándares debe ser local primero. CI es gate final. |

### Build & Release

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| Docker Build | ✅ | ✅ | **Ambos**: Local para desarrollo/debug. CI para artefactos oficiales. |
| Docker Push | ❌ | ✅ | **Solo Harness**: Push a registry oficial requiere credenciales CI y debe ser auditable. Local solo construye. |
| Semantic Versioning | ❌ | ✅ | **Solo Harness**: Versión oficial se calcula en CI basado en conventional commits del PR. Local no debe generar versiones. |
| Git Tag Creation | ❌ | ✅ | **Solo Harness**: Tags son eventos de release oficial. Deben crearse solo post-merge por CI. |
| PR Status Comment | ❌ | ✅ | **Solo Harness**: Comunicación automatizada en PR es función de CI. |

### Dev Environment

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| Dev Up/Down | ✅ | ❌ | **Solo Taskfile**: Ambiente de desarrollo es puramente local. CI usa ambientes efímeros propios. |
| Mongo/Redis CLI | ✅ | ❌ | **Solo Taskfile**: Utilidades de debugging local. No aplica en CI. |
| Seed Data | ✅ | ❌ | **Solo Taskfile**: Datos de prueba para desarrollo. CI usa fixtures específicos por test. |
| Container Shell | ✅ | ❌ | **Solo Taskfile**: Debugging interactivo es local. CI no tiene sesiones interactivas. |

### Performance Testing

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| k6 Baseline | ✅ | ❌ | **Considerar Harness**: Performance baseline debería correr en CI para ambiente consistente. Local es útil para desarrollo. |
| k6 Stress | ✅ | ❌ | **Solo Taskfile**: Stress testing es bajo demanda, no en cada PR. Puede agregarse como pipeline separado en Harness. |

### Demo & Lab

| Feature | Taskfile | Harness | Justificación |
|---------|:--------:|:-------:|---------------|
| Demo Scenarios | ✅ | ❌ | **Solo Taskfile**: Demos son interactivos y locales por naturaleza. |
| Lab Management | ✅ | ❌ | **Solo Taskfile**: Gestión de ejercicios es para workshops locales. |
| Exercise System | ✅ | ❌ | **Solo Taskfile**: Sistema educativo, no producción. |

---

## Gaps Identificados

### Agregar a Taskfile (feedback local antes de push)

| Task | Comando sugerido | Prioridad |
|------|------------------|-----------|
| `test:complexity` | `gocyclo -over 15 .` | Alta |
| `test:duplication` | `dupl -threshold 100 .` | Media |
| `test:benchmark` | `go test -bench=. -benchmem ./...` | Media |
| `lint:openapi` | `spectral lint openapi.yaml` | Alta |
| `security:secrets` | `gitleaks detect` | Alta |

### Agregar a Harness CI (gates oficiales faltantes)

| Stage/Step | Justificación | Prioridad |
|------------|---------------|-----------|
| Lint (golangci-lint) | Gate de estilo consistente | Alta |
| E2E Tests | Validación de integración pre-merge | Alta |
| Performance Baseline | Detectar regresiones en CI | Media |

---

## Diagrama de Flujo

```
┌─────────────────────────────────────────────────────────────────┐
│                        DEVELOPER LAPTOP                         │
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ task test   │───▶│ task lint   │───▶│ task build  │         │
│  │ (unit+cov)  │    │ (quality)   │    │ (docker)    │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                                    │
│         ▼                  ▼                                    │
│  ┌─────────────┐    ┌─────────────┐                            │
│  │ task test:  │    │ task test:  │     ◀── Feedback rápido    │
│  │ complexity  │    │ openapi     │         antes de push      │
│  └─────────────┘    └─────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ git push
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         HARNESS CI                              │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              STAGE: Validate and Secure                   │  │
│  │                    (PR abierto)                           │  │
│  │                                                           │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐            │  │
│  │  │ Complexity │ │   SAST     │ │ Unit Tests │            │  │
│  │  │   + Dupl   │ │   + SCA    │ │ + Coverage │            │  │
│  │  └────────────┘ └────────────┘ └────────────┘            │  │
│  │         │              │              │                   │  │
│  │         └──────────────┴──────────────┘                   │  │
│  │                        │                                  │  │
│  │                        ▼                                  │  │
│  │              ┌─────────────────┐                          │  │
│  │              │  PR Comment:    │                          │  │
│  │              │  "Ready to      │                          │  │
│  │              │   merge"        │                          │  │
│  │              └─────────────────┘                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│                              │ PR merged                        │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              STAGE: Build and Release                     │  │
│  │                   (PR merged)                             │  │
│  │                                                           │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐            │  │
│  │  │  Semantic  │ │  Docker    │ │ Container  │            │  │
│  │  │  Version   │ │  Build+Push│ │    SCA     │            │  │
│  │  └────────────┘ └────────────┘ └────────────┘            │  │
│  │                        │                                  │  │
│  │                        ▼                                  │  │
│  │              ┌─────────────────┐                          │  │
│  │              │   Git Tag +     │                          │  │
│  │              │   Release       │                          │  │
│  │              └─────────────────┘                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Configuración de Thresholds

Para mantener consistencia entre Taskfile y Harness CI:

| Parámetro | Valor | Archivo Taskfile | Variable Harness |
|-----------|-------|------------------|------------------|
| Coverage mínimo | 80% | `THRESHOLD` en `test:coverage` | `COVERAGE_THRESHOLD` |
| Complejidad máxima | 15 | (por agregar) | `MAX_COMPLEXITY` |
| Tokens duplicación | 100 | (por agregar) | `MIN_TOKENS` |
| Go version | 1.22 | (inferido de go.mod) | `GO_VERSION` |

---

## Referencias

- [Taskfile.yml](/Taskfile.yml)
- [CI-Golang-v2.yaml](/.harness/pipelines/CI/CI-Golang-v2.yaml)
- [Harness CI Documentation](https://developer.harness.io/docs/continuous-integration)
