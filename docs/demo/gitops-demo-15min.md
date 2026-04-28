# 🎬 Harness GitOps Demo - 15 Minutes

## Demo Theme: "From Code to Production in Minutes with AI-Powered GitOps"

---

## 🎯 Pre-Demo Setup (Before audience arrives)

```bash
# Verificar que todo está corriendo
kubectl get applications -n argocd | grep -E 'dev|staging|prod'
kubectl get pods -n cinema-dev

# Tener abiertos:
# - VS Code con Claude Code MCP
# - Harness UI (GitOps tab)
# - Grafana dashboard
# - Terminal con kubectl
```

---

## 📍 Demo Flow (15 min)

### ACT 1: "The Power of AI" (3 min) 🤖
**WOW Factor: Claude Code controla toda la plataforma desde el IDE**

#### 1.1 Opening Hook (30 sec)
> "¿Qué pasaría si pudieran controlar todo su proceso de deployment con lenguaje natural?"

#### 1.2 AI-Powered Status Check (1 min)
```
En VS Code, escribir:
"muéstrame el estado de todas las aplicaciones de GitOps en el ambiente dev"
```

**WOW:** Claude ejecuta kubectl, muestra status, health, y sync state sin escribir comandos.

#### 1.3 AI Troubleshooting (1.5 min)
```
"hay algún problema con los servicios? analiza los logs de los pods que no están healthy"
```

**WOW:** Claude diagnostica automáticamente, identifica root cause, sugiere fix.

---

### ACT 2: "ApplicationSets - Deploy Once, Scale Everywhere" (2.5 min) 📦
**WOW Factor: Un solo manifest genera 24 aplicaciones**

#### 2.1 Show the Magic (1 min)
```
En VS Code:
"muéstrame cómo está configurado el ApplicationSet de cinema-services"
```

**Highlight:**
- Matrix Generator: clusters × services
- Template: genera apps dinámicamente
- Labels: Harness integration

#### 2.2 Live Demo (1.5 min)
```bash
# Mostrar en Harness UI:
# GitOps → Applications → Filter by "dev"
# Mostrar las 8 apps generadas automáticamente
```

**WOW:** "Un archivo YAML → 24 aplicaciones en 3 ambientes"

---

### ACT 3: "Bulk Operations - Control at Scale" (2 min) ⚡
**WOW Factor: Sync/Refresh de múltiples apps con un click**

#### 3.1 Bulk Filter (30 sec)
```
En Harness UI:
GitOps → Applications → Filter:
- Environment: dev
- Health: Progressing OR Degraded
```

#### 3.2 Bulk Sync (1 min)
```
Seleccionar todas las apps filtradas → Sync All
```

**WOW:** "8 servicios sincronizados en 3 segundos"

#### 3.3 AI Alternative (30 sec)
```
En VS Code:
"sincroniza todas las aplicaciones de staging"
```

**WOW:** Claude ejecuta sync masivo con un comando natural.

---

### ACT 4: "OPA Policies - Governance as Code" (2.5 min) 🛡️
**WOW Factor: Bloqueo automático de deployments fuera de horario**

#### 4.1 Show Policy (1 min)
```
En VS Code:
"muéstrame la política de deployment freeze que tenemos configurada"
```

**Highlight:**
- Horarios por timezone (Mexico Central Time)
- Diferentes ventanas por ambiente (dev 24/7, prod solo Tue-Thu)
- Bypass para emergencias

#### 4.2 Policy in Action (1.5 min)
```
En Harness UI:
Governance → Policy Sets → Show "GitOps Deployment Windows"

# Intentar sync de prod fuera de horario
# Mostrar el mensaje de bloqueo
```

**WOW:** "La política rechazó el deployment porque es [día/hora]. Solo permitido Tue-Thu 10AM-4PM Mexico."

---

### ACT 5: "Secrets Management" (1.5 min) 🔐
**WOW Factor: Secrets nunca tocan el repositorio**

#### 5.1 Architecture Overview (30 sec)
```
Diagrama rápido:
Harness Secrets Manager → External Secrets Operator → K8s Secrets → Pods
```

#### 5.2 Live Demo (1 min)
```
En VS Code:
"muéstrame cómo están configurados los secrets del servicio de payment"

En Harness UI:
Project Settings → Secrets → Show masked values
```

**WOW:** "Los secrets están en Harness, sincronizados al cluster, pero nunca en Git"

---

### ACT 6: "Progressive Delivery with Rollouts" (2 min) 🚀
**WOW Factor: Canary deployment con rollback automático**

#### 6.1 Show Rollout Config (30 sec)
```
En VS Code:
"muéstrame la configuración de rollout del cinema service"
```

#### 6.2 Trigger Rollout (1 min)
```
# Hacer un cambio pequeño (ej: variable de entorno)
"actualiza la variable LOG_LEVEL a debug en el servicio cinema en dev"

# En Harness UI: ver el progreso del canary
# Steps: 20% → 40% → 60% → 80% → 100%
```

#### 6.3 Metrics Integration (30 sec)
```
Mostrar en Grafana:
- Request success rate
- Latency P99
- Error rate
```

**WOW:** "Si los métricas degradan, Argo Rollouts hace rollback automático"

---

### ACT 7: "Full Circle - AI Orchestration" (1.5 min) 🎭
**WOW Factor: Cierre con AI controlando todo el flujo**

#### 7.1 Complex Operation via AI
```
En VS Code:
"quiero hacer un deployment de la versión v1.2.0 del servicio booking 
a producción. Primero verifica que staging está healthy, luego 
muéstrame el diff de lo que va a cambiar, y si todo está bien 
procede con el sync"
```

**WOW:** Claude:
1. Verifica health de staging ✓
2. Muestra diff de manifests
3. Pide confirmación
4. Ejecuta sync a prod
5. Monitorea el rollout

---

## 🎤 Closing Statement (30 sec)

> "En 15 minutos vimos cómo Harness GitOps combina:
> - **AI** para operaciones en lenguaje natural
> - **ApplicationSets** para escalar a múltiples ambientes
> - **Bulk Operations** para control masivo
> - **OPA Policies** para governance automático
> - **Secrets** seguros sin tocar Git
> - **Rollouts** para deployments progresivos
> 
> Todo desde una sola plataforma. ¿Preguntas?"

---

## 📊 Visual Aids

### Terminal Split Layout
```
┌─────────────────────────────────────────────────────────┐
│  VS Code + Claude Code MCP          │  Harness UI       │
│  ─────────────────────────────────  │  ─────────────    │
│  > Claude: analyzing apps...        │  [Applications]   │
│  > Found 8 apps in dev              │  ○ booking ✓      │
│  > All healthy ✓                    │  ○ cinema ✓       │
│                                     │  ○ movie ✓        │
├─────────────────────────────────────┼───────────────────┤
│  Terminal (kubectl)                 │  Grafana          │
│  ─────────────────────────────────  │  ─────────────    │
│  $ kubectl get pods -n cinema-dev   │  [Dashboard]      │
│  NAME              READY  STATUS    │  📈 Requests/sec  │
│  booking-xxx       1/1    Running   │  📉 Error rate    │
│                                     │  📊 Latency       │
└─────────────────────────────────────┴───────────────────┘
```

---

## 🚨 Backup Plans

| Si esto falla... | Hacer esto... |
|------------------|---------------|
| MCP no responde | Usar kubectl directamente, explicar que MCP "está disponible" |
| Apps no syncan | Mostrar logs, explicar troubleshooting |
| OPA no bloquea | Mostrar policy file, explicar configuración |
| Rollout no progresa | Mostrar Argo Rollouts CLI status |

---

## ⏱️ Time Checkpoints

| Tiempo | Checkpoint |
|--------|------------|
| 0:00 | Start - AI Hook |
| 3:00 | Finish AI → Start ApplicationSets |
| 5:30 | Finish AppSets → Start Bulk Ops |
| 7:30 | Finish Bulk → Start OPA |
| 10:00 | Finish OPA → Start Secrets |
| 11:30 | Finish Secrets → Start Rollouts |
| 13:30 | Finish Rollouts → Start Closing |
| 15:00 | End |

---

## 💡 Pro Tips

1. **Keep Claude visible** - El chat de MCP debe verse en todo momento
2. **Use filters aggressively** - Muestra el poder de filtrado en Harness UI
3. **Narrate the magic** - Explica qué está pasando "behind the scenes"
4. **Have a story** - "El desarrollador quiere deployar su feature..."
5. **End with AI** - Cierra con Claude haciendo algo impresionante

---

## 🎬 Demo Script Snippets

### Para copiar/pegar en Claude Code:

```
# Status check
muéstrame el estado de todas las aplicaciones de GitOps

# Troubleshooting
analiza los pods que no están healthy y dime la causa

# Bulk sync
sincroniza todas las aplicaciones del ambiente dev

# Policy check
muéstrame las políticas de OPA configuradas para GitOps

# Deployment
despliega la versión latest del servicio booking a staging
```
