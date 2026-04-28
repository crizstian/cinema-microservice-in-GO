# Harness MCP Demo - 15 Minutos

**Premisa:** Control total de CI/CD desde VS Code con lenguaje natural.

**Proyecto:** `sandbox/CristianRamirez`  
**Pipelines:** `CI_Orchestrator` → `CICD_Go_GitOps`

---

## Flujo del Demo

```
PR Open  → Validate (lint, security, tests)
PR Merge → Build → Scan → Deploy
```

---

## ACT 1: Código → PR → Validación (5 min)

### 1.1 Cambio de código
```
Agrega un comentario "// Demo MCP" al inicio de main.go en booking y movie
```

**Resultado:**
```
✅ services/booking/cmd/booking/main.go: comentario agregado
✅ services/movie/cmd/movie/main.go: comentario agregado
```

### 1.2 Commit y PR
```
Haz commit, push a feature/demo, y crea un PR hacia monorepo
```

**Resultado:**
```
✅ PR creado: https://github.com/crizstian/cinema.../pull/XX
```

### 1.3 Verificar pipeline
```
¿Se disparó el pipeline CI_Orchestrator?
```

**Resultado:**
```
✅ CI_Orchestrator triggered (PR Open - validate mode)
   └── CICD_Go_GitOps: Lint ✅ Security ✅ Tests ✅
   └── Build: SKIPPED (validate mode)
```

### 1.4 Merge del PR
```
El pipeline pasó. Haz merge del PR
```

**Resultado:**
```
✅ PR merged (squash)
```

---

## ACT 2: Build & Deploy (4 min)

### 2.1 Pipeline post-merge
```
¿Se disparó el pipeline después del merge?
```

**Resultado:**
```
✅ CI_Orchestrator triggered (PR Merge - full mode)
   └── CICD_Go_GitOps: Running...
```

### 2.2 Monitorear build
```
Dame el diagnóstico del pipeline CICD_Go_GitOps
```

**Resultado:**
```
Pipeline: CICD_Go_GitOps (full mode)
├── Validate: ✅ Lint, Security, Tests
└── Build & Release: 🔄 Running
    ├── Build: ✅ booking, movie
    ├── Container Scan: ✅ 0 Critical
    ├── Update GitOps: ✅ Manifests committed
    └── Sync Apps: ✅ booking-dev, movie-dev synced
```

---

## ACT 3: Verificar Despliegues (3 min)

### 3.1 Estado de GitOps
```
Lista las aplicaciones de GitOps. ¿Ya se desplegaron?
```

**Resultado:**
```
| App                      | Status | Health  |
|--------------------------|--------|---------|
| bookingservicegitops-dev | Synced | Healthy |
| movieservicegitops-dev   | Synced | Healthy |
```

### 3.2 Verificar pods
```
Muéstrame los pods de booking en dev
```

**Resultado:**
```
✅ booking-service-xxx: Running
✅ booking-service-yyy: Running
   Replicas: 2/2 Ready
```

---

## ACT 4: Troubleshooting (2 min)

### 4.1 Diagnosticar problema
```
cinemaservicegitops-dev está Degraded. ¿Cuál es el problema?
```

**Resultado:**
```
Pod: CrashLoopBackOff
Logs: panic: environment variable MONGO_URI not set
Root Cause: Falta MONGO_URI en ConfigMap
```

### 4.2 Fix y redeploy
```
Agrega MONGO_URI al configmap y sincroniza
```

**Resultado:**
```
✅ ConfigMap updated
✅ Changes pushed
✅ Sync completed: Healthy
```

---

## Closing

> "En 15 minutos, sin abrir Harness UI:
> - PR Open → Validación automática
> - PR Merge → Build + Deploy automático  
> - Verificación de GitOps
> - Troubleshooting completo
>
> Todo con lenguaje natural."

---

## Script de Prompts

```
Agrega un comentario "// Demo MCP" al inicio de main.go en booking y movie
Haz commit, push a feature/demo, y crea un PR hacia monorepo
¿Se disparó el pipeline CI_Orchestrator?
El pipeline pasó. Haz merge del PR
¿Se disparó el pipeline después del merge?
Dame el diagnóstico del pipeline CICD_Go_GitOps
Lista las aplicaciones de GitOps. ¿Ya se desplegaron?
Muéstrame los pods de booking en dev
cinemaservicegitops-dev está Degraded. ¿Cuál es el problema?
Agrega MONGO_URI al configmap y sincroniza
```

---

## Checkpoints

| Tiempo | Sección |
|--------|---------|
| 0:00 | Intro |
| 0:30 | ACT 1 - PR + Validación |
| 5:30 | ACT 2 - Build & Deploy |
| 9:30 | ACT 3 - GitOps |
| 12:30 | ACT 4 - Troubleshooting |
| 14:30 | Closing |
