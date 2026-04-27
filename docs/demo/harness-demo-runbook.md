# Harness MCP Demo Runbook

Demo de 25-30 minutos mostrando el flujo completo del developer con Harness MCP.

## Flujo del Demo

```
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                          │
│   ┌──────────┐         ┌──────────┐         ┌──────────┐               │
│   │    CI    │────────▶│  GitOps  │────────▶│   IDP    │               │
│   │  Build   │         │  Deploy  │         │ Catalog  │               │
│   └────┬─────┘         └────┬─────┘         └──────────┘               │
│        │                    │                                           │
│        │ error?             │ error?                                    │
│        ▼                    ▼                                           │
│   ┌─────────────────────────────────────┐                              │
│   │         TROUBLESHOOTING             │                              │
│   │   • Diagnóstico automático          │                              │
│   │   • Root cause analysis             │                              │
│   │   • Sugerencias de fix              │                              │
│   │   • Retry desde el IDE              │                              │
│   └─────────────────────────────────────┘                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

| Paso | Tiempo | Descripción |
|------|--------|-------------|
| **1. CI** | 10 min | Cambio de código → Pipeline → (Si falla: Troubleshoot → Fix → Retry) |
| **2. GitOps** | 8 min | Promoción a staging → Sync → (Si falla: Troubleshoot → Fix → Retry) |
| **3. IDP** | 5 min | Catálogo, dependencias, scorecards |

---

## Concepto Central: "Zero Context Switch"

```
┌─────────────────────────────────────────────────────────────────┐
│                         IDE (VS Code)                            │
│                                                                  │
│  Developer ──▶ Claude Code ──▶ Harness MCP ──▶ Resultados       │
│                                                                  │
│  "Ejecuta CI"        "Diagnostica"        "Promueve a staging"  │
│  "¿Qué falló?"       "Muéstrame deps"     "Sync ArgoCD"         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Pre-Demo Setup (5 min antes)

```bash
cd /workspace
git checkout main && git pull origin main
./platform/scripts/demo/reset-demo.sh quick
```

Verificar en Claude Code:
```
> Verifica el estado del delegate de Harness
```

---

## Paso 1: CI (10 min)

**Narrativa:** "El developer hace un cambio, ejecuta CI, encuentra un problema de seguridad, lo corrige, y vuelve a ejecutar."

### 1.1 El Cambio de Código

Abrir `services/movie/internal/api/movies.go` y agregar paginación:

```go
// ANTES: Devuelve todas las películas (problema de performance)
func (a API) GetAllMovies(c echo.Context) error {
    cursor, err := a.db.Collection("movies").Find(ctx, bson.M{})
    // ...
}

// DESPUÉS: Con paginación
func (a API) GetAllMovies(c echo.Context) error {
    page, _ := strconv.Atoi(c.QueryParam("page"))
    if page < 1 { page = 1 }
    limit, _ := strconv.Atoi(c.QueryParam("limit"))
    if limit < 1 || limit > 100 { limit = 20 }
    
    opts := options.Find().SetSkip(int64((page-1)*limit)).SetLimit(int64(limit))
    cursor, err := a.db.Collection("movies").Find(ctx, bson.M{}, opts)
    // ...
}
```

**Talking Point:**
> "Agregamos paginación para evitar cargar miles de registros. Ahora ejecutamos el pipeline desde el IDE."

### 1.2 Ejecutar Pipeline

**Prompt:**
```
> Ejecuta el pipeline CI para el servicio movie
```

**Claude Code:**
- Usa `harness_execute(pipeline="CICD_Go_ShiftLeft", inputs={SERVICES: "movie"})`
- Muestra progreso en tiempo real
- Reporta: lint ✓, tests ✓, security scans...

### 1.3 Security Finding (Troubleshooting)

**El pipeline falla en security scans.** Para el demo, pre-introducir esta vulnerabilidad en `services/booking/internal/api/booking.go`:

```go
// VULNERABLE: NoSQL injection
query := bson.M{"$where": "this.order_id == '" + id + "'"}
```

**Prompt:**
```
> El pipeline falló. ¿Qué pasó?
```

**Claude Code diagnostica:**
```
Pipeline: CICD_Go_ShiftLeft - FAILED
Stage: Security Code
Scanner: Harness SAST

VULNERABILIDAD DETECTADA:
├── Tipo: NoSQL Injection (CWE-943)
├── Severidad: CRITICAL
├── Archivo: services/booking/internal/api/booking.go:152
├── Línea: query := bson.M{"$where": "this.order_id == '" + id + "'"}
└── Fix recomendado: Usar query parametrizada

Código vulnerable:
  query := bson.M{"$where": "this.order_id == '" + id + "'"}
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^
Código seguro:
  query := bson.M{"order_id": id}
```

**Talking Point:**
> "Sin abrir el browser, el developer ve exactamente qué encontró el scanner, dónde está el problema, y cómo corregirlo."

### 1.4 Fix y Retry

Corregir el código:
```go
// SECURE: Parameterized query
query := bson.M{"order_id": id}
```

**Prompt:**
```
> Volví a corregir el código. Re-ejecuta el pipeline.
```

**Claude Code:**
- Re-ejecuta el pipeline
- Esta vez pasa: lint ✓, tests ✓, security ✓, build ✓

**Talking Point:**
> "El ciclo completo - detectar, diagnosticar, corregir, verificar - sin salir del IDE."

---

## Paso 2: GitOps (8 min)

**Narrativa:** "CI pasó. Ahora promovemos a staging via GitOps. Si algo falla, diagnosticamos."

### 2.1 Ver Estado Actual

**Prompt:**
```
> Muéstrame el estado de las aplicaciones GitOps del sistema cinema
```

**Claude Code:**
```
GitOps Applications - cinema-platform:

DEV:
├── movie-service:    Synced ✓  v1.2.2
├── booking-service:  Synced ✓  v1.1.0
└── payment-service:  Synced ✓  v2.0.1

STAGING:
├── movie-service:    OutOfSync ⚠  (v1.2.2, pending v1.2.3)
└── booking-service:  Synced ✓  v1.1.0

PROD:
└── All Synced ✓
```

### 2.2 Crear PR de Promoción

**Prompt:**
```
> Crea un PR para promover movie-service v1.2.3 a staging
```

**Claude Code:**
```
PR Creado: #47
Título: "Promote movie-service v1.2.3 to staging"
Branch: promote/movie-v1.2.3-staging
URL: https://github.com/org/gitops-config/pull/47

Cambios:
  staging/movie/config.json
  - image.tag: "v1.2.2" → "v1.2.3"
```

### 2.3 Aprobar y Sincronizar

**Prompt:**
```
> Aprueba el PR y sincroniza en ArgoCD
```

**Claude Code:**
```
PR #47: Merged ✓
ArgoCD Sync: movie-service (staging)
Status: Progressing...
```

### 2.4 Deployment Failure (Troubleshooting)

**El sync falla.** (Simular con imagen inexistente o resource limits)

**Prompt:**
```
> El sync falló. ¿Cuál es el problema?
```

**Claude Code diagnostica:**
```
GitOps Sync: movie-service (staging) - FAILED

ROOT CAUSE:
├── Error: ImagePullBackOff
├── Imagen: gcr.io/cinema/movie:v1.2.3
├── Detalle: manifest unknown
└── Causa: La imagen v1.2.3 no existe en el registry

ANÁLISIS:
El pipeline CI generó tag v1.2.3 pero falló en el push.
Verificar logs del step "Push to Registry" en la última ejecución CI.

OPCIONES:
1. Re-ejecutar CI pipeline con push habilitado
2. Usar tag anterior: v1.2.2
3. Push manual de la imagen
```

**Prompt:**
```
> Re-ejecuta el pipeline CI con push completo
```

**Talking Point:**
> "El troubleshooting conecta GitOps con CI. El error de deploy se rastrea hasta el pipeline que no completó el push."

### 2.5 Sync Exitoso

Después del fix:

**Prompt:**
```
> Vuelve a sincronizar movie-service en staging
```

**Claude Code:**
```
ArgoCD Sync: movie-service (staging)
Status: Synced ✓
Health: Healthy
Pods: 3/3 Running
Version: v1.2.3
```

---

## Paso 3: IDP (5 min)

**Narrativa:** "El servicio está desplegado. Consultamos el catálogo para entender el sistema completo."

### 3.1 Consultar Catálogo

**Prompt:**
```
> Muéstrame información del servicio booking en el catálogo
```

**Claude Code:**
```
SERVICIO: booking-service
├── Owner: team-cinema
├── System: cinema-platform
├── Lifecycle: production
├── Tech Stack: Go, MongoDB, Kubernetes
│
├── APIs que provee:
│   └── booking-api (REST)
│
└── Dependencias:
    ├── seat-service (inventory)
    ├── payment-service (payments)
    ├── showtime-service (scheduling)
    └── notification-service (notifications)
```

### 3.2 Análisis de Impacto

**Prompt:**
```
> Si payment-service tiene un outage, ¿qué servicios se afectan?
```

**Claude Code:**
```
IMPACT ANALYSIS: payment-service

Servicios que dependen directamente:
└── booking-service

Flujos afectados:
└── Booking flow (no se pueden procesar pagos)

Servicios indirectamente afectados:
└── notification-service (no se envían confirmaciones)

Severidad: ALTA
Recomendación: payment-service requiere alta disponibilidad
```

**Talking Point:**
> "IDP permite entender el blast radius de un problema antes de que ocurra."

### 3.3 Scorecards

**Prompt:**
```
> ¿Cuál es el scorecard de madurez de booking-service?
```

**Claude Code:**
```
SCORECARD: booking-service

├── Security:      85%  ████████░░  (7 scanners activos)
├── CI/CD:        100%  ██████████  (pipeline completo)
├── Documentation: 70%  ███████░░░  (falta OpenAPI spec)
├── Observability: 60%  ██████░░░░  (metrics ok, no tracing)
├── Testing:       80%  ████████░░  (80% coverage)
└── OVERALL:       79%

RECOMENDACIONES:
1. Agregar distributed tracing (Jaeger/Zipkin)
2. Completar OpenAPI specification
3. Agregar runbook de operaciones
```

**Talking Point:**
> "Los scorecards miden madurez objetivamente. El equipo sabe exactamente qué mejorar."

---

## Resumen del Demo

| Paso | Acción | Troubleshooting |
|------|--------|-----------------|
| **CI** | Cambio → Pipeline | Security finding → Diagnóstico → Fix → Retry |
| **GitOps** | PR → Merge → Sync | Sync failure → Root cause → Fix → Re-sync |
| **IDP** | Catálogo → Deps → Scorecard | (información, no falla) |

---

## MCP Capabilities Usadas

| Pilar | Capabilities |
|-------|-------------|
| **CI** | `harness_execute`, `harness_status`, `harness_logs` |
| **GitOps** | `harness_gitops_status`, `harness_gitops_sync`, `harness_gitops_promote` |
| **IDP** | `harness_idp_catalog`, `harness_idp_dependencies`, `harness_idp_scorecard` |
| **Troubleshooting** | `harness_diagnose`, `harness_security_findings`, `harness_logs` |

---

## Cambios de Código para el Demo

### 1. Feature: Paginación
**Archivo:** `services/movie/internal/api/movies.go`

```diff
+ import "strconv"
+ import "go.mongodb.org/mongo-driver/mongo/options"

  func (a API) GetAllMovies(c echo.Context) error {
+     page, _ := strconv.Atoi(c.QueryParam("page"))
+     if page < 1 { page = 1 }
+     limit, _ := strconv.Atoi(c.QueryParam("limit"))
+     if limit < 1 || limit > 100 { limit = 20 }
+     
+     opts := options.Find().SetSkip(int64((page-1)*limit)).SetLimit(int64(limit))
-     cursor, err := a.db.Collection("movies").Find(ctx, bson.M{})
+     cursor, err := a.db.Collection("movies").Find(ctx, bson.M{}, opts)
```

### 2. Vulnerability (pre-introducir para demo)
**Archivo:** `services/booking/internal/api/booking.go`

```diff
  func (a API) GetOrderByID(c echo.Context) error {
      id := c.Param("orderId")
-     query := bson.M{"order_id": id}
+     query := bson.M{"$where": "this.order_id == '" + id + "'"}  // VULNERABLE
```

---

## Key Messages

| Momento | Mensaje |
|---------|---------|
| **CI execution** | "Pipeline desde el IDE, sin cambiar de contexto" |
| **Security finding** | "Detecta vulnerabilidades antes del merge, con fix sugerido" |
| **GitOps PR** | "Promociones conversacionales, Git sigue siendo la verdad" |
| **Sync failure** | "Root cause analysis automático, conecta GitOps con CI" |
| **IDP catalog** | "Entiende dependencias e impacto antes de hacer cambios" |
| **Scorecards** | "Métricas objetivas de madurez, no opiniones" |

**Mensaje Central:**
> "El developer hace todo el ciclo - código, CI, deploy, catálogo - desde el IDE. Cuando algo falla, diagnostica y corrige sin abrir el browser."

---

## Reset Post-Demo

```bash
./platform/scripts/demo/reset-demo.sh quick
```

---

## Fallback

Si hay problemas de conectividad:
- Pipeline exitoso: `fnwnPbl9Tl2NN9gQtc-4oQ`
- Usar screenshots de ejecuciones previas
- Walkthrough del YAML explicando la estructura
