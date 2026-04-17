#!/bin/bash
# Full deployment script for Cinema Microservices
# Usage: ./deploy-full.sh <environment> [version]
# Example: ./deploy-full.sh dev v1.0.0

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

ENVIRONMENT="${1:?Usage: $0 <environment> [version]}"
VERSION="${2:-latest}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

NAMESPACE="cinema-${ENVIRONMENT}"

echo ""
echo "=============================================="
echo "  Cinema Microservices - Full Deployment"
echo "=============================================="
echo "  Environment: $ENVIRONMENT"
echo "  Namespace:   $NAMESPACE"
echo "  Version:     $VERSION"
echo "=============================================="
echo ""

# Phase 1: Validate
log_info "Phase 1: Validating cluster access..."
if ! kubectl cluster-info &>/dev/null; then
  log_error "Cannot connect to Kubernetes cluster"
  exit 1
fi
log_info "Cluster access: OK"

# Phase 2: Render all manifests
log_info "Phase 2: Rendering manifests..."
"${SCRIPT_DIR}/render-all.sh" "$ENVIRONMENT" "$VERSION"

# Phase 3: Create namespace
log_info "Phase 3: Creating namespace..."
kubectl apply -f "${K8S_DIR}/rendered/${ENVIRONMENT}/namespace.yaml"
kubectl wait --for=jsonpath='{.status.phase}'=Active namespace/"$NAMESPACE" --timeout=30s

# Phase 4: Deploy base services (no dependencies)
log_info "Phase 4: Deploying base services..."
BASE_SERVICES="movie cinema user"
for svc in $BASE_SERVICES; do
  log_info "  Deploying: $svc"
  "${SCRIPT_DIR}/apply.sh" "$svc" "$ENVIRONMENT"
done

log_info "  Waiting for base services..."
for svc in $BASE_SERVICES; do
  kubectl wait --namespace "$NAMESPACE" \
    --for=condition=available deployment/"$svc" \
    --timeout=120s 2>/dev/null || log_warn "$svc not ready yet"
done

# Phase 5: Deploy intermediate services
log_info "Phase 5: Deploying intermediate services..."
INTERMEDIATE_SERVICES="showtime seat payment notification"
for svc in $INTERMEDIATE_SERVICES; do
  log_info "  Deploying: $svc"
  "${SCRIPT_DIR}/apply.sh" "$svc" "$ENVIRONMENT"
done

log_info "  Waiting for intermediate services..."
for svc in $INTERMEDIATE_SERVICES; do
  kubectl wait --namespace "$NAMESPACE" \
    --for=condition=available deployment/"$svc" \
    --timeout=120s 2>/dev/null || log_warn "$svc not ready yet"
done

# Phase 6: Deploy booking (SAGA orchestrator)
log_info "Phase 6: Deploying booking (SAGA orchestrator)..."
"${SCRIPT_DIR}/apply.sh" booking "$ENVIRONMENT"
kubectl wait --namespace "$NAMESPACE" \
  --for=condition=available deployment/booking \
  --timeout=120s 2>/dev/null || log_warn "booking not ready yet"

# Phase 7: Verify deployment
log_info "Phase 7: Verifying deployment..."
echo ""
echo "=== Deployment Status ==="
kubectl get deployments -n "$NAMESPACE" -o wide
echo ""
echo "=== Pod Status ==="
kubectl get pods -n "$NAMESPACE"
echo ""
echo "=== Services ==="
kubectl get svc -n "$NAMESPACE"
echo ""

# Count ready pods
TOTAL=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].status.replicas}' | wc -w)
READY=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].status.readyReplicas}' | tr ' ' '+' | bc 2>/dev/null || echo "0")

echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo "  Namespace: $NAMESPACE"
echo "  Version:   $VERSION"
echo "  Services:  $TOTAL deployed"
echo "=============================================="
echo ""
log_info "Next steps:"
echo "  1. Port-forward: kubectl port-forward -n $NAMESPACE svc/booking 8001:80"
echo "  2. Test health:  curl http://localhost:8001/health/ready"
echo "  3. View logs:    kubectl logs -n $NAMESPACE -l app.kubernetes.io/environment=$ENVIRONMENT -f"
echo ""
