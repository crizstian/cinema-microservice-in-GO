# Harness Sales Engineer Demo Playbook

> **Repositorio**: Cinema Microservices (Go Monorepo)  
> **Audiencia**: DevOps Engineers, Platform Teams, Engineering Leaders  
> **Formato**: Tell → Show → Tell  
> **Objetivo**: Demostrar diferenciadores vs GitHub Actions, GitLab CI, Azure DevOps

---

## Tabla de Contenidos

1. [Setup Pre-Demo](#setup-pre-demo)
2. [Demo Básico: CI Pipeline con Variables](#demo-básico)
3. [Demo Intermedio: Looping Strategy + Test Intelligence](#demo-intermedio)
4. [Demo Avanzado: AI-Assisted DevOps con MCP](#demo-avanzado)
5. [Cheat Sheet de Comandos](#cheat-sheet)
6. [Objeciones Comunes](#objeciones-comunes)

---

## Setup Pre-Demo

### Requisitos
```bash
# Clonar repositorio
git clone https://github.com/crizstian/cinema-microservices.git
cd cinema-microservices

# Verificar servicios disponibles
ls services/
# → booking cinema movie notification payment seat showtime user

# Verificar Taskfile
task --list

# Tener VS Code con extensión Claude Code + Harness MCP
```

### Verificar Harness MCP Server
```bash
# En VS Code, abrir terminal y verificar MCP
claude mcp list
# Debe mostrar: harness, github, perplexity
```

---

# DEMO BÁSICO
## CI Pipeline con Variables y Build de Microservicio

**Duración**: 10-15 minutos  
**Audiencia**: Equipos comenzando con CI/CD  
**Wow Factor**: Pipeline YAML simplificado vs GitHub Actions verboso

---

### PROMPT 1: Contexto y Exploración

```
Actúa como Sales Engineer de Harness. Estás haciendo una demo de CI pipelines para un equipo de DevOps que actualmente usa GitHub Actions.

CONTEXTO DEL REPOSITORIO:
- Monorepo Go con 8 microservicios: booking, cinema, movie, notification, payment, seat, showtime, user
- Cada servicio tiene su propio go.mod en services/{nombre}/
- Dockerfile centralizado en platform/docker/go-service/Dockerfile
- Build args: SERVICE_NAME, SERVICE_PORT, VERSION, COMMIT_SHA
- Tests con JUnit XML output en tests/test-results/
- Taskfile.yml con 30+ tareas automatizadas

DEMO OBJETIVO:
Crear un pipeline básico de CI que:
1. Haga checkout del código
2. Ejecute lint (go vet)
3. Ejecute tests unitarios de UN servicio (booking)
4. Genere reporte JUnit
5. Build de imagen Docker

FORMATO Tell → Show → Tell:

**TELL (2 min)**: 
"En GitHub Actions, para hacer esto necesitarían un workflow de ~80 líneas con múltiples jobs, configurar runners, manejar artifacts manualmente. En Harness, lo resolvemos en menos de 30 líneas con un pipeline declarativo que además tiene variables nativas, sin necesidad de scripts bash para pasarlas entre steps."

**SHOW (8 min)**:
1. Abre Harness UI → Project → Pipelines → Create
2. Muestra el Pipeline Studio visual
3. Crea el pipeline con los stages mencionados
4. Ejecuta y muestra logs en tiempo real
5. Muestra el reporte JUnit integrado

**TELL (2 min)**:
"Lo que acabamos de crear en 5 minutos, con feedback visual inmediato, en GitHub Actions les tomaría configurar YAML, hacer push, esperar el runner, revisar logs fragmentados. Y esto es solo un servicio - esperen a ver cómo escalamos a 8."

Genera el YAML del pipeline de Harness optimizado para esta demo, con comentarios explicativos para el SE.
```

---

### PROMPT 2: Generar Pipeline YAML

```
Genera el pipeline YAML de Harness para el Demo Básico con estas especificaciones:

PIPELINE: cinema-booking-ci
STAGES:
1. Lint (go vet)
2. Unit Test (con JUnit report)
3. Docker Build

VARIABLES DE PIPELINE:
- service_name: booking (default)
- service_port: 8082
- registry: docker.io/crizstian/cinema

REQUIREMENTS:
- Usar Harness CI con hosted runners
- Connector de Docker Hub pre-configurado: "dockerhub"
- Mostrar cómo las variables se propagan entre steps
- Incluir condiciones de fallo para mostrar quality gates

DIFERENCIADORES A DESTACAR EN COMENTARIOS:
1. Variables nativas (vs secrets de GitHub)
2. Step Groups para organización visual
3. Failure Strategy declarativa
4. Reports integrados (no necesitas actions de terceros)

El YAML debe ser copy-paste ready para la demo.
```

---

### PROMPT 3: Comparación con Competencia

```
Prepara una tabla comparativa para mostrar durante el TELL final del Demo Básico.

COMPARAR: Harness CI vs GitHub Actions vs GitLab CI vs Azure DevOps

CRITERIOS:
1. Líneas de YAML para el mismo pipeline
2. Configuración de variables/secrets
3. Reportes de test integrados
4. Visualización de pipeline
5. Tiempo de setup (nuevo proyecto)
6. Debugging de fallos

FORMATO:
- Tabla markdown
- Incluir iconos ✅ ❌ ⚠️
- Destacar 3 "killer features" de Harness
- Preparar 2 frases de cierre impactantes

La comparación debe ser honesta pero destacando fortalezas reales de Harness.
```

---

# DEMO INTERMEDIO
## Looping Strategy para Monorepo + Test Intelligence

**Duración**: 20-25 minutos  
**Audiencia**: Platform Teams, DevOps Senior  
**Wow Factor**: Un pipeline, 8 servicios, ejecución inteligente

---

### PROMPT 4: Setup de Looping Strategy

```
Actúa como Sales Engineer de Harness. Demo de Looping Strategy para monorepo.

CONTEXTO:
El cliente tiene un monorepo con 8 microservicios Go. Actualmente en GitHub Actions tienen 8 workflows separados (uno por servicio) con ~70% de código duplicado. Quieren:
1. Un solo pipeline para todos los servicios
2. Poder ejecutar uno, varios, o todos
3. No duplicar configuración
4. Paralelismo controlado

SCRIPT DE DEMO (Tell → Show → Tell):

**TELL (3 min)**:
"Veo que tienen 8 workflows casi idénticos. En GitHub Actions la única opción es usar workflow_call o composite actions, que añaden complejidad. En GitLab es similar con includes. 

En Harness tenemos Looping Strategy - defines el pipeline UNA vez y Harness lo ejecuta N veces con diferentes valores. Es como un for-each declarativo, pero con:
- Paralelismo configurable (maxConcurrency)
- Matriz dinámica desde variables
- Acceso a metadata del loop (index, total, item)
- Fallo parcial controlado (si falla booking, movie sigue)"

**SHOW (15 min)**:
1. Crear pipeline con matriz de servicios
2. Mostrar ejecución paralela de 3 servicios
3. Simular fallo en uno, mostrar que otros continúan
4. Mostrar variable <+matrix.service> en logs
5. Cambiar a "all services" y ejecutar

**TELL (3 min)**:
"Acaban de ver 8 builds paralelos en UN pipeline. En GitHub Actions necesitarían matrix strategy que no soporta items dinámicos, o 8 jobs separados. Aquí es una línea de configuración. Y el siguiente paso es aún mejor: Test Intelligence para no ejecutar tests innecesarios."

Genera el YAML del pipeline con Looping Strategy, optimizado para demo.
```

---

### PROMPT 5: Pipeline con Looping Strategy YAML

```
Genera pipeline YAML de Harness con Matrix/Looping Strategy para los 8 microservicios.

SERVICIOS:
- booking (port 8082)
- cinema (port 8085)
- movie (port 8000)
- notification (port 8002)
- payment (port 8001)
- seat (port 3004)
- showtime (port 3003)
- user (port 8004)

REQUIREMENTS:

1. PIPELINE INPUT:
   - target_services: runtime input (default: "all")
   - Opciones: "all", "booking", "cinema", etc.

2. MATRIX STRATEGY:
   ```yaml
   strategy:
     matrix:
       service: <+stage.variables.service_list>
     maxConcurrency: 4
   ```

3. CONDITIONAL LOGIC:
   - Si target_services == "all" → matriz completa
   - Si target_services == "booking" → solo booking

4. STAGES POR SERVICIO:
   - Lint
   - Unit Test
   - Build Docker
   - Push (solo si rama main)

5. FAILURE STRATEGY:
   - Fallo en un servicio NO detiene otros
   - Rollback solo del servicio fallido

COMENTARIOS EN YAML:
- Explicar cada sección para el SE
- Marcar "WOW POINTS" para destacar en demo
- Incluir valores que se pueden modificar en vivo

El SE debe poder copiar este YAML y ejecutar en 2 minutos.
```

---

### PROMPT 6: Test Intelligence Demo

```
Actúa como Sales Engineer de Harness. Demo de Test Intelligence (TI).

CONTEXTO:
El monorepo tiene 36 archivos de test unitarios distribuidos en 8 servicios. 
Sin TI: todos los tests se ejecutan siempre (~30 segundos total).
Con TI: solo tests afectados por cambios (~5 segundos para cambio en 1 servicio).

ESCENARIO DE DEMO:
1. Cambiar services/payment/internal/api/payment.go
2. Mostrar que TI selecciona solo tests de payment
3. Mostrar ahorro de tiempo: 30s → 5s (83% reducción)

**TELL (3 min)**:
"Test Intelligence analiza el código y entiende qué tests están relacionados con qué archivos. No es simplemente 'correr tests del directorio modificado' - es análisis de dependencias real.

Diferencia con la competencia:
- GitHub Actions: No tiene. Necesitas scripts custom.
- GitLab: Tiene 'test impact analysis' en Ultimate ($$$)
- Azure DevOps: Solo para .NET y Java
- Harness: Soporta Go, Java, Python, .NET, JavaScript nativo"

**SHOW (10 min)**:
1. Mostrar pipeline sin TI → 36 tests, 30s
2. Habilitar TI en el step de test
3. Hacer commit en payment/api/payment.go
4. Ejecutar pipeline → TI selecciona 4 tests
5. Mostrar visualización: "Tests Selected: 4/36"
6. Mostrar el call graph que TI construye

**TELL (2 min)**:
"En un monorepo real con miles de tests, esto significa la diferencia entre 45 minutos y 2 minutos de CI. Y TI aprende - cada ejecución mejora su modelo. Esto es AI/ML real aplicado a DevOps, no un buzzword."

Genera:
1. YAML del step con Test Intelligence habilitado
2. Script para simular el cambio en payment
3. Métricas esperadas para mostrar
```

---

### PROMPT 7: Métricas de Test Intelligence

```
Prepara los datos y visualizaciones para el demo de Test Intelligence.

DATOS DEL REPOSITORIO:
- 36 archivos de test
- 8 servicios
- Promedio 4-5 tests por servicio

ESCENARIOS A MOSTRAR:

1. CAMBIO EN UN SERVICIO (payment):
   - Sin TI: 36 tests, ~30s
   - Con TI: 4 tests, ~5s
   - Ahorro: 83%

2. CAMBIO EN SHARED CODE (si existiera):
   - Sin TI: 36 tests
   - Con TI: Tests de servicios dependientes
   - Mostrar grafo de dependencias

3. CAMBIO EN DOCKERFILE:
   - Sin TI: 36 tests
   - Con TI: 0 tests (no afecta código)
   - Highlight: TI entiende que infra != código

VISUALIZACIONES:
- Gráfico de barras: Tiempo con/sin TI
- Tabla de tests seleccionados por servicio
- Call graph simplificado

FRASES DE IMPACTO:
- "En 1 mes de uso, TI ahorró X horas de CI"
- "Cada desarrollador ahorra Y minutos por push"
- "ROI: reducción del Z% en costos de runners"

Genera markdown con los datos y visualizaciones ASCII para mostrar en terminal o slides.
```

---

# DEMO AVANZADO
## AI-Assisted DevOps: VS Code + Harness MCP + Claude Code

**Duración**: 25-30 minutos  
**Audiencia**: Innovation Teams, CTOs, Platform Engineering Leads  
**Wow Factor**: Crear y ejecutar pipelines con lenguaje natural desde VS Code

---

### PROMPT 8: Setup del Demo Avanzado

```
Actúa como Sales Engineer de Harness. Demo de AI-Assisted DevOps con MCP.

CONTEXTO TÉCNICO:
- VS Code con extensión Claude Code
- Harness MCP Server configurado
- Acceso a Harness API vía MCP tools:
  - harness_list (pipelines, executions, services)
  - harness_execute (run, retry pipelines)
  - harness_diagnose (análisis de fallos)
  - harness_create (crear pipelines desde descripción)

DIFERENCIADOR ÚNICO:
"Esto es algo que GitHub Actions, GitLab, y Azure DevOps NO pueden hacer. No tienen integración con AI assistants que puedan crear, ejecutar, y diagnosticar pipelines con lenguaje natural."

**TELL (5 min)**:
"Imaginen un mundo donde su equipo no necesita memorizar sintaxis YAML, buscar documentación, o navegar UIs complejas. Simplemente describen lo que quieren y el sistema lo ejecuta.

Esto no es un chatbot que genera texto - es un AI assistant con ACCESO REAL a Harness. Puede:
1. Listar sus pipelines y ver el estado
2. Ejecutar pipelines con parámetros
3. Diagnosticar por qué falló un build
4. Crear pipelines nuevos desde descripción en español
5. Todo desde VS Code, sin cambiar de contexto

La competencia tiene 'AI assistants' que generan YAML que luego tienes que copiar, pegar, validar. Nosotros ejecutamos directamente."

**SHOW (20 min)** - Ver prompts siguientes

**TELL (5 min)**:
"Acaban de ver cómo un desarrollador puede manejar todo su CI/CD sin salir del editor. No es el futuro - es ahora. Y es exclusivo de Harness."

Dame el script completo de la demo con los comandos exactos a ejecutar.
```

---

### PROMPT 9: Demo MCP - Exploración

```
Este es el primer paso del Demo Avanzado. El SE está en VS Code con Claude Code abierto.

ESCENA 1: Exploración del Estado Actual

El SE dice en voz alta:
"Primero, voy a preguntarle a Claude cuál es el estado de mis pipelines sin abrir el navegador."

PROMPT A EJECUTAR EN CLAUDE CODE:
---
Usando el Harness MCP Server, muéstrame:
1. Lista de pipelines en el proyecto CristianRamirez
2. Las últimas 3 ejecuciones del pipeline de CI
3. Si alguna falló, dime cuál y por qué

Formato la respuesta como un resumen ejecutivo que pueda compartir con mi equipo.
---

RESPUESTA ESPERADA (para el SE):
Claude usará:
- harness_list(resource_type="pipeline") → Lista pipelines
- harness_list(resource_type="execution") → Últimas ejecuciones
- harness_diagnose() si hay fallos

El SE destaca:
"Miren - sin abrir Harness UI, sin navegar menús, tengo el estado completo. Y Claude me lo resumió en lenguaje humano, no JSON crudo."

TRANSICIÓN:
"Ahora vamos a ejecutar un pipeline con parámetros, todo desde aquí."
```

---

### PROMPT 10: Demo MCP - Ejecución con Parámetros

```
ESCENA 2: Ejecutar Pipeline con Lenguaje Natural

El SE dice:
"Quiero ejecutar el build solo del servicio payment, en la rama feature/new-payment, sin tener que recordar el nombre exacto del pipeline o la sintaxis de los inputs."

PROMPT A EJECUTAR EN CLAUDE CODE:
---
Ejecuta el pipeline de CI para el monorepo de cinema con estos parámetros:
- Servicio: payment
- Rama: feature/increase-coverage-and-fix-junit
- No hacer push al registry (es un test)

Monitorea la ejecución y avísame cuando termine o si hay errores.
---

RESPUESTA ESPERADA:
Claude usará:
- harness_execute(resource_type="pipeline", action="run", resource_id="cinema-ci", inputs={service: "payment", branch: "...", push: false})
- Polling de estado con harness_list(resource_type="execution")

El SE destaca:
"Observen - no escribí YAML, no busqué el ID del pipeline, no navegué a la UI. Simplemente describí lo que quería en español y se ejecutó. Ahora imaginen esto multiplicado por 50 desarrolladores que no tienen que aprender la sintaxis de Harness."

MOSTRAR:
- El pipeline ejecutándose en tiempo real (split screen con Harness UI)
- Los logs fluyendo
- El resultado final

TRANSICIÓN:
"¿Qué pasa cuando algo falla? Aquí es donde la magia real ocurre."
```

---

### PROMPT 11: Demo MCP - Diagnóstico de Fallos

```
ESCENA 3: Diagnóstico Inteligente de Fallos

SETUP: El SE previamente preparó un pipeline que falla (test que falla, o error de build).

El SE dice:
"Tengo un pipeline que falló esta mañana. En GitHub Actions, tendría que abrir el workflow, buscar el job que falló, expandir los logs, buscar el error. Aquí, simplemente pregunto."

PROMPT A EJECUTAR EN CLAUDE CODE:
---
El pipeline cinema-ci falló en la última ejecución. 
Analiza qué pasó y dame:
1. El stage/step exacto que falló
2. La causa raíz del error
3. Sugerencia de cómo arreglarlo
4. Si es algo que se puede reintentar, hazlo automáticamente
---

RESPUESTA ESPERADA:
Claude usará:
- harness_diagnose(execution_id="...") → Análisis de causa raíz
- Lectura de logs del step fallido
- harness_execute(action="retry") si aplica

EJEMPLO DE RESPUESTA DE CLAUDE:
```
## Análisis de Fallo - Pipeline cinema-ci

**Execution ID**: abc123
**Stage Fallido**: Unit Test - payment
**Step Fallido**: Run go test

### Causa Raíz
El test `TestPaymentRefund` en `payment_test.go:142` falló con:
- Expected: `status: "refunded"`
- Actual: `status: "pending"`

Esto sugiere un cambio en la lógica de refund que no se reflejó en el test.

### Archivos Relacionados
- services/payment/internal/api/payment.go (modificado hace 2h)
- services/payment/internal/api/payment_test.go (no modificado)

### Sugerencia
Actualizar el test para reflejar el nuevo comportamiento del refund, o revertir el cambio en payment.go si fue accidental.

### Acción
No es retriable (el código necesita fix). Abriendo el archivo relevante...
```

El SE destaca:
"Esto hubiera tomado 10 minutos de investigación manual. Claude lo hizo en 5 segundos, me dio contexto, y hasta abrió el archivo que necesito editar. Esto es productivity multiplicado."

TRANSICIÓN:
"Ahora el momento wow final - vamos a crear un pipeline completamente nuevo describiendo lo que queremos."
```

---

### PROMPT 12: Demo MCP - Crear Pipeline con Lenguaje Natural

```
ESCENA 4: Crear Pipeline desde Descripción Natural (MOMENTO WOW)

El SE dice:
"Para el cierre, vamos a hacer algo que ninguna otra plataforma puede hacer hoy. Voy a crear un pipeline de deployment completo, describiendo lo que quiero en lenguaje natural."

PROMPT A EJECUTAR EN CLAUDE CODE:
---
Crea un nuevo pipeline de Harness para deployment con estas características:

NOMBRE: cinema-deploy-staging

DESCRIPCIÓN:
- Trigger: Cuando el pipeline de CI termina exitosamente
- Aprobación: Requiere aprobación manual del team lead
- Deploy: Actualizar las imágenes en docker-compose para staging
- Notificación: Enviar mensaje a Slack cuando el deploy termine
- Rollback: Si el health check falla en 5 minutos, rollback automático

SERVICIOS A DEPLOYAR:
- Todos los que pasaron el CI (usar output del pipeline anterior)

AMBIENTE: staging
REGISTRY: docker.io/crizstian/cinema

Genera el pipeline, muéstramelo para revisión, y si apruebo, créalo en Harness.
---

RESPUESTA ESPERADA:
Claude:
1. Genera el YAML del pipeline
2. Explica cada sección
3. Pide confirmación
4. Usa harness_create() para crearlo

El SE destaca:
"Acabo de describir un pipeline de deployment complejo - con aprobaciones, notificaciones, rollback automático - y Claude lo creó en 30 segundos. En la competencia, esto es 1-2 horas de documentación, trial and error, y debugging de YAML."

CIERRE DE DEMO:
"Lo que han visto hoy no es el roadmap de Harness - es lo que pueden usar AHORA. AI-assisted DevOps no es un slide de PowerPoint, es productividad real para sus equipos."
```

---

### PROMPT 13: Demo MCP - Script Completo

```
Genera el script completo del Demo Avanzado con tiempos, transiciones, y puntos de énfasis.

FORMATO:
```
[00:00] INTRO
- Qué: Presentación del concepto AI-Assisted DevOps
- Decir: "..."
- Hacer: Abrir VS Code con el repo

[02:00] TELL - Contexto
- Qué: Explicar la diferencia con competencia
- Decir: "..."
- Mostrar: Slide comparativo (opcional)

[05:00] SHOW - Escena 1: Exploración
- Qué: Listar pipelines con MCP
- Comando: [prompt exacto]
- Destacar: "Observen cómo..."
- Duración: 3 min

[08:00] SHOW - Escena 2: Ejecución
...

[25:00] TELL - Cierre
- Qué: Resumen de capacidades
- Decir: Frase de impacto final
- CTA: "¿Listos para una prueba con su propio repo?"
```

Incluye:
- Tiempos exactos
- Frases textuales para cada momento
- Qué hacer si algo falla (contingencias)
- Preguntas anticipadas del cliente
```

---

# CHEAT SHEET

## Comandos Rápidos para Demo

```bash
# Verificar servicios
ls services/
# → booking cinema movie notification payment seat showtime user

# Ver tareas disponibles
task --list

# Ejecutar tests de un servicio
task test:unit SERVICE=payment

# Build de un servicio
task build SERVICE=payment TAG=demo-v1

# Ver logs de última ejecución
task dev:logs SERVICE=payment
```

## Harness MCP Tools

```
harness_list       → Listar recursos (pipelines, executions, services)
harness_execute    → Ejecutar/reintentar pipelines
harness_diagnose   → Analizar fallos con causa raíz
harness_create     → Crear recursos desde descripción
harness_status     → Estado general del proyecto
```

## Variables de Pipeline Comunes

```yaml
<+pipeline.name>           # Nombre del pipeline
<+pipeline.executionId>    # ID de ejecución
<+stage.name>              # Nombre del stage actual
<+matrix.service>          # Item actual en loop
<+matrix.index>            # Índice del loop (0, 1, 2...)
<+codebase.branch>         # Rama del commit
<+codebase.commitSha>      # SHA corto del commit
<+trigger.payload.branch>  # Rama del trigger
```

## Respuestas a Preguntas Comunes

| Pregunta | Respuesta |
|----------|-----------|
| "¿Funciona con nuestro runner self-hosted?" | "Sí, Harness soporta hosted, self-hosted, y Kubernetes runners" |
| "¿El MCP es open source?" | "Sí, harness-mcp está en GitHub. El protocolo MCP es de Anthropic." |
| "¿Qué pasa si Claude genera YAML incorrecto?" | "El MCP valida antes de crear. Además, siempre muestra el YAML para revisión." |
| "¿Cuánto cuesta Test Intelligence?" | "Incluido en el tier Team. El ahorro en runners paga la diferencia." |

---

# OBJECIONES COMUNES

## "Ya tenemos GitHub Actions funcionando"

**Respuesta**:
"GitHub Actions es excelente para proyectos simples. Pero ustedes tienen un monorepo con 8 servicios. ¿Cuánto tiempo pasan manteniendo 8 workflows casi idénticos? ¿Cuántos minutos de CI desperdician corriendo todos los tests cuando solo cambió un servicio?

Harness les da:
1. Un pipeline, 8 servicios (Looping Strategy)
2. Solo los tests necesarios (Test Intelligence)
3. Creación y diagnóstico con AI (MCP)

No es reemplazar lo que funciona - es escalar lo que tienen."

## "Parece complejo"

**Respuesta**:
"Entiendo la preocupación. Déjame mostrarte algo..."
[Ejecutar el demo de MCP creando un pipeline con lenguaje natural]
"...esto es lo opuesto a complejo. Tu equipo describe lo que quiere, Harness lo ejecuta."

## "El costo de migración es alto"

**Respuesta**:
"Harness puede correr en paralelo con su CI actual. Empiecen con un servicio, validen el ROI con Test Intelligence (típicamente 40-60% reducción en tiempo de CI), y escalen cuando estén listos. No es big bang."

---

*Playbook generado para demos de Harness CI/CD usando el repositorio Cinema Microservices*  
*Última actualización: 2026-04-08*
