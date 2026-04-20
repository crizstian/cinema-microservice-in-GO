#!/bin/bash
# Deploy infrastructure components (MongoDB, Jaeger, Ingress)
# Usage: ./deploy-infra.sh [environment]
# Example: ./deploy-infra.sh dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"
INFRA_DIR="${K8S_DIR}/infrastructure"

ENVIRONMENT="${1:-dev}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Infrastructure Deployment"
echo "=============================================="
echo "  Environment: $ENVIRONMENT"
echo "=============================================="
echo ""

# 1. Ingress Controller
log_info "Step 1: Deploying Ingress Controller..."
if kubectl get deployment -n ingress-nginx ingress-nginx-controller &>/dev/null; then
  log_warn "Ingress Controller already exists, skipping..."
else
  kubectl apply -f "${INFRA_DIR}/ingress-nginx/ingress-controller.yaml"
  log_info "Waiting for Ingress Controller..."
  kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=ingress-nginx \
    --timeout=120s || log_warn "Ingress not ready yet"
fi

# 2. MongoDB
log_info "Step 2: Deploying MongoDB..."
if kubectl get pods -n mongodb -l app=mongodb 2>/dev/null | grep -q Running; then
  log_warn "MongoDB already running, skipping..."
else
  # Generate credentials if not set
  MONGO_ROOT_USER="${MONGO_ROOT_USER:-admin}"
  MONGO_ROOT_PASS="${MONGO_ROOT_PASS:-$(openssl rand -base64 16 | tr -d '=+/')}"

  log_info "MongoDB credentials:"
  echo "  User: $MONGO_ROOT_USER"
  echo "  Pass: $MONGO_ROOT_PASS"
  echo ""

  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: mongodb
  labels:
    name: mongodb
---
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secrets
  namespace: mongodb
type: Opaque
stringData:
  MONGO_INITDB_ROOT_USERNAME: "${MONGO_ROOT_USER}"
  MONGO_INITDB_ROOT_PASSWORD: "${MONGO_ROOT_PASS}"
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb
  namespace: mongodb
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
  namespace: mongodb
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
      containers:
        - name: mongodb
          image: mongo:7.0
          ports:
            - containerPort: 27017
          envFrom:
            - secretRef:
                name: mongodb-secrets
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

  log_info "Waiting for MongoDB..."
  kubectl wait --namespace mongodb \
    --for=condition=ready pod \
    --selector=app=mongodb \
    --timeout=120s || log_warn "MongoDB not ready yet"
fi

# 3. Jaeger
log_info "Step 3: Deploying Jaeger..."
if kubectl get deployment -n observability jaeger &>/dev/null; then
  log_warn "Jaeger already exists, skipping..."
else
  INGRESS_DOMAIN="${INGRESS_DOMAIN:-dev.local}"

  cat "${INFRA_DIR}/jaeger/jaeger.yaml" | \
    sed "s|\${INGRESS_DOMAIN}|${INGRESS_DOMAIN}|g" | \
    kubectl apply -f -

  log_info "Waiting for Jaeger..."
  kubectl wait --namespace observability \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=jaeger \
    --timeout=120s || log_warn "Jaeger not ready yet"
fi

# 4. Create application secrets
log_info "Step 4: Creating application secrets..."
NAMESPACE="cinema-${ENVIRONMENT}"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic mongodb-credentials \
  --namespace="$NAMESPACE" \
  --from-literal=DB_USER=cinema \
  --from-literal=DB_PASS=cinema123 \
  --dry-run=client -o yaml | kubectl apply -f -

# Summary
echo ""
echo "=============================================="
echo "  Infrastructure Deployment Complete!"
echo "=============================================="
echo ""
log_info "Status:"
echo ""
echo "=== Ingress Controller ==="
kubectl get pods -n ingress-nginx --no-headers 2>/dev/null || echo "Not deployed"
echo ""
echo "=== MongoDB ==="
kubectl get pods -n mongodb --no-headers 2>/dev/null || echo "Not deployed"
echo ""
echo "=== Jaeger ==="
kubectl get pods -n observability --no-headers 2>/dev/null || echo "Not deployed"
echo ""
log_info "Next step: Deploy services with ./deploy-full.sh $ENVIRONMENT"
