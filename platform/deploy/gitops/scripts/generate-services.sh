#!/bin/bash
# Generate Kustomize manifests for all cinema services
# Usage: ./generate-services.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITOPS_DIR="$(dirname "$SCRIPT_DIR")"
SERVICES_DIR="$GITOPS_DIR/services"

# Service definitions: name|port|dbName|cpu_req|mem_req|cpu_lim|mem_lim
declare -A SERVICES=(
  ["booking"]="8001|booking|100m|128Mi|500m|512Mi"
  ["cinema"]="8003|cinema|50m|64Mi|250m|256Mi"
  ["movie"]="8002|movie|50m|64Mi|250m|256Mi"
  ["notification"]="8008|notification|50m|64Mi|250m|256Mi"
  ["payment"]="8007|payment|100m|128Mi|500m|512Mi"
  ["seat"]="8005|seat|100m|128Mi|500m|512Mi"
  ["showtime"]="8006|showtime|50m|64Mi|250m|256Mi"
  ["user"]="8004|user|50m|64Mi|250m|256Mi"
)

# Service dependencies
declare -A DEPENDENCIES=(
  ["booking"]="seat-service|showtime-service|payment-service|notification-service"
  ["cinema"]=""
  ["movie"]="cinema-service"
  ["notification"]=""
  ["payment"]=""
  ["seat"]="showtime-service"
  ["showtime"]="movie-service|cinema-service"
  ["user"]=""
)

generate_service() {
  local svc=$1
  local config="${SERVICES[$svc]}"
  local deps="${DEPENDENCIES[$svc]:-}"

  IFS='|' read -r port dbname cpu_req mem_req cpu_lim mem_lim <<< "$config"

  local svc_dir="$SERVICES_DIR/$svc"
  mkdir -p "$svc_dir/base" "$svc_dir/overlays"/{dev,staging,prod}

  echo "Generating $svc-service (port: $port, db: $dbname)"

  # Generate base/deployment.yaml
  cat > "$svc_dir/base/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${svc}-service
  labels:
    app.kubernetes.io/name: ${svc}-service
    app.kubernetes.io/component: service
    app.kubernetes.io/part-of: cinema-microservices
spec:
  replicas: 1
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: ${svc}-service
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${svc}-service
        app.kubernetes.io/component: service
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "${port}"
        prometheus.io/path: "/metrics"
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: ${svc}-service
          image: crizstian/${svc}-service:latest
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: ${port}
              protocol: TCP
          envFrom:
            - configMapRef:
                name: ${svc}-service-config
            - secretRef:
                name: cinema-secrets
                optional: true
          resources:
            requests:
              cpu: ${cpu_req}
              memory: ${mem_req}
            limits:
              cpu: ${cpu_lim}
              memory: ${mem_lim}
          livenessProbe:
            httpGet:
              path: /health/live
              port: http
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /health/ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: ${svc}-service
                topologyKey: kubernetes.io/hostname
EOF

  # Generate base/service.yaml
  cat > "$svc_dir/base/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: ${svc}-service
  labels:
    app.kubernetes.io/name: ${svc}-service
spec:
  type: ClusterIP
  ports:
    - name: http
      port: ${port}
      targetPort: http
  selector:
    app.kubernetes.io/name: ${svc}-service
EOF

  # Generate base/configmap.yaml
  cat > "$svc_dir/base/configmap.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ${svc}-service-config
  labels:
    app.kubernetes.io/name: ${svc}-service
data:
  SERVICE_NAME: ${svc}-service
  SERVICE_PORT: "${port}"
  DB_NAME: ${dbname}
  LOG_LEVEL: info
EOF

  # Generate base/hpa.yaml
  cat > "$svc_dir/base/hpa.yaml" << EOF
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${svc}-service
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${svc}-service
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 80
EOF

  # Generate base/kustomization.yaml
  cat > "$svc_dir/base/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - hpa.yaml

commonLabels:
  app.kubernetes.io/managed-by: argocd
  harness.io/serviceRef: ${svc}-service
EOF

  # Generate overlays for each environment
  for env in dev staging prod; do
    local ns="cinema-${env}"
    local replicas=1
    local min_replicas=1
    local max_replicas=2
    local log_level="debug"

    case $env in
      staging)
        replicas=2
        min_replicas=2
        max_replicas=5
        log_level="info"
        ;;
      prod)
        replicas=3
        min_replicas=3
        max_replicas=10
        log_level="warn"
        ;;
    esac

    cat > "$svc_dir/overlays/$env/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${ns}

resources:
  - ../../base

commonLabels:
  app.kubernetes.io/environment: ${env}
  harness.io/envRef: ${env}

images:
  - name: crizstian/${svc}-service
    newTag: latest

patches:
  - target:
      kind: Deployment
      name: ${svc}-service
    patch: |
      - op: replace
        path: /spec/replicas
        value: ${replicas}
  - target:
      kind: ConfigMap
      name: ${svc}-service-config
    patch: |
      - op: add
        path: /data/LOG_LEVEL
        value: ${log_level}
      - op: add
        path: /data/DB_SERVERS
        value: mongodb.${ns}.svc.cluster.local:27017
      - op: add
        path: /data/NATS_URL
        value: nats://nats.${ns}.svc.cluster.local:4222
  - target:
      kind: HorizontalPodAutoscaler
      name: ${svc}-service
    patch: |
      - op: replace
        path: /spec/minReplicas
        value: ${min_replicas}
      - op: replace
        path: /spec/maxReplicas
        value: ${max_replicas}
EOF
  done
}

echo "Generating GitOps manifests for cinema services..."
for svc in "${!SERVICES[@]}"; do
  generate_service "$svc"
done

echo "Done! Generated manifests in $SERVICES_DIR"
