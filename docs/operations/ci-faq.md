# CI/CD Pipeline FAQ

Preguntas frecuentes sobre la arquitectura y operación del pipeline CI/CD para el monorepo Cinema Microservices.

---

## Tabla de Contenidos

1. [Arquitectura del Pipeline](#arquitectura-del-pipeline)
2. [Security Scanning](#security-scanning)
3. [Monorepo y Looping](#monorepo-y-looping)
4. [Container Builds](#container-builds)
5. [Gobernanza y Policies](#gobernanza-y-policies)
6. [Multi-Lenguaje y Templates](#multi-lenguaje-y-templates)
7. [Operaciones y Troubleshooting](#operaciones-y-troubleshooting)

---

## Arquitectura del Pipeline

### Q: ¿Por qué el pipeline tiene 3 stages en lugar de 2?

**A:** La arquitectura de 3 stages sigue el patrón shift-left:

| Stage | Propósito | Cuándo Ejecuta |
|-------|-----------|----------------|
| **Security Scan - Code** | Escaneo de código (SCA, SAST, secrets) | PR Open (`RUN_MODE=validate`) |
| **Build and Test** | Compilar binarios, construir imágenes, escanear containers | PR Merge (`RUN_MODE=full`) |
| **Push Images** | Publicar imágenes al registry, crear tags | PR Merge (si pasan gates) |

Esta separación permite:
- Fail-fast en seguridad antes de invertir tiempo en builds
- Claridad en qué falló (código vs container vs push)
- Conditional execution basado en security gates

---

### Q: ¿Por qué no hacer build del container en el PR (Stage 1)?

**A:** Decisión de diseño para optimizar tiempo y recursos:

| Enfoque | Pros | Cons |
|---------|------|------|
| **Build en PR** | Detecta problemas de Dockerfile temprano | +3-5 min por PR, redundante si no se mergea |
| **Build solo en Merge** | Más rápido, sin redundancia | Problemas de Dockerfile se detectan al mergear |

**Conclusión:** El código aplicativo es lo crítico. Si el código pasa, el Dockerfile (que cambia raramente) también funcionará. Si falla en merge, el desarrollador crea un fix PR.

---

### Q: ¿Cómo evitamos redundancia si antes teníamos build 2 veces?

**A:** La versión anterior (v3.0-v3.2) tenía:

```
PR Open:  Build Binary → Build Image → Scan → (no push)
PR Merge: Build Binary → Build Image → Scan → Push  ← REDUNDANTE
```

**Solución implementada (v3.5):**

```
PR Open:  Code Security Scans only (no build)
PR Merge: Build Binary → Build Image → Scan → Push (si pasa gate)
```

**Ahorro:** ~40% reducción en tiempo total del ciclo PR→Merge.

---

### Q: ¿Qué pasa si el container tiene vulnerabilidades?

**A:** Flujo diseñado para este escenario:

1. **Container se construye** (siempre)
2. **Scanners detectan vulnerabilidades** (Trivy + HarnessContainer)
3. **Security Gate evalúa thresholds:**
   - Critical > 0 → GATE_PASS=false
   - High > 3 → GATE_PASS=false
4. **Si falla el gate:**
   - Imagen NO se publica al registry
   - PR recibe comentario con detalles de vulnerabilidades
   - `ManualIntervention` permite aprobar excepciones (4h timeout)
5. **Desarrollador crea fix PR** actualizando base image o dependencias

---

## Security Scanning

### Q: ¿Cuáles son los 7 security scanners y qué detectan?

**A:**

| Scanner | Tipo | Detecta | Stage |
|---------|------|---------|-------|
| **HarnessSAST** (config: sast) | SAST | Vulnerabilidades en código fuente | Code |
| **Snyk SAST** | SAST | Vulnerabilidades en código (segunda opinión) | Code |
| **HarnessSAST** (config: sca) | SCA | Vulnerabilidades en dependencias | Code |
| **Snyk SCA** | SCA | Vulnerabilidades en dependencias + SBOM | Code |
| **Semgrep** | SAST | Patrones inseguros, best practices | Code |
| **Gitleaks** | Secrets | Credenciales hardcodeadas, API keys | Code |
| **AquaTrivy** | Container | CVEs en imagen base y packages | Container |
| **HarnessContainer** | Container | CVEs en imagen (segunda opinión) | Container |

---

### Q: ¿Por qué usar HarnessSAST con config:sca en lugar de HarnessSCA?

**A:** Basado en el pipeline de referencia `pipeline-shift-left.yaml`:

```yaml
# CORRECTO (shift-left pattern)
- step:
    type: HarnessSAST
    spec:
      config: sca  # ← Configura HarnessSAST para modo SCA

# INCORRECTO (versión anterior)
- step:
    type: HarnessSCA  # ← Step type diferente
```

El patrón `HarnessSAST` con `config: sca|sast` es más flexible y consistente con la arquitectura de Harness STO.

---

### Q: ¿Qué Policy Sets necesito configurar en Harness?

**A:** Las siguientes policies deben existir:

| Policy Set | Aplicado a | Propósito |
|------------|------------|-----------|
| `STO_Policy` | Scanners individuales (HarnessSAST, Snyk) | Baseline de severidades aceptables |
| `security_secrets` | Gitleaks | Zero-tolerance para secrets |
| `security_gate_code` | Evaluate Code Security step + Stage | Gate consolidado de código |
| `security_gate_container` | Evaluate Container Security step + Stage | Gate consolidado de container |
| `security_container` | Trivy | Baseline para container scans |

---

### Q: ¿Por qué ManualIntervention en los security gates?

**A:** Permite flexibilidad controlada:

```yaml
failureStrategies:
  - onFailure:
      errors:
        - AllErrors
      action:
        type: ManualIntervention
        spec:
          timeout: 4h
          onTimeout:
            action:
              type: Abort
```

**Beneficios:**
- Si hay violación crítica, un approver puede evaluar si es aceptable
- Documentación automática de quién aprobó la excepción
- Timeout de 4h evita pipelines colgados indefinidamente
- Audit trail completo para compliance

---

## Monorepo y Looping

### Q: ¿Cómo funciona la estrategia de looping para monorepo?

**A:** Cada StepGroup itera sobre la lista de servicios:

```yaml
stepGroup:
  name: Build Services
  identifier: build_services
  steps:
    - step: ...
  strategy:
    repeat:
      items: <+pipeline.variables.SERVICES.split(",")>
      nodeName: <+repeat.item>
      maxConcurrency: 3
```

**Variables:**
- `SERVICES`: Input del pipeline (ej: `"booking,movie,showtime"`)
- `<+repeat.item>`: Nombre del servicio actual en la iteración
- `maxConcurrency`: Cuántos servicios procesar en paralelo

---

### Q: ¿Qué valores de maxConcurrency usar?

**A:** Depende del tipo de operación:

| StepGroup | maxConcurrency | Razón |
|-----------|----------------|-------|
| Code Quality (lint) | 4 | Operaciones CPU-light |
| SCA Scans | 3 | I/O moderado |
| SAST Scans | 3 | CPU-intensive pero paralelizable |
| Tests | 3 | Balance CPU/memoria |
| Build + Container Scan | 2 | I/O heavy, Docker daemon compartido |
| Push Images | 2 | Network-bound |

---

### Q: ¿Cómo accedo a outputs de steps dentro de loops?

**A:** Harness genera outputs por iteración:

```yaml
# Dentro del mismo loop (mismo StepGroup)
<+execution.steps.semantic_version.output.outputVariables.VERSION>

# Desde fuera del loop (después del StepGroup)
# LIMITACIÓN: Solo obtienes el valor de la última iteración
<+execution.steps.build_scan.output.outputVariables.VERSION>

# Para acceder a outputs de iteraciones específicas, usa archivos o matriz
```

**Workaround para múltiples outputs:** El step `Release Summary` itera sobre `SERVICES` y consulta logs del pipeline para reconstruir el estado.

---

## Container Builds

### Q: ¿Por qué usar docker build + docker save en lugar de BuildAndPushDockerRegistry?

**A:** Para separar build de push y permitir scan intermedio:

```yaml
# PASO 1: Build (sin push)
- step:
    type: Run
    spec:
      command: |
        docker build -t image:tag .
        docker save image:tag -o /harness/image.tar

# PASO 2: Scan (sobre imagen local)
- step:
    type: AquaTrivy
    spec:
      image:
        type: local_image
        name: image
        tag: tag

# PASO 3: Push (condicional)
- step:
    type: BuildAndPushDockerRegistry
    when:
      condition: <+execution.steps.security_gate.output.outputVariables.GATE_PASS> == "true"
```

---

### Q: ¿Por qué no usar el plugin Kaniko?

**A:** Decisión basada en consistencia con el patrón shift-left:

| Aspecto | Kaniko Plugin | docker build + BuildAndPush |
|---------|---------------|----------------------------|
| **Complejidad** | Más parámetros (`tar_path`, `no_push`) | Patrones nativos de Harness |
| **Debugging** | Logs específicos de Kaniko | Logs estándar de Docker |
| **Flexibilidad** | Menos opciones | Más control granular |
| **Consistencia** | Diferente al resto del pipeline | Mismo patrón que shift-left |

---

### Q: ¿Cómo funciona el conditional push?

**A:** Dos enfoques equivalentes:

```yaml
# OPCIÓN 1: when condition (usado en v3.5)
- step:
    type: BuildAndPushDockerRegistry
    when:
      stageStatus: Success
      condition: <+execution.steps.security_gate.output.outputVariables.GATE_PASS> == "true"

# OPCIÓN 2: Stage separado con condition
- stage:
    name: Push Images
    when:
      condition: <+pipeline.stages.build_and_test.spec.execution.steps.evaluate_container_security.output.outputVariables.CONTAINER_GATE_PASSED> == "true"
```

---

## Gobernanza y Policies

### Q: ¿Cómo forzar que todos los pipelines tengan security scans?

**A:** Usar OPA Policies en Harness:

```rego
# require-security-scans.rego

# Deny pipelines without security scan stage
deny[msg] {
    not has_security_stage
    msg := "Pipeline must include at least one SecurityTests stage"
}

has_security_stage {
    input.pipeline.stages[_].stage.type == "SecurityTests"
}

# Deny Docker builds without container scan
deny[msg] {
    has_docker_build
    not has_container_scan
    msg := "Docker builds require container security scanning"
}
```

**Aplicación:**
1. Crear Policy Set en Harness
2. Asociar a Organization o Project
3. El pipeline falla si viola la policy

---

### Q: ¿Cuáles son las policies recomendadas?

**A:** Policies implementadas en `require-security-scans.rego`:

| Policy | Nivel | Acción |
|--------|-------|--------|
| Require SecurityTests stage | deny | Bloquea pipeline |
| Require container scan for Docker builds | deny | Bloquea pipeline |
| Require Gitleaks | deny | Bloquea pipeline |
| Require policySetRef on security stages | deny | Bloquea pipeline |
| Require approved templates only | deny | Bloquea pipeline |
| Require ManualIntervention on gates | warn | Warning (no bloquea) |

---

## Multi-Lenguaje y Templates

### Q: ¿Cómo manejar múltiples lenguajes (Go, Java, Node, Python)?

**A:** Estrategia de templates en 3 niveles:

```
┌─────────────────────────────────────────────────────────┐
│                    TEMPLATE LIBRARY                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  STAGE TEMPLATES (100% compartidos)                    │
│  ├── security-scan-code.yaml  → Cualquier lenguaje     │
│  └── container-scan.yaml      → Cualquier imagen       │
│                                                         │
│  STEP TEMPLATES (Por lenguaje)                         │
│  ├── build-go.yaml     → go build, go test             │
│  ├── build-java.yaml   → maven/gradle                  │
│  ├── build-node.yaml   → npm/yarn/pnpm                 │
│  └── build-python.yaml → pip/poetry                    │
│                                                         │
│  PIPELINES (Compuestos de templates)                   │
│  ├── CI-Go.yaml        → Stage(security) + Step(go)   │
│  ├── CI-Java.yaml      → Stage(security) + Step(java) │
│  └── ...                                               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Reutilización:** ~75% del código es compartido entre lenguajes.

---

### Q: ¿Por qué no usar un single pipeline para todos los lenguajes?

**A:** Comparación de estrategias:

| Estrategia | Pros | Cons | Gobernanza |
|------------|------|------|------------|
| **Single Pipeline** | Un archivo | Complejidad extrema, condicionales por todos lados | Difícil |
| **Pipeline per Stack** | Claridad, ownership por equipo | Duplicación masiva (~70% repetido) | Inconsistente |
| **Templates + OPA** | DRY, gobernanza centralizada, flexibilidad | Curva de aprendizaje inicial | Excelente |

**Recomendación:** Templates + OPA Policies.

---

### Q: ¿Cómo referenciar un template en un pipeline?

**A:**

```yaml
# Stage Template
- stage:
    name: Security Scan - Code
    template:
      templateRef: security_scan_code
      versionLabel: "1.0.0"
      templateInputs:
        spec:
          caching:
            key: go-mod-<+hashFiles("**/go.sum")>

# Step Template
- step:
    name: Build Go
    template:
      templateRef: build_go
      versionLabel: "1.0.0"
      templateInputs:
        spec:
          image: golang:1.24
```

---

## Operaciones y Troubleshooting

### Q: ¿Cómo diagnosticar un pipeline fallido?

**A:** Usar herramientas MCP de Harness:

```bash
# 1. Ver estado general
harness_status(org_id="sandbox", project_id="CristianRamirez")

# 2. Diagnosticar fallo específico
harness_diagnose(execution_id="<execution_id>")

# 3. Ver logs de ejecución
harness_list(resource_type="execution_log", filters={"executionId": "<id>"})

# 4. Re-ejecutar
harness_execute(resource_type="pipeline", action="run", inputs={"branch": "main"})
```

---

### Q: ¿Qué hacer si el pre-flight check falla?

**A:** El pre-flight valida antes de operaciones costosas:

| Error | Causa | Solución |
|-------|-------|----------|
| `Service directory not found` | Servicio en SERVICES no existe | Verificar variable SERVICES |
| `go.mod not found` | Estructura de servicio incorrecta | Agregar go.mod al servicio |
| `main.go not found` | Entry point faltante | Crear `cmd/<service>/main.go` |
| `Dockerfile not found` | Dockerfile movido/eliminado | Verificar `platform/docker/go-service/Dockerfile` |

---

### Q: ¿Cómo reducir tiempos de pipeline?

**A:** Optimizaciones implementadas:

| Optimización | Impacto | Cómo |
|--------------|---------|------|
| Cache Intelligence | -30% en builds | `caching.enabled: true` + key por go.sum |
| Parallel execution | -40% en stages | `maxConcurrency: 2-4` en loops |
| Pre-flight checks | Fail-fast | Validar antes de loops costosos |
| No container en PR | -5 min por PR | Solo code scans en validate mode |
| Build Intelligence | Variable | `buildIntelligence.enabled: true` |

---

### Q: ¿Cuáles son los tiempos esperados del pipeline?

**A:**

| Stage | Servicios | Tiempo Esperado | Alerta si > |
|-------|-----------|-----------------|-------------|
| Security Scan - Code | 4 | 3-5 min | 8 min |
| Build and Test | 4 | 5-8 min | 12 min |
| Push Images | 4 | 2-3 min | 5 min |
| **Total PR (validate)** | 4 | 3-5 min | 8 min |
| **Total Merge (full)** | 4 | 7-11 min | 17 min |

---

## Referencias

- [Pipeline Principal](/.harness/pipelines/CI/CI-Unified-v3.yaml)
- [Pipeline Shift-Left (referencia)](/.harness/pipelines/CI/pipeline-shift-left.yaml)
- [Templates](/.harness/templates/)
- [OPA Policies](/.harness/policies/)
- [Runbook](./ci-runbook.md)
- [CI/CD Strategy](./ci-cd-strategy.md)
- [Harness STO Documentation](https://developer.harness.io/docs/security-testing-orchestration)

---

*Última actualización: 2026-04-26*
*Pipeline version: v3.5*
