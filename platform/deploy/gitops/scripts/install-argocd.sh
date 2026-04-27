#!/bin/bash
# ArgoCD Installation Script for Cinema Microservices
# Usage: ./install-argocd.sh [dev|staging|prod]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITOPS_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="argocd"
ENV="${1:-dev}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."

  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
  fi

  if ! command -v helm &> /dev/null; then
    log_error "Helm not found. Please install Helm."
    exit 1
  fi

  if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster."
    exit 1
  fi

  log_info "Prerequisites OK"
}

# Add Helm repo
add_helm_repo() {
  log_info "Adding ArgoCD Helm repository..."
  helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
  helm repo update
}

# Create namespace
create_namespace() {
  log_info "Creating namespace $NAMESPACE..."
  kubectl create namespace $NAMESPACE 2>/dev/null || true
}

# Install ArgoCD
install_argocd() {
  local values_file="$GITOPS_DIR/argocd/values.yaml"

  log_info "Installing ArgoCD with Helm..."

  if [[ -f "$values_file" ]]; then
    helm upgrade --install argocd argo/argo-cd \
      --namespace $NAMESPACE \
      --values "$values_file" \
      --wait \
      --timeout 10m
  else
    log_warn "Values file not found, using defaults..."
    helm upgrade --install argocd argo/argo-cd \
      --namespace $NAMESPACE \
      --set server.extraArgs[0]=--insecure \
      --set applicationSet.enabled=true \
      --wait \
      --timeout 10m
  fi
}

# Wait for pods
wait_for_pods() {
  log_info "Waiting for ArgoCD pods to be ready..."
  kubectl wait --for=condition=Ready pods --all -n $NAMESPACE --timeout=300s
}

# Get admin password
get_admin_password() {
  log_info "Retrieving admin password..."

  local password
  password=$(kubectl -n $NAMESPACE get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

  if [[ -n "$password" ]]; then
    echo ""
    echo "============================================"
    echo "ArgoCD Admin Credentials"
    echo "============================================"
    echo "Username: admin"
    echo "Password: $password"
    echo "============================================"
    echo ""
  else
    log_warn "Could not retrieve password. It may have been deleted."
  fi
}

# Setup port forward
setup_port_forward() {
  log_info "Setting up port-forward..."
  echo ""
  echo "To access ArgoCD UI, run:"
  echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
  echo ""
  echo "Then open: https://localhost:8080"
  echo ""
}

# Install CLI
install_cli() {
  if command -v argocd &> /dev/null; then
    log_info "ArgoCD CLI already installed: $(argocd version --client --short)"
    return
  fi

  log_info "Installing ArgoCD CLI..."

  local os
  local arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  case $arch in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
  esac

  curl -sSL -o /tmp/argocd \
    "https://github.com/argoproj/argo-cd/releases/latest/download/argocd-${os}-${arch}"

  chmod +x /tmp/argocd
  sudo mv /tmp/argocd /usr/local/bin/argocd

  log_info "ArgoCD CLI installed: $(argocd version --client --short)"
}

# Bootstrap applications
bootstrap_apps() {
  local bootstrap_file="$GITOPS_DIR/argocd/apps/cinema-bootstrap.yaml"

  if [[ -f "$bootstrap_file" ]]; then
    log_info "Bootstrapping Cinema applications..."
    kubectl apply -f "$bootstrap_file"
    log_info "Bootstrap application created"
  else
    log_warn "Bootstrap file not found: $bootstrap_file"
  fi
}

# Main
main() {
  echo ""
  echo "============================================"
  echo "ArgoCD Installation for Cinema Microservices"
  echo "Environment: $ENV"
  echo "============================================"
  echo ""

  check_prerequisites
  add_helm_repo
  create_namespace
  install_argocd
  wait_for_pods
  get_admin_password

  read -p "Install ArgoCD CLI? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_cli
  fi

  read -p "Bootstrap Cinema applications? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    bootstrap_apps
  fi

  setup_port_forward

  log_info "ArgoCD installation complete!"
  echo ""
  echo "Next steps:"
  echo "  1. Access UI: kubectl port-forward svc/argocd-server -n $NAMESPACE 8080:443"
  echo "  2. Login CLI: argocd login localhost:8080 --username admin"
  echo "  3. Add repo: argocd repo add https://github.com/crizstian/cinema-microservice-in-GO.git"
  echo "  4. Sync apps: argocd app list && argocd app sync <app-name>"
  echo ""
}

main "$@"
