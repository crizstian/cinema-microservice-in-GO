# Kubernetes Deployment Guide

Guía completa para desplegar Cinema Microservices en Kubernetes.
Diseñada para todos los niveles: desde principiantes hasta expertos.

---

## Tabla de Contenidos

1. [Prerequisitos](#prerequisitos)
2. [Fase 1: Validación de Configuración](#fase-1-validación-de-configuración)
3. [Fase 2: Despliegue de Infraestructura](#fase-2-despliegue-de-infraestructura)
4. [Fase 3: Despliegue de Microservicios](#fase-3-despliegue-de-microservicios)
5. [Fase 4: Validación del Despliegue](#fase-4-validación-del-despliegue)
6. [Fase 5: Troubleshooting](#fase-5-troubleshooting)
7. [Fase 6: Cleanup](#fase-6-cleanup)
8. [Quick Reference](#quick-reference)

---

## Prerequisitos

### Herramientas requeridas

#### 1. Verificar kubectl

**Objetivo:** Confirmar que tienes instalada la herramienta de línea de comandos de Kubernetes.

**Por qué es importante:** `kubectl` es la interfaz principal para interactuar con cualquier cluster de Kubernetes. Sin ella, no puedes desplegar, inspeccionar ni gestionar recursos.

```bash
kubectl version --client
```

**Respuesta esperada:**
```
Client Version: v1.30.0
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
```

**Si falla:** Instala kubectl siguiendo la [guía oficial](https://kubernetes.io/docs/tasks/tools/).

---

#### 2. Verificar acceso al cluster

**Objetivo:** Confirmar que puedes conectarte al cluster de Kubernetes.

**Por qué es importante:** Tu máquina local necesita credenciales válidas para comunicarse con el API server del cluster. Sin acceso, ningún comando funcionará.

```bash
kubectl cluster-info
```

**Respuesta esperada:**
```
Kubernetes control plane is running at https://35.231.43.35
GLBCDefaultBackend is running at https://35.231.43.35/api/v1/...
KubeDNS is running at https://35.231.43.35/api/v1/...
```

**Si falla con "connection refused":**
- Verifica tu archivo `~/.kube/config`
- Para GKE: `gcloud container clusters get-credentials CLUSTER_NAME --zone ZONE --project PROJECT`
- Para EKS: `aws eks update-kubeconfig --name CLUSTER_NAME`

---

#### 3. Verificar contexto actual

**Objetivo:** Confirmar que estás apuntando al cluster correcto.

**Por qué es importante:** Puedes tener múltiples clusters configurados (dev, staging, prod). Ejecutar comandos en el cluster equivocado puede causar problemas graves en producción.

```bash
kubectl config current-context
```

**Respuesta esperada:**
```
gke_sales-209522_us-east1-b_se-sandbox
```

**Para cambiar de contexto:**
```bash
# Listar contextos disponibles
kubectl config get-contexts

# Cambiar a otro contexto
kubectl config use-context NOMBRE_DEL_CONTEXTO
```

---

### Requisitos mínimos del cluster

**Objetivo:** Asegurar que el cluster tiene suficientes recursos para los microservicios.

**Por qué es importante:** Si el cluster no tiene suficientes recursos, los pods quedarán en estado "Pending" indefinidamente.

| Entorno | Nodes | CPU | Memory | Storage |
|---------|-------|-----|--------|---------|
| dev | 1 | 2 cores | 4GB | 20GB |
| staging | 3 | 4 cores | 8GB | 50GB |
| prod | 3+ | 8 cores | 16GB | 100GB |

```bash
# Verificar nodos disponibles
kubectl get nodes

# Ver recursos disponibles por nodo
kubectl describe nodes | grep -A 5 "Allocatable:"
```

**Respuesta esperada:**
```
NAME                                STATUS   ROLES    AGE   VERSION
gke-se-sandbox-pool-01-xxx          Ready    <none>   18d   v1.34.4
gke-se-sandbox-pool-01-yyy          Ready    <none>   18d   v1.34.4
```

---

### Configuración del Nodo Dedicado (SE LATAM)

**Objetivo:** Configurar los pods para que se desplieguen en el nodo dedicado del equipo SE LATAM.

**Por qué es importante:** El cluster es compartido por múltiples equipos. El nodo SE LATAM está reservado exclusivamente para demos mediante:
- **Taint:** Repele pods que no tengan la tolerancia correcta
- **Label:** Permite seleccionar específicamente este nodo

#### Metadata del Nodo

| Tipo | Key | Value | Efecto |
|------|-----|-------|--------|
| **Node** | - | `gke-se-sandbox-se-latam-nodepool-22d1afe2-88nb` | - |
| **Taint** | `dedicated` | `selatam_demo_space` | `NoSchedule` |
| **Label** | `owner` | `cristian-ramirez` | - |
| **Label** | `purpose` | `custom-demo` | - |
| **Label** | `scope` | `discovery` | - |
| **Network Tag** | - | `terraform`, `iacm` | - |

#### Verificar el nodo

```bash
# Buscar nodo con el label owner
kubectl get nodes -l owner=cristian-ramirez
```

**Respuesta esperada:**
```
NAME                                              STATUS   ROLES    AGE   VERSION
gke-se-sandbox-se-latam-nodepool-22d1afe2-88nb    Ready    <none>   17d   v1.34.4-gke.1193000
```

```bash
# Ver detalles del taint y labels
kubectl describe node -l owner=cristian-ramirez | grep -E "(Taints:|owner|purpose|scope)"
```

**Respuesta esperada:**
```
                    owner=cristian-ramirez
                    purpose=custom-demo
                    scope=discovery
Taints:             dedicated=selatam_demo_space:NoSchedule
```

#### Configuración requerida en los pods

Para que los pods se desplieguen en este nodo, necesitan:

**1. Toleration** (para soportar el taint):
```yaml
tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "selatam_demo_space"
    effect: "NoSchedule"
```

**2. NodeSelector** (para seleccionar el nodo por owner):
```yaml
nodeSelector:
  owner: cristian-ramirez
```

**Nota:** Esta configuración ya está incluida en los templates del entorno `dev`. Si tus pods quedan en `Pending`, verifica que tengan ambas configuraciones.

---

## Fase 1: Validación de Configuración

### 1.1 Verificar estructura de manifiestos

**Objetivo:** Confirmar que todos los templates de Kubernetes y el renderer Go existen en el repositorio.

**Por qué es importante:** Los templates usan Go templating (`{{ .Values.* }}`) para generar manifiestos. El renderer Go combina templates + values para producir YAML válido.

```bash
# Verificar estructura completa
ls -la platform/deploy/kubernetes/
```

**Respuesta esperada:**
```
bin/          # Binario del renderer Go compilado
cmd/          # Código fuente del renderer
rendered/     # Manifiestos generados (output)
scripts/      # Scripts de deployment
templates/    # Templates con Go templating
values/       # Configuración por entorno y servicio
```

```bash
# Verificar templates organizados
ls -la platform/deploy/kubernetes/templates/
```

**Respuesta esperada:**
```
infrastructure/    # Templates de MongoDB, Ingress
services/          # Templates de microservicios
```

```bash
# Verificar templates de servicios
ls platform/deploy/kubernetes/templates/services/
```

**Respuesta esperada:**
```
configmap.yaml     # Variables de configuración del servicio
deployment.yaml    # Define cómo se despliega el contenedor
hpa.yaml           # Horizontal Pod Autoscaler (escalado automático)
networkpolicy.yaml # Reglas de firewall entre pods
pdb.yaml           # Pod Disruption Budget (alta disponibilidad)
secret.yaml        # Credenciales y datos sensibles
service.yaml       # Endpoint interno + ServiceAccount
```

```bash
# Verificar templates de infraestructura
ls platform/deploy/kubernetes/templates/infrastructure/
```

**Respuesta esperada:**
```
mongodb.yaml       # StatefulSet de MongoDB con replicaset
ingress-nginx.yaml # Ingress controller
```

**Si falta algún archivo:** Verifica que clonaste el repositorio correctamente o ejecuta `git pull`.

---

### 1.2 Verificar estructura de values

**Objetivo:** Revisar la configuración organizada por capas (base → entorno → servicio).

**Por qué es importante:** El renderer Go fusiona valores en orden: `base.yaml` → `environments/{env}.yaml` → `services/{svc}.yaml`. Valores posteriores sobrescriben anteriores.

```bash
# Verificar estructura de values
ls -la platform/deploy/kubernetes/values/
```

**Respuesta esperada:**
```
base.yaml           # Defaults globales (nodeSelector, tolerations, recursos base)
infrastructure.yaml # Config de MongoDB, Ingress
environments/       # Config por entorno (dev, staging, prod)
services/           # Config por servicio (booking, movie, etc.)
```

```bash
# Ver values base (aplicados a todos)
cat platform/deploy/kubernetes/values/base.yaml
```

**Respuesta esperada:**
```yaml
# Node placement (SE LATAM dedicated node)
nodeOwner: cristian-ramirez
nodeTaintValue: selatam_demo_space

# Image defaults
image:
  registry: crizstian
  pullPolicy: IfNotPresent

# Default resources
resources:
  requests:
    cpu: 50m
    memory: 128Mi
...
```

```bash
# Ver values por servicio
for svc in booking movie cinema; do
  echo "=== $svc ===" && cat platform/deploy/kubernetes/values/services/$svc.yaml
done
```

**Respuesta esperada:**
```yaml
=== booking ===
port: 8001
dbName: booking
dependencies:
  - seat
  - payment
  - showtime
  - notification
...
```

**Qué verificar:**
- `port`: Cada servicio debe tener un puerto único
- `dbName`: Nombre de la base de datos que usará el servicio
- `resources`: Recursos asignados (sobrescriben base si se especifican)

---

### 1.3 Verificar values por entorno

**Objetivo:** Revisar la configuración específica del entorno (dev/staging/prod).

**Por qué es importante:** Cada entorno tiene diferentes requisitos de recursos, réplicas, y configuración. Prod necesita más réplicas y recursos que dev.

```bash
cat platform/deploy/kubernetes/values/environments/dev.yaml
```

**Respuesta esperada:**
```yaml
environment: dev
namespace: cinema-dev

image:
  pullPolicy: Always

database:
  servers: mongodb.cinema-dev.svc.cluster.local:27017
  replica: ""  # Empty for standalone MongoDB (no replica set)
  user: cinema
  password: cinema123

observability:
  logLevel: debug

services:
  booking: http://booking.cinema-dev.svc.cluster.local
  movie: http://movie.cinema-dev.svc.cluster.local
  # ... otros servicios

replicas: 1
resources:
  requests:
    cpu: 25m
    memory: 64Mi
```

**Diferencias clave entre entornos:**

| Configuración | Dev | Staging | Prod |
|--------------|-----|---------|------|
| `replicas` | 1 | 2 | 3 |
| `observability.logLevel` | debug | info | warn |
| `resources.requests.cpu` | 25m | 50m | 100m |
| `autoscaling.minReplicas` | 1 | 2 | 3 |
| `pdb.minAvailable` | 0 | 1 | 2 |

---

### 1.4 Test de rendering (dry-run)

**Objetivo:** Generar los manifiestos finales usando el renderer Go y validar que son YAML válido.

**Por qué es importante:** El renderer Go combina templates (`{{ .Values.* }}`) + values YAML. Este paso detecta errores de sintaxis ANTES de aplicar al cluster.

```bash
# Paso 1: Compilar el renderer (solo la primera vez)
cd platform/deploy/kubernetes/cmd/render && go build -o ../../bin/render .
```

```bash
# Paso 2: Renderizar manifiestos de un servicio
task k8s:render SERVICE=booking ENV=dev VERSION=v1.0.0
```

**Respuesta esperada:**
```
Rendered: platform/deploy/kubernetes/rendered/dev/booking/configmap.yaml
Rendered: platform/deploy/kubernetes/rendered/dev/booking/deployment.yaml
Rendered: platform/deploy/kubernetes/rendered/dev/booking/hpa.yaml
Rendered: platform/deploy/kubernetes/rendered/dev/booking/networkpolicy.yaml
Rendered: platform/deploy/kubernetes/rendered/dev/booking/pdb.yaml
Rendered: platform/deploy/kubernetes/rendered/dev/booking/secret.yaml
Rendered: platform/deploy/kubernetes/rendered/dev/booking/service.yaml
Rendered templates to: platform/deploy/kubernetes/rendered/dev/booking
```

```bash
# Paso 3: Verificar contenido generado
cat platform/deploy/kubernetes/rendered/dev/booking/deployment.yaml | head -50
```

**Respuesta esperada:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: booking
  namespace: cinema-dev
  labels:
    app.kubernetes.io/name: booking
    app.kubernetes.io/version: "v1.0.0"
    app.kubernetes.io/component: service
    app.kubernetes.io/environment: dev
spec:
  replicas: 1
  ...
    spec:
      nodeSelector:
        owner: cristian-ramirez          # ← Del values/base.yaml
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "selatam_demo_space"    # ← Tolera el taint del nodo
          effect: "NoSchedule"
```

**Qué verificar:**
- Los valores `{{ .Values.* }}` fueron reemplazados por valores reales
- `nodeSelector` y `tolerations` están presentes para el nodo SE LATAM
- No hay errores de sintaxis YAML

```bash
# Paso 4: Validar YAML con kubectl (dry-run)
kubectl apply --dry-run=client -f platform/deploy/kubernetes/rendered/dev/booking/
```

**Respuesta esperada:**
```
configmap/booking-config created (dry run)
secret/booking-secrets created (dry run)
deployment.apps/booking created (dry run)
service/booking created (dry run)
serviceaccount/booking created (dry run)
horizontalpodautoscaler.autoscaling/booking created (dry run)
poddisruptionbudget.policy/booking created (dry run)
networkpolicy.networking.k8s.io/booking created (dry run)
```

**Si falla:** Revisa el error. Los errores comunes son:
- Template syntax error: `{{ .Values.xyz }}` mal formado
- Nil value: campo requerido no existe en values
- YAML indentation: espacios inconsistentes

---

### 1.5 Renderizar todos los servicios

**Objetivo:** Generar manifiestos para los 8 microservicios de una sola vez.

**Por qué es importante:** Asegura consistencia y ahorra tiempo. Todos los servicios usan la misma versión y configuración de entorno.

```bash
task k8s:render:all ENV=dev VERSION=v1.0.0
```

**Respuesta esperada:**
```
Rendering all services for environment: dev, version: v1.0.0
=== Rendering: booking ===
Rendered: .../rendered/dev/booking/configmap.yaml
Rendered: .../rendered/dev/booking/deployment.yaml
...
=== Rendering: movie ===
...
=== Rendering: cinema ===
...
(8 servicios en total)
All services rendered to: .../rendered/dev/
```

```bash
# Verificar estructura generada
ls -la platform/deploy/kubernetes/rendered/dev/
```

**Respuesta esperada:**
```
booking/
cinema/
movie/
notification/
payment/
seat/
showtime/
user/
```

```bash
# Ver contenido de un servicio
ls platform/deploy/kubernetes/rendered/dev/booking/
```

**Respuesta esperada:**
```
configmap.yaml
deployment.yaml
hpa.yaml
networkpolicy.yaml
pdb.yaml
secret.yaml
service.yaml
```

### 1.6 Renderizar infraestructura

**Objetivo:** Generar manifiestos de MongoDB e Ingress-nginx con Go templating.

**Por qué es importante:** La infraestructura también necesita `nodeSelector` y `tolerations` para desplegarse en el nodo SE LATAM dedicado.

```bash
task k8s:infra:render
```

**Respuesta esperada:**
```
Rendered: rendered/infrastructure/mongodb.yaml
Rendered: rendered/infrastructure/ingress-nginx.yaml
Rendered infrastructure to: rendered/infrastructure
```

```bash
# Verificar node scheduling en infraestructura
grep -A5 "nodeSelector" platform/deploy/kubernetes/rendered/infrastructure/mongodb.yaml
```

**Respuesta esperada:**
```yaml
      nodeSelector:
        owner: cristian-ramirez
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "selatam_demo_space"
```

---

## Fase 2: Despliegue de Infraestructura

### 2.1 Crear Namespace de Aplicación

**Objetivo:** Crear un espacio aislado en Kubernetes para nuestros servicios.

**Por qué es importante:** Los namespaces proporcionan:
- **Aislamiento:** Recursos separados de otros equipos/proyectos
- **Seguridad:** Políticas de red y RBAC por namespace
- **Organización:** Fácil visualización y gestión de recursos relacionados

```bash
export KUBECONFIG=/home/devuser/.kube/config

kubectl create namespace cinema-dev --dry-run=client -o yaml | kubectl apply -f -
```

**Respuesta esperada:**
```
namespace/cinema-dev created
```

```bash
# Verificar creación
kubectl get namespace cinema-dev
```

**Respuesta esperada:**
```
NAME         STATUS   AGE
cinema-dev   Active   5s
```

**Si el namespace ya existe:** El comando es idempotente (no falla, solo muestra "unchanged").

---

### 2.2 Desplegar MongoDB

**Objetivo:** Desplegar la base de datos que usarán todos los microservicios.

**Por qué es importante:** MongoDB es el almacén de datos central. Sin él, ningún microservicio puede persistir información.

#### Opción A: Usando manifiestos renderizados (recomendado)

```bash
# Paso 1: Revisar credenciales de ejemplo en values/infrastructure.yaml
cat platform/deploy/kubernetes/values/infrastructure.yaml
```

**Configuración de ejemplo (ya incluida):**
```yaml
mongodb:
  replicas: 1
  rootUser: cinema_admin
  rootPassword: n8XGsZ15Z4OzTqpAXsCAs8CA  # CAMBIAR EN PRODUCCIÓN!
  keyfile: |
    RJfupxJIIETj0XWK85zWHY7AEDVWXQ1UPV9l1E23Ehxm...
  storageClass: standard
  storageSize: 10Gi
```

**Para generar nuevas credenciales (producción):**
```bash
# Generar password seguro
head -c 32 /dev/urandom | base64 | tr -d '=+/' | head -c 24

# Generar keyfile para replicaset
head -c 512 /dev/urandom | base64 | tr -d '\n' | head -c 756
```

```bash
# Paso 2: Renderizar infraestructura
task k8s:infra:render COMPONENT=mongodb
```

**Respuesta esperada:**
```
Rendered: rendered/infrastructure/mongodb.yaml
Rendered infrastructure to: rendered/infrastructure
```

```bash
# Paso 3: Aplicar MongoDB
kubectl apply -f platform/deploy/kubernetes/rendered/infrastructure/mongodb.yaml
```

**Respuesta esperada:**
```
secret/mongodb-secrets created
configmap/mongodb-config created
service/mongodb created
statefulset.apps/mongodb created
```

**Nota:** MongoDB se despliega en el namespace `cinema-dev` (mismo que los microservicios) para simplificar el service discovery.

```bash
# Paso 4: Ejecutar script de deploy con seed
# Este script usa los archivos de seed existentes en platform/docker/mongodb/seed/
platform/deploy/kubernetes/scripts/deploy-mongodb.sh cinema-dev
```

**Respuesta esperada:**
```
=== Deploying MongoDB to namespace: cinema-dev ===
>>> Step 1: Rendering MongoDB template...
>>> Step 2: Applying MongoDB manifests...
>>> Step 3: Waiting for MongoDB to be ready...
>>> Step 4: Creating seed scripts ConfigMap...
>>> Step 5: Running seed job...
>>> Step 6: Waiting for seed job to complete...
=== MongoDB Seed ===
Running seed scripts...
  01-init-replica.js
  02-create-databases.js
  03-create-indexes.js
  04-seed-test-data.js
Verification...
Replica: rs0
Movies: 2
Showtimes: 2
=== Seed Complete ===
=== MongoDB deployment complete ===
```

**Archivos de seed reutilizados** (no duplicados):
```
platform/docker/mongodb/seed/
├── 01-init-replica.js      # Inicializa replica set
├── 02-create-databases.js  # Crea DBs y colecciones
├── 03-create-indexes.js    # Crea índices
└── 04-seed-test-data.js    # Datos de prueba
```

**Datos de seed incluidos:**
| Base de datos | Colección | Registros | Descripción |
|---------------|-----------|-----------|-------------|
| cinema | movies | 2 | The Shawshank Redemption, Inception |
| cinema | cinemas | 1 | Cinema Downtown |
| cinema | rooms | 2 | Room 1 (100 seats), VIP Room (50 seats) |
| cinema | showtimes | 2 | Funciones para mañana |
| cinema | users | 1 | test@example.com |
| cinema_seats | room_layouts | 1 | 100 asientos (10x10, VIP en filas A-B) |
| cinema_seats | showtimes | 2 | Mapeos showtime → room |

#### Opción B: MongoDB simplificado para dev (sin persistencia)

```bash
# Generar credenciales seguras
export MONGO_ROOT_USER=admin
export MONGO_ROOT_PASS=$(openssl rand -base64 24 | tr -d '=+/')

echo "=== MongoDB Credentials ==="
echo "User: $MONGO_ROOT_USER"
echo "Pass: $MONGO_ROOT_PASS"
echo "(GUARDA ESTA CONTRASEÑA - no se puede recuperar)"
```

```bash
# Desplegar MongoDB simplificado en el namespace de la app
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: cinema-dev
spec:
  ports:
    - port: 27017
      targetPort: 27017
  selector:
    app: mongodb
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: cinema-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      nodeSelector:
        owner: cristian-ramirez
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "selatam_demo_space"
          effect: "NoSchedule"
      containers:
        - name: mongodb
          image: mongo:7.0
          ports:
            - containerPort: 27017
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              value: "${MONGO_ROOT_USER}"
            - name: MONGO_INITDB_ROOT_PASSWORD
              value: "${MONGO_ROOT_PASS}"
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
          volumeMounts:
            - name: data
              mountPath: /data/db
      volumes:
        - name: data
          emptyDir: {}
EOF
```

**Respuesta esperada:**
```
service/mongodb created
deployment.apps/mongodb created
```

```bash
# Esperar a que MongoDB esté listo
kubectl wait --namespace cinema-dev \
  --for=condition=ready pod \
  --selector=app=mongodb \
  --timeout=120s
```

**Respuesta esperada:**
```
pod/mongodb-xxxxxxxxx-xxxxx condition met
```

**Si timeout:** El pod puede estar descargando la imagen o sin recursos suficientes.
```bash
# Diagnosticar
kubectl describe pod -n cinema-dev -l app=mongodb
kubectl logs -n cinema-dev -l app=mongodb
```

```bash
# Test de conexión a MongoDB
kubectl run mongo-test --rm -it --restart=Never \
  --image=mongo:8.0 -n cinema-dev -- \
  mongosh mongodb://mongodb:27017 --eval "db.adminCommand('ping')"
```

**Respuesta esperada:**
```
{ ok: 1 }
pod "mongo-test" deleted
```

```bash
# Verificar datos de seed
kubectl run mongo-verify --rm -it --restart=Never \
  --image=mongo:8.0 -n cinema-dev -- \
  mongosh mongodb://mongodb:27017 --eval "
    db = db.getSiblingDB('cinema');
    print('Movies: ' + db.movies.countDocuments());
    print('Cinemas: ' + db.cinemas.countDocuments());
    print('Showtimes: ' + db.showtimes.countDocuments());
    db.movies.find({}, {title: 1, _id: 0}).forEach(m => print('  - ' + m.title));
  "
```

**Respuesta esperada:**
```
Movies: 2
Cinemas: 1
Showtimes: 2
  - The Shawshank Redemption
  - Inception
pod "mongo-verify" deleted
```

**Si falla con "connection refused":**
- Verifica que el pod de MongoDB está Running: `kubectl get pods -n cinema-dev`
- Verifica que el service existe: `kubectl get svc mongodb -n cinema-dev`
- Verifica el Job de seed: `kubectl logs -n cinema-dev job/mongodb-seed`

---

### 2.3 Verificar Infraestructura Completa

**Objetivo:** Confirmar que toda la infraestructura está running antes de desplegar los microservicios.

**Por qué es importante:** Desplegar microservicios sin infraestructura causará CrashLoopBackOff porque no podrán conectarse a MongoDB.

```bash
echo "=== Pods en cinema-dev ===" 
kubectl get pods -n cinema-dev

echo ""
echo "=== Services en cinema-dev ===" 
kubectl get svc -n cinema-dev
```

**Respuesta esperada:**
```
=== Pods en cinema-dev ===
NAME                       READY   STATUS    RESTARTS   AGE
mongodb-xxxxxxxxx-xxxxx    1/1     Running   0          5m

=== Services en cinema-dev ===
NAME      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)
mongodb   ClusterIP   34.118.xxx.xxx   <none>        27017/TCP
```

**Checklist antes de continuar:**
- [ ] MongoDB pod en status `Running` con `1/1` READY
- [ ] MongoDB service existe con ClusterIP asignado

---

## Fase 3: Despliegue de Microservicios

### Entendiendo el orden de despliegue

**Objetivo:** Desplegar los servicios en el orden correcto según sus dependencias.

**Por qué es importante:** El servicio `booking` depende de `payment`, `seat`, `showtime` y `notification`. Si lo despliegas primero, fallará al intentar conectarse a servicios que no existen.

```
Arquitectura de dependencias:

┌─────────────────────────────────────────────────────────────┐
│                    BOOKING (SAGA Orchestrator)               │
│                  Depende de: todos los demás                 │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│     SEAT      │    │    PAYMENT    │    │ NOTIFICATION  │
│ Depende de:   │    │ Independiente │    │ Independiente │
│   showtime    │    └───────────────┘    └───────────────┘
└───────────────┘
        │
        ▼
┌───────────────┐
│   SHOWTIME    │
│ Depende de:   │
│ movie, cinema │
└───────────────┘
        │
        ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│     MOVIE     │    │    CINEMA     │    │     USER      │
│ Independiente │    │ Independiente │    │ Independiente │
└───────────────┘    └───────────────┘    └───────────────┘
```

**Orden de despliegue:**
1. **Base:** movie, cinema, user (sin dependencias)
2. **Intermedio:** showtime, seat, payment, notification
3. **Orquestador:** booking (depende de todos)

---

### 3.1 Desplegar Servicios Base

**Objetivo:** Desplegar los microservicios que no tienen dependencias de otros servicios.

**Por qué es importante:** Estos servicios solo dependen de MongoDB. Desplegarlos primero crea los endpoints necesarios para los servicios intermedios.

```bash
export KUBECONFIG=/home/devuser/.kube/config

BASE_SERVICES="movie cinema user"

for svc in $BASE_SERVICES; do
  echo ""
  echo "=========================================="
  echo "  Deploying: $svc"
  echo "=========================================="
  
  # Renderizar manifiestos
  task k8s:render SERVICE=$svc ENV=dev VERSION=v1.0.0
  
  # Aplicar al cluster
  task k8s:apply SERVICE=$svc ENV=dev
  
  echo ""
  echo "Waiting for $svc to be ready..."
  kubectl wait --namespace cinema-dev \
    --for=condition=available deployment/$svc \
    --timeout=120s || echo "⚠️  Warning: $svc not ready yet"
done
```

**Respuesta esperada para cada servicio:**
```
==========================================
  Deploying: movie
==========================================
=== Rendering manifests for movie (dev) ===
...
Rendered: .../movie/deployment.yaml
...

Applying configmap.yaml...
configmap/movie-config created
Applying secret.yaml...
secret/movie-secrets created
Applying service.yaml...
service/movie created
...

Waiting for movie to be ready...
deployment.apps/movie condition met
```

```bash
# Verificar estado
kubectl get pods -n cinema-dev -l app.kubernetes.io/name=movie
kubectl get pods -n cinema-dev -l app.kubernetes.io/name=cinema
kubectl get pods -n cinema-dev -l app.kubernetes.io/name=user
```

**Respuesta esperada:**
```
NAME                     READY   STATUS    RESTARTS   AGE
movie-xxxxxxxxx-xxxxx    1/1     Running   0          60s
cinema-xxxxxxxxx-xxxxx   1/1     Running   0          45s
user-xxxxxxxxx-xxxxx     1/1     Running   0          30s
```

**Si STATUS es ImagePullBackOff:**
- La imagen no existe en el registry
- Verifica: `kubectl describe pod -n cinema-dev -l app.kubernetes.io/name=movie`
- Solución: Construir y pushear la imagen primero con `task build:push SERVICE=movie`

**Si STATUS es CrashLoopBackOff:**
- El contenedor está fallando al iniciar
- Verifica logs: `kubectl logs -n cinema-dev -l app.kubernetes.io/name=movie`
- Causas comunes: MongoDB no accesible, variables de entorno faltantes

---

### 3.2 Desplegar Servicios Intermedios

**Objetivo:** Desplegar servicios que dependen de los servicios base.

**Por qué es importante:** `showtime` necesita `movie` y `cinema` para validar datos. `seat` necesita `showtime` para verificar funciones disponibles.

```bash
INTERMEDIATE_SERVICES="showtime seat payment notification"

for svc in $INTERMEDIATE_SERVICES; do
  echo ""
  echo "=========================================="
  echo "  Deploying: $svc"
  echo "=========================================="
  
  task k8s:render SERVICE=$svc ENV=dev VERSION=v1.0.0
  task k8s:apply SERVICE=$svc ENV=dev
  
  echo ""
  echo "Waiting for $svc to be ready..."
  kubectl wait --namespace cinema-dev \
    --for=condition=available deployment/$svc \
    --timeout=120s || echo "⚠️  Warning: $svc not ready yet"
done
```

**Respuesta esperada:**
```
==========================================
  Deploying: showtime
==========================================
...
deployment.apps/showtime condition met

==========================================
  Deploying: seat
==========================================
...
deployment.apps/seat condition met

(similar para payment y notification)
```

```bash
# Verificar todos los pods hasta ahora
kubectl get pods -n cinema-dev
```

**Respuesta esperada:**
```
NAME                            READY   STATUS    RESTARTS   AGE
mongodb-xxxxxxxxx-xxxxx         1/1     Running   0          10m
movie-xxxxxxxxx-xxxxx           1/1     Running   0          5m
cinema-xxxxxxxxx-xxxxx          1/1     Running   0          4m
user-xxxxxxxxx-xxxxx            1/1     Running   0          4m
showtime-xxxxxxxxx-xxxxx        1/1     Running   0          3m
seat-xxxxxxxxx-xxxxx            1/1     Running   0          2m
payment-xxxxxxxxx-xxxxx         1/1     Running   0          1m
notification-xxxxxxxxx-xxxxx    1/1     Running   0          1m
```

---

### 3.3 Desplegar Booking (Orquestador SAGA)

**Objetivo:** Desplegar el servicio principal que orquesta el proceso de reserva.

**Por qué es importante:** Booking implementa el patrón SAGA para coordinar transacciones distribuidas:
1. Reserva asientos (seat-service)
2. Procesa pago (payment-service)
3. Confirma reserva
4. Envía notificación (notification-service)

Si algún paso falla, ejecuta compensaciones (rollback).

```bash
echo "=========================================="
echo "  Deploying: booking (SAGA Orchestrator)"
echo "=========================================="

task k8s:render SERVICE=booking ENV=dev VERSION=v1.0.0
task k8s:apply SERVICE=booking ENV=dev

echo ""
echo "Waiting for booking to be ready..."
kubectl wait --namespace cinema-dev \
  --for=condition=available deployment/booking \
  --timeout=120s
```

**Respuesta esperada:**
```
==========================================
  Deploying: booking (SAGA Orchestrator)
==========================================
=== Rendering manifests for booking (dev) ===
...
deployment.apps/booking condition met
```

---

### 3.4 Verificar Despliegue Completo

**Objetivo:** Confirmar que todos los microservicios están running correctamente.

**Por qué es importante:** Un solo servicio en estado incorrecto puede causar fallos en cascada debido a las dependencias.

```bash
echo "=== Deployments ==="
kubectl get deployments -n cinema-dev

echo ""
echo "=== Pods ==="
kubectl get pods -n cinema-dev

echo ""
echo "=== Services ==="
kubectl get svc -n cinema-dev
```

**Respuesta esperada:**
```
=== Deployments ===
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
mongodb        1/1     1            1           15m
movie          1/1     1            1           10m
cinema         1/1     1            1           9m
user           1/1     1            1           8m
showtime       1/1     1            1           7m
seat           1/1     1            1           6m
payment        1/1     1            1           5m
notification   1/1     1            1           4m
booking        1/1     1            1           2m

=== Pods ===
NAME                            READY   STATUS    RESTARTS   AGE
mongodb-xxx                     1/1     Running   0          15m
movie-xxx                       1/1     Running   0          10m
cinema-xxx                      1/1     Running   0          9m
user-xxx                        1/1     Running   0          8m
showtime-xxx                    1/1     Running   0          7m
seat-xxx                        1/1     Running   0          6m
payment-xxx                     1/1     Running   0          5m
notification-xxx                1/1     Running   0          4m
booking-xxx                     1/1     Running   0          2m

=== Services ===
NAME           TYPE        CLUSTER-IP       PORT(S)
mongodb        ClusterIP   34.118.xxx.xxx   27017/TCP
movie          ClusterIP   34.118.xxx.xxx   80/TCP
cinema         ClusterIP   34.118.xxx.xxx   80/TCP
user           ClusterIP   34.118.xxx.xxx   80/TCP
showtime       ClusterIP   34.118.xxx.xxx   80/TCP
seat           ClusterIP   34.118.xxx.xxx   80/TCP
payment        ClusterIP   34.118.xxx.xxx   80/TCP
notification   ClusterIP   34.118.xxx.xxx   80/TCP
booking        ClusterIP   34.118.xxx.xxx   80/TCP
```

**Checklist de validación:**
- [ ] Todos los deployments muestran `1/1` en READY
- [ ] Todos los pods están en `Running`
- [ ] Todos los pods muestran `1/1` en READY
- [ ] `RESTARTS` es 0 (o bajo)
- [ ] Todos los services tienen `CLUSTER-IP` asignado

---

## Fase 4: Validación del Despliegue

### 4.1 Health Checks

**Objetivo:** Verificar que cada servicio responde correctamente a sus endpoints de salud.

**Por qué es importante:** Un pod en `Running` no garantiza que la aplicación funcione. Los health checks confirman que:
- La aplicación inició correctamente
- Puede conectarse a sus dependencias (MongoDB)
- Está lista para recibir tráfico

```bash
SERVICES="booking movie cinema user seat showtime payment notification"

for svc in $SERVICES; do
  echo "=== Health Check: $svc ==="
  
  # Intentar con wget (Alpine-based images)
  kubectl exec -n cinema-dev deploy/$svc -- \
    wget -qO- --timeout=5 http://localhost:${PORT:-8080}/health/ready 2>/dev/null || \
  
  # Fallback: curl
  kubectl exec -n cinema-dev deploy/$svc -- \
    curl -sf --max-time 5 http://localhost:${PORT:-8080}/health/ready 2>/dev/null || \
  
  echo "❌ Health endpoint not responding"
  echo ""
done
```

**Respuesta esperada:**
```
=== Health Check: booking ===
{"status":"healthy","service":"booking","dependencies":{"mongodb":"connected"}}

=== Health Check: movie ===
{"status":"healthy","service":"movie","dependencies":{"mongodb":"connected"}}
...
```

**Si falla:**
- Verifica logs: `kubectl logs -n cinema-dev deploy/$svc`
- Verifica que el puerto es correcto (puede variar por servicio)
- Verifica conexión a MongoDB desde el pod

---

### 4.2 Port Forward para Testing Local

**Objetivo:** Exponer los servicios del cluster a tu máquina local para pruebas.

**Por qué es importante:** Los services con `ClusterIP` solo son accesibles dentro del cluster. Port-forward crea un túnel temporal para testing.

```bash
# Crear túneles (ejecutar en terminales separadas o con &)
kubectl port-forward -n cinema-dev svc/booking 8001:80 &
kubectl port-forward -n cinema-dev svc/movie 8002:80 &
kubectl port-forward -n cinema-dev svc/cinema 8003:80 &

echo ""
echo "Services disponibles en:"
echo "  Booking:  http://localhost:8001"
echo "  Movie:    http://localhost:8002"
echo "  Cinema:   http://localhost:8003"
```

**Respuesta esperada:**
```
Forwarding from 127.0.0.1:8001 -> 8001
Forwarding from 127.0.0.1:8002 -> 8002
Forwarding from 127.0.0.1:8003 -> 8003
```

**Para detener port-forward:**
```bash
# Listar procesos de port-forward
jobs

# Matar todos
kill $(jobs -p)
```

---

### 4.3 Test de Conectividad entre Servicios

**Objetivo:** Verificar que los servicios pueden comunicarse entre sí dentro del cluster.

**Por qué es importante:** Cada servicio se conecta a otros via DNS interno de Kubernetes (`http://service-name/`). Si la resolución DNS falla, el servicio no puede funcionar.

```bash
# Desde el pod de booking, verificar conectividad a otros servicios
echo "=== Test desde booking hacia otros servicios ==="

kubectl exec -n cinema-dev deploy/booking -- \
  wget -qO- --timeout=5 http://movie/health/ready && echo "✅ movie: OK" || echo "❌ movie: FAIL"

kubectl exec -n cinema-dev deploy/booking -- \
  wget -qO- --timeout=5 http://payment/health/ready && echo "✅ payment: OK" || echo "❌ payment: FAIL"

kubectl exec -n cinema-dev deploy/booking -- \
  wget -qO- --timeout=5 http://seat/health/ready && echo "✅ seat: OK" || echo "❌ seat: FAIL"

kubectl exec -n cinema-dev deploy/booking -- \
  wget -qO- --timeout=5 http://notification/health/ready && echo "✅ notification: OK" || echo "❌ notification: FAIL"
```

**Respuesta esperada:**
```
=== Test desde booking hacia otros servicios ===
{"status":"healthy"...}
✅ movie: OK
{"status":"healthy"...}
✅ payment: OK
{"status":"healthy"...}
✅ seat: OK
{"status":"healthy"...}
✅ notification: OK
```

**Si falla:**
```bash
# Verificar que el servicio existe
kubectl get svc -n cinema-dev

# Verificar resolución DNS
kubectl exec -n cinema-dev deploy/booking -- nslookup movie

# Verificar que hay endpoints
kubectl get endpoints -n cinema-dev
```

---

### 4.4 Test de APIs

**Objetivo:** Verificar que las APIs responden correctamente con datos.

**Por qué es importante:** Esto confirma el flujo completo: API → Service → MongoDB → Response.

```bash
# Prerequisito: tener port-forward activo
# kubectl port-forward -n cinema-dev svc/movie 8002:80 &

# Test endpoint de movies
echo "=== GET /api/movies ==="
curl -s http://localhost:8002/api/movies | head -20

echo ""
echo "=== GET /api/cinemas ==="
curl -s http://localhost:8003/api/cinemas | head -20

echo ""
echo "=== GET /health/ready (booking) ==="
curl -s http://localhost:8001/health/ready
```

**Respuesta esperada (con datos de seed):**
```
=== GET /api/movies ===
[
  {
    "id": "mov_shawshank",
    "title": "The Shawshank Redemption",
    "director": "Frank Darabont",
    "duration": 142
  },
  {
    "id": "mov_inception",
    "title": "Inception",
    "director": "Christopher Nolan",
    "duration": 148
  }
]

=== GET /api/cinemas ===
[
  {
    "id": "507f1f77bcf86cd799439022",
    "name": "Cinema Downtown",
    "city": "Test City"
  }
]

=== GET /health/ready (booking) ===
{"status":"healthy","service":"booking"}
```

**Si responde vacío `[]`:**
- Verifica que el Job mongodb-init completó: `kubectl get jobs -n mongodb`
- Re-ejecuta el seed: `kubectl delete job mongodb-init -n mongodb && kubectl apply -f rendered/infrastructure/mongodb.yaml`
- Verifica logs: `kubectl logs -n mongodb job/mongodb-init`

---

### 4.5 Verificar Logs

**Objetivo:** Revisar los logs de los servicios para detectar errores o warnings.

**Por qué es importante:** Los logs revelan problemas que no son visibles en el estado del pod, como errores de lógica de negocio o conexiones lentas.

```bash
# Ver logs de un servicio específico (últimas 50 líneas)
kubectl logs -n cinema-dev deploy/booking --tail=50
```

**Respuesta esperada (healthy):**
```
time="2024-04-17T10:30:00Z" level=info msg="--- Booking Service ---"
time="2024-04-17T10:30:01Z" level=info msg="Connected to Booking Service DB"
time="2024-04-17T10:30:01Z" level=info msg="Initializing API Repository Configuration"
time="2024-04-17T10:30:02Z" level=info msg="Server started on port 8001"
```

**Respuesta con problemas:**
```
time="2024-04-17T10:30:00Z" level=error msg="Failed to connect to MongoDB: connection refused"
time="2024-04-17T10:30:05Z" level=error msg="Retrying connection..."
```

```bash
# Ver logs de todos los servicios (últimas 10 líneas cada uno)
for svc in booking movie cinema user seat showtime payment notification; do
  echo ""
  echo "=== Logs: $svc ===" 
  kubectl logs -n cinema-dev deploy/$svc --tail=10
done
```

```bash
# Stream de logs en tiempo real (Ctrl+C para salir)
kubectl logs -n cinema-dev -l app.kubernetes.io/environment=dev -f --max-log-requests=10
```

---

## Fase 5: Troubleshooting

### 5.1 Pod no inicia (Pending)

**Objetivo:** Diagnosticar por qué un pod está atascado en estado "Pending".

**Por qué ocurre:** El scheduler de Kubernetes no puede encontrar un nodo adecuado para el pod.

```bash
# Ver el estado del pod
kubectl get pods -n cinema-dev

# Ver detalles y eventos
kubectl describe pod -n cinema-dev -l app.kubernetes.io/name=booking
```

**Buscar en la sección "Events":**

| Mensaje | Causa | Solución |
|---------|-------|----------|
| `Insufficient cpu` | No hay CPU disponible | Reducir `resources.requests.cpu` o agregar nodos |
| `Insufficient memory` | No hay memoria disponible | Reducir `resources.requests.memory` o agregar nodos |
| `FailedScheduling` | No hay nodos que cumplan requisitos | Verificar nodeSelector, tolerations |
| `PersistentVolumeClaim not found` | PVC no existe | Crear el PVC primero |
| `node(s) had untolerated taint` | Pod no tolera el taint del nodo | Agregar toleration en el pod |
| `node(s) didn't match Pod's node selector` | nodeSelector no coincide con labels | Verificar label del nodo |

```bash
# Ver recursos disponibles en los nodos
kubectl describe nodes | grep -A 10 "Allocated resources"
```

---

### 5.6 Pod Pending por Taint/NodeSelector (SE LATAM Node)

**Objetivo:** Resolver problemas de scheduling cuando los pods no se despliegan en el nodo dedicado.

**Por qué ocurre:** El nodo SE LATAM tiene un taint `NoSchedule` que repele pods sin la tolerancia correcta.

```bash
# Ver si el pod está Pending
kubectl get pods -n cinema-dev

# Ver eventos del pod
kubectl describe pod -n cinema-dev -l app.kubernetes.io/name=booking | grep -A 10 "Events:"
```

**Error típico:**
```
Events:
  Warning  FailedScheduling  0/6 nodes are available: 1 node(s) had untolerated taint 
  {dedicated: selatam_demo_space}, 5 node(s) didn't match Pod's node affinity/selector.
```

**Diagnóstico:**

```bash
# 1. Verificar que el nodo existe y está Ready
kubectl get nodes -l owner=cristian-ramirez

# 2. Ver taints del nodo
kubectl describe node -l owner=cristian-ramirez | grep -A 2 "Taints:"

# 3. Ver si el pod tiene la configuración correcta
kubectl get pod -n cinema-dev -l app.kubernetes.io/name=booking -o yaml | grep -A 10 "tolerations:"
kubectl get pod -n cinema-dev -l app.kubernetes.io/name=booking -o yaml | grep -A 3 "nodeSelector:"
```

**Configuración correcta en el deployment (generada por Go templates):**
```yaml
spec:
  template:
    spec:
      nodeSelector:
        owner: cristian-ramirez           # ← Label del nodo (values/base.yaml)
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "selatam_demo_space"     # ← Valor del taint (values/base.yaml)
          effect: "NoSchedule"
```

**Solución si falta la configuración:**

1. Verificar que `values/base.yaml` tiene los valores correctos:
```yaml
# Node placement (SE LATAM dedicated node)
nodeOwner: cristian-ramirez
nodeTaintValue: selatam_demo_space
```

2. Verificar que el template `templates/deployment.yaml` usa los valores:
```yaml
      nodeSelector:
        owner: {{ .Values.nodeOwner }}
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: {{ quote .Values.nodeTaintValue }}
          effect: "NoSchedule"
```

3. Re-renderizar y re-aplicar:
```bash
task k8s:render SERVICE=booking ENV=dev VERSION=v1.0.0
task k8s:apply SERVICE=booking ENV=dev
```

4. Verificar el deployment generado:
```bash
grep -A8 "nodeSelector" platform/deploy/kubernetes/rendered/dev/booking/deployment.yaml
```

**Respuesta esperada:**
```yaml
      nodeSelector:
        owner: cristian-ramirez
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "selatam_demo_space"
          effect: "NoSchedule"
```

---

### 5.2 Pod en CrashLoopBackOff

**Objetivo:** Diagnosticar por qué un pod se reinicia constantemente.

**Por qué ocurre:** El contenedor inicia pero falla inmediatamente, causando un ciclo de reinicios.

```bash
# Ver logs del contenedor actual
kubectl logs -n cinema-dev -l app.kubernetes.io/name=booking

# Ver logs del contenedor anterior (antes del último restart)
kubectl logs -n cinema-dev -l app.kubernetes.io/name=booking --previous

# Ver detalles del pod
kubectl describe pod -n cinema-dev -l app.kubernetes.io/name=booking
```

**Causas comunes y soluciones:**

| Error en logs | Causa | Solución |
|---------------|-------|----------|
| `connection refused` | No puede conectar a MongoDB | Verificar que MongoDB está running |
| `ECONNREFUSED` | Servicio dependiente no existe | Desplegar dependencias primero |
| `permission denied` | Permisos de archivo | Verificar securityContext |
| `exec format error` | Imagen para arquitectura incorrecta | Reconstruir imagen para la arquitectura correcta |
| `OOMKilled` | Se quedó sin memoria | Aumentar `resources.limits.memory` |

---

### 5.3 Pod en ImagePullBackOff

**Objetivo:** Diagnosticar por qué Kubernetes no puede descargar la imagen del contenedor.

**Por qué ocurre:** El container registry no es accesible o la imagen no existe.

```bash
# Ver detalles del error
kubectl describe pod -n cinema-dev -l app.kubernetes.io/name=booking | grep -A 5 "Events"
```

**Causas comunes:**

| Error | Causa | Solución |
|-------|-------|----------|
| `ImagePullBackOff` | Imagen no existe | Verificar nombre y tag: `docker pull IMAGE:TAG` |
| `ErrImagePull` | Registry no accesible | Verificar credenciales del registry |
| `unauthorized` | Sin permisos | Crear imagePullSecret |

```bash
# Verificar que la imagen existe
docker pull crizstian/booking-service:v1.0.0

# Si necesitas credenciales privadas
kubectl create secret docker-registry regcred \
  --docker-server=REGISTRY_URL \
  --docker-username=USERNAME \
  --docker-password=PASSWORD \
  -n cinema-dev
```

---

### 5.4 Servicio no responde

**Objetivo:** Diagnosticar por qué un servicio no responde a requests.

**Por qué ocurre:** El service no tiene endpoints, o el pod no está escuchando en el puerto correcto.

```bash
# Verificar que el service tiene endpoints
kubectl get endpoints -n cinema-dev

# Ver detalles del service
kubectl describe svc booking -n cinema-dev
```

**Respuesta esperada:**
```
Name:              booking
Endpoints:         10.244.0.15:8001    # ← Debe tener IPs
```

**Si "Endpoints" está vacío:**
- El selector del service no coincide con los labels del pod
- No hay pods en estado Ready

```bash
# Verificar labels del pod
kubectl get pods -n cinema-dev --show-labels

# Verificar selector del service
kubectl get svc booking -n cinema-dev -o yaml | grep -A 5 "selector"

# Test desde dentro del cluster
kubectl run debug --rm -it --restart=Never --image=busybox -n cinema-dev -- \
  wget -qO- --timeout=5 http://booking/health/ready
```

---

### 5.5 Rollback de un Servicio

**Objetivo:** Revertir un despliegue problemático a una versión anterior.

**Por qué es importante:** Si una nueva versión introduce bugs, puedes rápidamente volver a la versión estable.

```bash
# Ver historial de revisiones
kubectl rollout history deployment/booking -n cinema-dev
```

**Respuesta esperada:**
```
deployment.apps/booking 
REVISION  CHANGE-CAUSE
1         Deploy booking v1.0.0
2         Deploy booking v1.0.1
3         Deploy booking v1.1.0    ← actual (con bugs)
```

```bash
# Rollback a la revisión anterior
kubectl rollout undo deployment/booking -n cinema-dev

# O rollback a una revisión específica
kubectl rollout undo deployment/booking -n cinema-dev --to-revision=1

# Verificar estado del rollback
kubectl rollout status deployment/booking -n cinema-dev
```

**Respuesta esperada:**
```
deployment.apps/booking rolled back
deployment "booking" successfully rolled out
```

---

## Fase 6: Cleanup

### 6.1 Eliminar un Servicio

**Objetivo:** Eliminar un servicio específico sin afectar a los demás.

**Por qué es importante:** Útil para redeploys limpios o cuando un servicio ya no es necesario.

```bash
task k8s:delete SERVICE=booking ENV=dev
```

**O manualmente:**
```bash
kubectl delete deployment booking -n cinema-dev
kubectl delete service booking -n cinema-dev
kubectl delete configmap booking-config -n cinema-dev
kubectl delete secret booking-secrets -n cinema-dev
kubectl delete hpa booking -n cinema-dev
kubectl delete pdb booking -n cinema-dev
```

---

### 6.2 Eliminar Todos los Servicios

**Objetivo:** Limpiar completamente el namespace de aplicación.

**Por qué es importante:** Útil para empezar de cero o liberar recursos del cluster.

```bash
# Eliminar todo el namespace (incluye todos los recursos dentro)
kubectl delete namespace cinema-dev
```

**Respuesta esperada:**
```
namespace "cinema-dev" deleted
```

**Nota:** Este comando elimina TODOS los recursos del namespace, incluyendo MongoDB y los datos.

---

### 6.3 Eliminar Solo Microservicios (mantener infra)

**Objetivo:** Eliminar solo los microservicios pero mantener MongoDB.

```bash
SERVICES="booking movie cinema user seat showtime payment notification"

for svc in $SERVICES; do
  echo "Deleting $svc..."
  kubectl delete deployment $svc -n cinema-dev --ignore-not-found
  kubectl delete service $svc -n cinema-dev --ignore-not-found
  kubectl delete configmap ${svc}-config -n cinema-dev --ignore-not-found
  kubectl delete secret ${svc}-secrets -n cinema-dev --ignore-not-found
done

echo "Done. MongoDB preserved."
```

---

## Quick Reference

### Comandos Frecuentes

```bash
# === KUBECONFIG (siempre primero) ===
export KUBECONFIG=/home/devuser/.kube/config

# === RENDER (Go templating) ===
task k8s:render SERVICE=booking ENV=dev VERSION=v1.0.0      # Un servicio
task k8s:render:all ENV=dev VERSION=v1.0.0                  # Todos los servicios
task k8s:infra:render                                        # Toda la infraestructura
task k8s:infra:render COMPONENT=mongodb                     # Solo MongoDB

# === DEPLOY ===
task k8s:apply SERVICE=booking ENV=dev
task k8s:deploy SERVICE=booking ENV=dev VERSION=v1.0.0      # render + apply

# === INFRAESTRUCTURA ===
kubectl apply -f platform/deploy/kubernetes/rendered/infrastructure/mongodb.yaml
kubectl apply -f platform/deploy/kubernetes/rendered/infrastructure/ingress-nginx.yaml

# === ESTADO ===
kubectl get pods -n cinema-dev
kubectl get svc -n cinema-dev
kubectl get deployments -n cinema-dev

# === VERIFICAR NODE SCHEDULING ===
kubectl get pods -n cinema-dev -o wide                      # Ver en qué nodo están
kubectl get nodes -l owner=cristian-ramirez                 # Ver nodo SE LATAM

# === LOGS ===
kubectl logs -n cinema-dev deploy/booking --tail=50
kubectl logs -n cinema-dev deploy/booking -f                # stream

# === DEBUG ===
kubectl describe pod -n cinema-dev -l app.kubernetes.io/name=booking
kubectl exec -n cinema-dev deploy/booking -- sh

# === PORT FORWARD ===
kubectl port-forward -n cinema-dev svc/booking 8001:80

# === ESCALAR ===
kubectl scale deployment booking -n cinema-dev --replicas=3

# === ROLLBACK ===
kubectl rollout undo deployment/booking -n cinema-dev
```

### Orden de Despliegue

```
┌─────────────────────────────────────────────────────────┐
│  FASE 1: INFRAESTRUCTURA                                │
│  ┌─────────────┐  ┌─────────────┐                      │
│  │  namespace  │→ │  MongoDB    │                      │
│  └─────────────┘  └─────────────┘                      │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 2: SERVICIOS BASE (sin dependencias)              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │    movie    │  │   cinema    │  │    user     │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 3: SERVICIOS INTERMEDIOS                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ │
│  │ showtime │ │   seat   │ │ payment  │ │notification│ │
│  └──────────┘ └──────────┘ └──────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  FASE 4: ORQUESTADOR                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │              booking (SAGA)                      │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### URLs de Acceso (con port-forward)

| Servicio | Comando | URL Local |
|----------|---------|-----------|
| booking | `kubectl port-forward -n cinema-dev svc/booking 8001:80` | http://localhost:8001 |
| movie | `kubectl port-forward -n cinema-dev svc/movie 8002:80` | http://localhost:8002 |
| cinema | `kubectl port-forward -n cinema-dev svc/cinema 8003:80` | http://localhost:8003 |
| user | `kubectl port-forward -n cinema-dev svc/user 8004:80` | http://localhost:8004 |
| seat | `kubectl port-forward -n cinema-dev svc/seat 3003:80` | http://localhost:3003 |
| showtime | `kubectl port-forward -n cinema-dev svc/showtime 3004:80` | http://localhost:3004 |
| payment | `kubectl port-forward -n cinema-dev svc/payment 8082:80` | http://localhost:8082 |
| notification | `kubectl port-forward -n cinema-dev svc/notification 8085:80` | http://localhost:8085 |

### Checklist de Despliegue

**Prerequisitos:**
- [ ] `kubectl` instalado y configurado
- [ ] Contexto apuntando al cluster correcto (`gke_sales-209522_us-east1-b_se-sandbox`)
- [ ] Nodo SE LATAM disponible (`kubectl get nodes -l owner=cristian-ramirez`)
- [ ] Go renderer compilado (`platform/deploy/kubernetes/bin/render`)

**Rendering:**
- [ ] `values/base.yaml` con `nodeOwner` y `nodeTaintValue` correctos
- [ ] Infraestructura renderizada (`task k8s:infra:render`)
- [ ] Servicios renderizados (`task k8s:render:all ENV=dev VERSION=v1.0.0`)
- [ ] Manifiestos validados (`kubectl apply --dry-run=client -f ...`)

**Infraestructura:**
- [ ] Namespace `cinema-dev` creado
- [ ] MongoDB running y accesible (en nodo SE LATAM)

**Microservicios:**
- [ ] Servicios base desplegados (movie, cinema, user)
- [ ] Servicios intermedios desplegados (showtime, seat, payment, notification)
- [ ] Booking desplegado (SAGA orchestrator)
- [ ] Todos los pods en nodo SE LATAM (`kubectl get pods -o wide`)

**Validación:**
- [ ] Health checks pasando
- [ ] Conectividad entre servicios OK
- [ ] APIs respondiendo correctamente

### Estructura del Proyecto K8s

```
platform/deploy/kubernetes/
├── bin/
│   └── render                    # Binario Go compilado
├── cmd/render/
│   ├── main.go                   # Código fuente del renderer
│   └── go.mod
├── templates/
│   ├── services/                 # Templates de microservicios
│   │   ├── deployment.yaml       # {{ .Values.* }} syntax
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml
│   │   ├── hpa.yaml
│   │   ├── pdb.yaml
│   │   └── networkpolicy.yaml
│   └── infrastructure/           # Templates de infra
│       ├── mongodb.yaml          # StatefulSet + credentials
│       └── ingress-nginx.yaml    # Ingress controller
├── values/
│   ├── base.yaml                 # Defaults globales (nodeSelector, tolerations)
│   ├── infrastructure.yaml       # Config de MongoDB, Ingress
│   ├── environments/
│   │   ├── dev.yaml              # Entorno desarrollo
│   │   ├── staging.yaml          # Pre-producción
│   │   └── prod.yaml             # Producción
│   └── services/
│       ├── booking.yaml          # Port, DB, recursos por servicio
│       ├── movie.yaml
│       ├── cinema.yaml
│       ├── user.yaml
│       ├── seat.yaml
│       ├── showtime.yaml
│       ├── payment.yaml
│       └── notification.yaml
├── rendered/                     # Output generado (gitignored)
│   ├── infrastructure/
│   │   ├── mongodb.yaml
│   │   └── ingress-nginx.yaml
│   └── dev/
│       ├── booking/
│       ├── movie/
│       └── ... (8 servicios)
└── scripts/
    ├── render.sh                 # Renderizar un servicio
    ├── render-all.sh             # Renderizar todos los servicios
    └── render-infra.sh           # Renderizar infraestructura
```

### Flujo de Valores (Merge Order)

```
┌─────────────────────────────────────────────────────────────┐
│  1. values/base.yaml                                        │
│     └─ nodeOwner, nodeTaintValue, image.registry, etc.      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. values/environments/{env}.yaml                          │
│     └─ namespace, database, replicas, resources (override)  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. values/services/{service}.yaml                          │
│     └─ port, dbName, dependencies (service-specific)        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. CLI flags: -version, -service (injected at render)      │
│     └─ version, serviceName                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Fase 7: CD Pipeline y Validación

### 7.1 Tareas de CD en Taskfile

El Taskfile incluye tareas que replican el flujo de Harness CD para validación local:

```bash
# Flujo completo de CD (validate → render → deploy → smoke)
task cd:pipeline SERVICE=movie ENV=dev VERSION=v0.0.3

# O ejecutar cada paso individualmente:
task cd:validate SERVICE=movie ENV=dev      # Pre-deploy validation
task cd:render SERVICE=movie ENV=dev VERSION=v0.0.3  # Render templates
task cd:deploy SERVICE=movie ENV=dev        # Apply to cluster
task cd:smoke SERVICE=movie ENV=dev PORT=8002  # Health checks
task cd:rollback SERVICE=movie ENV=dev      # Rollback if needed
```

### 7.2 Validación Pre-Deploy

El script `validate-values.sh` verifica la configuración antes de renderizar:

```bash
./scripts/validate-values.sh movie dev
```

**Validaciones incluidas:**
- `database.replica` - Requerido para staging/prod; opcional en dev (vacío = standalone MongoDB)
- `database.servers` está configurado
- `database.user` y `database.password` (requeridos en staging/prod, opcionales en dev para no-auth mode)
- `port` está en rango válido (1024-65535)
- `namespace` coincide con el entorno (`cinema-{env}`)

**Respuesta esperada:**
```
=== Validating values for movie (dev) ===
Merging values from:
  1. values/base.yaml
  2. values/environments/dev.yaml
  3. values/services/movie.yaml

=== Running basic validation ===
INFO: database.replica is empty (standalone MongoDB for dev)
OK: database.servers = mongodb.cinema-dev.svc.cluster.local:27017
OK: database.user = [REDACTED]
OK: database.password = [REDACTED]
OK: port = 8002
OK: namespace = cinema-dev

=== Validation Summary ===
PASSED: All validations passed
```

### 7.3 MongoDB con Autenticación

A partir de v0.0.3, MongoDB soporta dos modos de autenticación:

#### Modo Standalone (Dev)

Para desarrollo, MongoDB se despliega sin replica set, simplificando la configuración:

**Credenciales en `values/infrastructure.yaml`:**
```yaml
mongodb:
  rootUser: cinema_admin
  rootPassword: n8XGsZ15Z4OzTqpAXsCAs8CA  # CAMBIAR EN PRODUCCIÓN
  appUser: cinema
  appPassword: cinema123  # CAMBIAR EN PRODUCCIÓN
```

**Configuración en `values/environments/dev.yaml`:**
```yaml
database:
  servers: mongodb.cinema-dev.svc.cluster.local:27017
  replica: ""  # Vacío = standalone mode (sin replica set)
  user: cinema
  password: cinema123
```

**ConfigMap generado incluye:**
```yaml
DB_SERVERS: mongodb.cinema-dev.svc.cluster.local:27017
DB_REPLICA: ""
DB_USER: cinema
DB_PASS: cinema123
```

**Verificar conexión (standalone):**
```bash
kubectl run mongo-test --rm -it --restart=Never \
  --image=mongo:8.0 -n cinema-dev -- \
  mongosh "mongodb://cinema:cinema123@mongodb:27017/movie?authSource=admin" \
  --eval "db.adminCommand('ping')"
```

#### Modo Replica Set (Staging/Prod)

Para staging y producción, MongoDB usa replica set para alta disponibilidad:

```yaml
# values/environments/staging.yaml
database:
  servers: mongodb-0.mongodb,mongodb-1.mongodb,mongodb-2.mongodb
  replica: rs0  # Nombre del replica set
  user: cinema
  password: ${MONGO_APP_PASSWORD}  # Desde secret
```

**Verificar conexión (replica set):**
```bash
kubectl run mongo-test --rm -it --restart=Never \
  --image=mongo:8.0 -n cinema-staging -- \
  mongosh "mongodb://cinema:pass@mongodb:27017/movie?authSource=admin&replicaSet=rs0" \
  --eval "rs.status()"
```

### 7.4 Health Endpoints

Todos los servicios exponen endpoints de salud compatibles con Kubernetes:

| Endpoint | Propósito | Kubernetes Probe |
|----------|-----------|------------------|
| `/health/live` | Liveness check | `livenessProbe` |
| `/health/ready` | Readiness check | `readinessProbe` |
| `/ping` | Legacy health check | - |

**Verificar health desde dentro del cluster:**
```bash
kubectl exec -n cinema-dev deploy/movie -- \
  wget -qO- http://localhost:8002/health/ready
```

**Respuesta esperada:**
```
pong
```

### 7.5 OPA Policies

Las políticas OPA validan configuración antes del deploy en Harness:

| Policy | Archivo | Validaciones |
|--------|---------|--------------|
| ConfigMap Validation | `policies/configmap-validation.rego` | DB_REPLICA, credentials, port, namespace |
| Deployment Validation | `policies/deployment-validation.rego` | Probes, resources, image tags |

**Testing local de policies:**
```bash
# Instalar OPA
brew install opa  # macOS

# Validar values
yq eval-all 'select(fi==0)*select(fi==1)*select(fi==2)' \
  values/base.yaml values/environments/dev.yaml values/services/movie.yaml \
  | yq -o=json > /tmp/values.json

opa eval -i /tmp/values.json \
  -d policies/configmap-validation.rego \
  "data.kubernetes.configmap.deny"
```

**Configurar en Harness UI:**
1. Navegar a **Project Settings** → **Governance** → **Policies**
2. Crear policy con contenido de `configmap-validation.rego`
3. Crear Policy Set con Entity Type: `Pipeline`, Event: `On Run`

### 7.6 Pipeline Harness CD

El pipeline `CD_Kubernetes` incluye el flujo completo:

```
┌─────────────────────────────────────────────────────────────┐
│  Step 1: Validate Values                                    │
│  └─ ./scripts/validate-values.sh <service> dev              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 2: Render Templates                                   │
│  └─ ./scripts/render.sh <service> dev <version>             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 3: K8sRollingDeploy                                   │
│  └─ Harness native deployment step                          │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 4: Smoke Test - Liveness                              │
│  └─ HTTP GET /health/live → expect 200                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Step 5: Smoke Test - Readiness                             │
│  └─ HTTP GET /health/ready → expect 200                     │
└─────────────────────────────────────────────────────────────┘
```

**Pipeline YAML:** `.harness/pipelines/CD/CD-Kubernetes-updated.yaml`

---

## Versiones

### v0.0.3 (Actual)

**Cambios:**
- **MongoDB standalone mode** para dev (sin replica set, simplifica configuración)
- **MongoDB con autenticación** via user/password (DB_USER, DB_PASS en configmap)
- **DB_REPLICA opcional** - vacío para standalone, configurado para replica set
- Health endpoints `/health/live` y `/health/ready` en todos los servicios
- Script de validación pre-deploy (`validate-values.sh`) actualizado para soportar standalone
- ConfigMap incluye DB_USER y DB_PASS para autenticación
- Pipeline CD actualizado con smoke tests HTTP
- Servicios Go actualizados para manejar DB_REPLICA opcional

**ConfigMap generado (ejemplo movie):**
```yaml
DB_SERVERS: mongodb.cinema-dev.svc.cluster.local:27017
DB_REPLICA: ""  # Vacío para standalone
DB_USER: cinema
DB_PASS: cinema123
DB_NAME: movie
```

**Imágenes Docker (linux/amd64):**
```
crizstian/booking-service:v0.0.3
crizstian/movie-service:v0.0.3
crizstian/cinema-service:v0.0.3
crizstian/user-service:v0.0.3
crizstian/seat-service:v0.0.3
crizstian/showtime-service:v0.0.3
crizstian/payment-service:v0.0.3
crizstian/notification-service:v0.0.3
```
