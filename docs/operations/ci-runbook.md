# CI Pipeline Runbook

Guía operacional para el pipeline CI-Unified-v3.

---

## Quick Reference

| Acción | Comando/URL |
|--------|-------------|
| Ver pipeline | `harness_get(url='<pipeline-url>')` |
| Ejecutar | `harness_execute(resource_type='pipeline', action='run')` |
| Diagnosticar fallo | `harness_diagnose(execution_id='<id>')` |
| Ver logs | `harness_list(resource_type='execution_log')` |

---

## Escenarios Comunes

### 1. PR falla en Code Quality

**Síntoma:** Step `lint` o `complexity` falla

**Diagnóstico:**
```bash
# Ver errores de lint
golangci-lint run --timeout 3m

# Ver funciones con alta complejidad (>15)
gocyclo -over 15 .
```

**Solución:**
- Corregir errores de lint en el código
- Refactorizar funciones complejas

---

### 2. Security Scanner detecta vulnerabilidad

**Síntoma:** Step de security muestra findings

**Diagnóstico:**
1. Revisar logs del step
2. Identificar CVE o rule ID
3. Verificar severidad (critical/high/medium/low)

**Solución por tipo:**

| Tipo | Acción |
|------|--------|
| SAST (código) | Corregir patrón de código inseguro |
| SCA (dependencia) | Actualizar `go.mod`: `go get -u <pkg>` |
| Gitleaks (secreto) | Rotar credencial + `.gitignore` |
| Container (imagen) | Actualizar base image en Dockerfile |

---

### 3. Coverage bajo umbral (80%)

**Síntoma:** Step `unit_tests` falla con coverage < 80%

**Diagnóstico:**
```bash
cd services/<service>
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out  # Ver áreas sin cobertura
```

**Solución:**
- Agregar tests para código no cubierto
- Priorizar: handlers, business logic, error paths

---

### 4. Container bloqueado (no se publica)

**Síntoma:** Pipeline termina exitoso pero imagen no se publicó

**Diagnóstico:**
1. Revisar step `security_gate` - outputs `GATE_PASS`
2. Verificar `VULN_CRITICAL` y `VULN_HIGH`
3. Comparar contra umbrales: `SECURITY_GATE_CRITICAL=0`, `SECURITY_GATE_HIGH=5`

**Solución:**
1. Identificar vulnerabilidades en scan logs
2. Crear PR con fix (actualizar base image o deps)
3. Re-ejecutar pipeline

---

### 5. Build Container falla

**Síntoma:** Step `build_container` falla

**Diagnóstico:**
1. Verificar Dockerfile existe: `platform/docker/go-service/Dockerfile`
2. Verificar binary existe: `services/<svc>/<svc>`
3. Revisar logs de Kaniko

**Causas comunes:**
- Binary no compiló (step anterior falló silenciosamente)
- Dockerfile target incorrecto
- Context path incorrecto

**Solución:**
```bash
# Verificar build local
cd services/<service>
CGO_ENABLED=0 go build -o <service> ./cmd/<service>

# Verificar Dockerfile
docker build -f platform/docker/go-service/Dockerfile \
  --target runtime-prebuilt \
  --build-arg SERVICE_NAME=<service> .
```

---

### 6. Pre-flight Check falla

**Síntoma:** Pipeline falla en primer step

**Diagnóstico:**
- Servicio no existe en `services/`
- Falta `go.mod` en servicio
- Falta `cmd/<svc>/main.go`

**Solución:**
1. Verificar estructura del servicio
2. Corregir variable `SERVICES` si contiene servicio inválido

---

### 7. GitHub API falla (status/comment)

**Síntoma:** Steps de GitHub fallan con 401/403/404

**Diagnóstico:**
1. Verificar secret `CristianGithub` está configurado
2. Verificar token tiene permisos: `repo`, `write:discussion`
3. Verificar repo name es correcto

**Solución:**
- Regenerar token en GitHub
- Actualizar secret en Harness

---

## Monitoreo

### Métricas a observar

| Métrica | Normal | Alerta |
|---------|--------|--------|
| Duración Stage 1 | 3-5 min | >8 min |
| Duración Stage 2 | 5-8 min | >12 min |
| Cache hit rate | >80% | <50% |
| Security gate pass rate | >90% | <70% |

### Logs importantes

```bash
# Ver ejecuciones recientes
harness_list(resource_type='execution', filters={'pipelineIdentifier': 'CI_Unified_v3'})

# Diagnosticar fallo específico
harness_diagnose(execution_id='<execution_id>')
```

---

## Mantenimiento

### Semanal

- [ ] Revisar vulnerabilidades nuevas en imágenes base
- [ ] Verificar actualizaciones de scanners
- [ ] Limpiar cache si >5GB

### Mensual

- [ ] Actualizar versiones de Go/Alpine
- [ ] Revisar umbrales de security gate
- [ ] Analizar métricas de duración

### Trimestral

- [ ] Evaluar nuevos scanners
- [ ] Revisar coverage thresholds
- [ ] Actualizar documentación

---

## Contactos

| Rol | Responsabilidad |
|-----|-----------------|
| DevOps | Pipeline config, infrastructure |
| Security | Scanner rules, gate thresholds |
| Dev Lead | Coverage policy, lint rules |
