# Harness Demo Prompts - Ready to Use

> **Instrucciones**: Copia y pega estos prompts en Claude Code (VS Code) durante la demo.  
> **Pre-requisito**: Harness MCP Server configurado y conectado.

---

## DEMO BÁSICO: CI Pipeline

### Prompt B1: Crear Pipeline Simple

```
Usando el Harness MCP Server, crea un pipeline de CI para el servicio "booking" del monorepo cinema-microservices.

ESPECIFICACIONES:
- Nombre: cinema-booking-ci
- Repositorio: La rama actual del workspace
- Stages:
  1. Lint: ejecutar "go vet ./..." en services/booking
  2. Test: ejecutar tests unitarios con coverage
  3. Build: construir imagen Docker

CONFIGURACIÓN:
- Runner: Harness Cloud (Linux, amd64)
- Timeout: 20 minutos
- Failure Strategy: fail fast

Genera el YAML, muéstramelo, y si lo apruebo, créalo en Harness proyecto "CristianRamirez".
```

### Prompt B2: Ejecutar y Monitorear

```
Ejecuta el pipeline "cinema-booking-ci" que acabamos de crear.

Parámetros:
- Rama: la rama actual del repositorio
- Servicio: booking

Monitorea la ejecución en tiempo real y dame updates cada 30 segundos.
Cuando termine, muestra un resumen con:
- Duración total
- Estado de cada stage
- Logs de cualquier warning o error
```

### Prompt B3: Ver Reportes

```
Del pipeline que acaba de ejecutar, muéstrame:
1. El reporte de cobertura de tests
2. Los tests que pasaron/fallaron
3. El tiempo de cada stage

Formatea como tabla para compartir con el equipo.
```

---

## DEMO INTERMEDIO: Looping Strategy + Test Intelligence

### Prompt I1: Crear Pipeline con Matrix

```
Crea un pipeline de Harness con Looping Strategy para construir los 8 microservicios del monorepo.

SERVICIOS (con puertos):
- booking: 8082
- cinema: 8085  
- movie: 8000
- notification: 8002
- payment: 8001
- seat: 3004
- showtime: 3003
- user: 8004

REQUIREMENTS:
1. Input variable "target_services" que acepte:
   - "all" → construye todos
   - nombre de servicio → construye solo ese
   
2. Matrix strategy con maxConcurrency: 4

3. Stages por cada servicio:
   - Lint (go vet)
   - Unit Test (con JUnit report)
   - Docker Build
   - Push (solo si rama == main)

4. Failure Strategy:
   - Si un servicio falla, los demás continúan
   - Marcar pipeline como "partial success" si alguno falla

Genera el YAML completo y créalo como "cinema-monorepo-ci".
```

### Prompt I2: Ejecutar Subset de Servicios

```
Ejecuta el pipeline "cinema-monorepo-ci" solo para estos servicios:
- payment
- booking
- notification

Quiero ver cómo se ejecutan en paralelo.
Muéstrame el progreso de cada uno mientras corren.
```

### Prompt I3: Ejecutar Todos con Paralelismo

```
Ahora ejecuta el pipeline "cinema-monorepo-ci" con target_services="all".

Mientras corre, muéstrame:
1. Qué servicios están corriendo en paralelo (máximo 4)
2. Cuáles están en queue
3. El progreso general (X de 8 completados)

Al final, genera un reporte comparativo de tiempos por servicio.
```

### Prompt I4: Habilitar Test Intelligence

```
Modifica el pipeline "cinema-monorepo-ci" para habilitar Test Intelligence en el stage de Unit Test.

Configuración de TI:
- Lenguaje: Go
- Build tool: go test
- Test reports: JUnit XML
- Test splitting: por tiempo de ejecución previo

Muéstrame el YAML modificado y aplica los cambios.
```

### Prompt I5: Demostrar Test Intelligence

```
Acabo de modificar el archivo services/payment/internal/api/payment.go.

Ejecuta el pipeline con Test Intelligence habilitado y muéstrame:
1. Cuántos tests TOTAL hay en el monorepo
2. Cuántos tests SELECCIONÓ TI para esta ejecución
3. El porcentaje de ahorro
4. El call graph que TI usó para la selección

Compara el tiempo estimado con/sin TI.
```

### Prompt I6: Métricas de Test Intelligence

```
Genera un reporte de métricas de Test Intelligence para las últimas 10 ejecuciones del pipeline "cinema-monorepo-ci".

Incluye:
1. Tests totales vs tests ejecutados (promedio)
2. Tiempo ahorrado por ejecución
3. Ahorro acumulado en horas
4. Precisión de TI (tests seleccionados que realmente fallaron)

Visualiza como tabla y gráfico ASCII si es posible.
```

---

## DEMO AVANZADO: AI-Assisted DevOps con MCP

### Prompt A1: Exploración del Estado

```
Muéstrame el estado actual de todos los pipelines en el proyecto de Harness "CristianRamirez".

Para cada pipeline, incluye:
- Nombre
- Última ejecución (fecha, duración, estado)
- Tasa de éxito de las últimas 10 ejecuciones

Si algún pipeline tiene problemas recurrentes, destácalo.
Formato como resumen ejecutivo para compartir en standup.
```

### Prompt A2: Diagnóstico de Fallo

```
El pipeline "cinema-monorepo-ci" falló en su última ejecución.

Haz un diagnóstico completo:
1. ¿Qué servicio falló?
2. ¿En qué stage/step?
3. ¿Cuál es el error exacto?
4. ¿Es un flaky test o un fallo real?
5. ¿Qué archivo necesito modificar para arreglarlo?

Si es retriable (fallo de red, timeout), reintenta automáticamente.
Si es un bug de código, abre el archivo relevante en VS Code.
```

### Prompt A3: Crear Pipeline de Deployment

```
Crea un pipeline de deployment para el monorepo de cinema.

NOMBRE: cinema-deploy-staging

FLUJO:
1. TRIGGER: Cuando "cinema-monorepo-ci" termine exitosamente en rama main
2. APPROVAL: Requiere aprobación de un miembro del grupo "platform-team"
3. DEPLOY: 
   - Actualizar tags de imagen en docker-compose.yml
   - Hacer docker-compose pull && up -d en servidor staging
4. VERIFY: Health check de todos los servicios (/ping endpoints)
5. NOTIFY: Mensaje a Slack canal #deployments con resumen
6. ROLLBACK: Si health check falla en 5 min, revertir al tag anterior

VARIABLES:
- staging_server: staging.cinema.local
- slack_webhook: (usar secret "slack_deployments")
- previous_version: (capturar antes del deploy)

Genera el YAML, explícame cada sección, y créalo cuando yo apruebe.
```

### Prompt A4: Pipeline Multi-Environment

```
Extiende el pipeline de deployment para soportar múltiples ambientes.

AMBIENTES:
1. staging (auto-deploy desde main)
2. production (requiere aprobación + ventana de deployment)

CONFIGURACIÓN PRODUCTION:
- Solo deploy en horario: Lunes-Jueves, 10:00-16:00 UTC
- Requiere 2 aprobaciones de "senior-engineers"
- Deployment canary: 10% tráfico por 15 min, luego 100%
- Notificación a PagerDuty además de Slack
- Rollback automático si error rate > 1%

Muestra cómo estructurar esto con environment overrides en Harness.
```

### Prompt A5: Pipeline con Feature Flags

```
Integra Harness Feature Flags en el pipeline de deployment.

ESCENARIO:
El servicio "payment" tiene una nueva feature "instant-refunds" que queremos lanzar gradualmente.

CONFIGURACIÓN:
1. Crear feature flag "instant_refunds_enabled"
2. En staging: flag ON para todos
3. En production: flag ON solo para 5% de usuarios

PIPELINE UPDATES:
1. Después del deploy, activar el flag según ambiente
2. Si error rate sube, desactivar flag automáticamente
3. Agregar step de verificación: "¿el flag está respondiendo correctamente?"

Genera los cambios necesarios en el pipeline.
```

### Prompt A6: Generar Documentación

```
Genera documentación completa de todos los pipelines de CI/CD que hemos creado.

FORMATO: Markdown para el README del equipo

INCLUIR:
1. Diagrama de flujo de cada pipeline (ASCII o Mermaid)
2. Variables y secrets requeridos
3. Triggers configurados
4. Proceso de aprobación
5. Comandos para ejecutar manualmente
6. Troubleshooting común

Guarda en docs/PIPELINES.md del repositorio.
```

---

## PROMPTS DE EMERGENCIA (Si algo falla en la demo)

### Fallback: Listar Recursos

```
Lista todos los recursos de Harness disponibles:
- Pipelines
- Services  
- Environments
- Connectors

Solo muéstrame los nombres, sin ejecutar nada.
```

### Fallback: Estado Simple

```
¿Cuál es el estado del proyecto de Harness?
Solo necesito saber si la conexión funciona.
```

### Fallback: Ejecutar Task Local

```
El Harness MCP no responde. Ejecuta los tests localmente con:
task test:unit SERVICE=booking

Y muéstrame el resultado.
```

---

## TRANSICIONES SUGERIDAS

### De Básico a Intermedio
> "Acabamos de ver cómo crear un pipeline para UN servicio. Pero ustedes tienen 8. ¿Van a duplicar esto 8 veces? Déjenme mostrarles Looping Strategy..."

### De Intermedio a Avanzado
> "Matrix y TI son poderosos, pero aún requieren escribir YAML. ¿Qué tal si simplemente le DECIMOS a Harness lo que queremos? Aquí es donde el MCP entra..."

### Cierre
> "Todo lo que han visto - crear pipelines, ejecutarlos, diagnosticar fallos, generar documentación - lo hicimos sin salir de VS Code, usando lenguaje natural. Esto no es el futuro de DevOps, es el presente. Y es exclusivo de Harness."

---

## MÉTRICAS DE IMPACTO (Para el TELL final)

```
┌─────────────────────────────────────────────────────────────┐
│                    ROI DE HARNESS CI                        │
├─────────────────────────────────────────────────────────────┤
│  Looping Strategy:                                          │
│    • 8 workflows → 1 pipeline = 87% menos YAML              │
│    • Mantenimiento: 8 horas/mes → 1 hora/mes                │
├─────────────────────────────────────────────────────────────┤
│  Test Intelligence:                                         │
│    • 36 tests → 4 tests (cambio en 1 servicio)             │
│    • Tiempo: 30s → 5s = 83% reducción                       │
│    • Por mes (100 builds): 42 min ahorrados                 │
├─────────────────────────────────────────────────────────────┤
│  AI-Assisted (MCP):                                         │
│    • Crear pipeline: 30 min → 2 min                         │
│    • Diagnosticar fallo: 10 min → 30 seg                    │
│    • Onboarding: 2 días → 2 horas                           │
├─────────────────────────────────────────────────────────────┤
│  TOTAL: 60% reducción en tiempo de CI/CD                    │
│         40% reducción en costos de infraestructura          │
└─────────────────────────────────────────────────────────────┘
```

---

*Prompts listos para demo - Harness Sales Engineering*
