#!/bin/bash
# Harness Delegate Installation Script
# Cinema Microservices Project
#
# Usage: ./install-delegate.sh [ACCOUNT_ID] [DELEGATE_TOKEN]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="harness-delegate-ng"
RELEASE_NAME="cinema-delegate"
VALUES_FILE="$SCRIPT_DIR/delegate-values.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
  log_step "Checking prerequisites..."

  if ! command -v kubectl &> /dev/null; then
    log_error "kubectl not found. Please install kubectl."
    exit 1
  fi

  if ! command -v helm &> /dev/null; then
    log_error "Helm not found. Please install Helm v3+."
    exit 1
  fi

  if ! kubectl cluster-info &> /dev/null; then
    log_error "Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
  fi

  log_info "Prerequisites OK"
}

# Get or prompt for account ID
get_account_id() {
  if [[ -n "${1:-}" ]]; then
    ACCOUNT_ID="$1"
  elif [[ -n "${HARNESS_ACCOUNT_ID:-}" ]]; then
    ACCOUNT_ID="$HARNESS_ACCOUNT_ID"
  else
    read -p "Enter Harness Account ID: " ACCOUNT_ID
  fi

  if [[ -z "$ACCOUNT_ID" ]]; then
    log_error "Account ID is required"
    exit 1
  fi
}

# Get or prompt for delegate token
get_delegate_token() {
  if [[ -n "${2:-}" ]]; then
    DELEGATE_TOKEN="$2"
  elif [[ -n "${HARNESS_DELEGATE_TOKEN:-}" ]]; then
    DELEGATE_TOKEN="$HARNESS_DELEGATE_TOKEN"
  else
    read -sp "Enter Delegate Token: " DELEGATE_TOKEN
    echo
  fi

  if [[ -z "$DELEGATE_TOKEN" ]]; then
    log_error "Delegate Token is required"
    exit 1
  fi
}

# Add Helm repository
add_helm_repo() {
  log_step "Adding Harness Delegate Helm repository..."

  helm repo add harness-delegate \
    https://app.harness.io/storage/harness-download/delegate-helm-chart/ \
    2>/dev/null || true

  helm repo update
  log_info "Helm repository added"
}

# Create namespace
create_namespace() {
  log_step "Creating namespace $NAMESPACE..."

  kubectl create namespace "$NAMESPACE" 2>/dev/null || true
  log_info "Namespace ready"
}

# Install delegate
install_delegate() {
  log_step "Installing Harness Delegate..."

  helm upgrade --install "$RELEASE_NAME" \
    harness-delegate/harness-delegate-ng \
    --namespace "$NAMESPACE" \
    --set accountId="$ACCOUNT_ID" \
    --set delegateToken="$DELEGATE_TOKEN" \
    --set managerEndpoint="https://app.harness.io" \
    --set delegateName="$RELEASE_NAME" \
    --set replicas=2 \
    --set tags="cinema\\,kubernetes\\,gitops" \
    --wait \
    --timeout 10m

  log_info "Delegate installed"
}

# Install with custom values
install_delegate_custom() {
  log_step "Installing Harness Delegate with custom values..."

  if [[ ! -f "$VALUES_FILE" ]]; then
    log_error "Values file not found: $VALUES_FILE"
    exit 1
  fi

  # Create temp values with credentials
  TEMP_VALUES=$(mktemp)
  cat "$VALUES_FILE" > "$TEMP_VALUES"

  helm upgrade --install "$RELEASE_NAME" \
    harness-delegate/harness-delegate-ng \
    --namespace "$NAMESPACE" \
    --values "$TEMP_VALUES" \
    --set accountId="$ACCOUNT_ID" \
    --set delegateToken="$DELEGATE_TOKEN" \
    --wait \
    --timeout 10m

  rm -f "$TEMP_VALUES"
  log_info "Delegate installed with custom values"
}

# Wait for delegate pods
wait_for_pods() {
  log_step "Waiting for delegate pods to be ready..."

  kubectl wait --for=condition=Ready pods \
    -l harness.io/name="$RELEASE_NAME" \
    -n "$NAMESPACE" \
    --timeout=300s

  log_info "Delegate pods are ready"
}

# Show status
show_status() {
  log_step "Delegate Status:"
  echo ""
  kubectl get pods -n "$NAMESPACE" -l harness.io/name="$RELEASE_NAME"
  echo ""

  log_info "Delegate logs:"
  kubectl logs -n "$NAMESPACE" -l harness.io/name="$RELEASE_NAME" --tail=20
  echo ""
}

# Show next steps
show_next_steps() {
  echo ""
  echo "============================================"
  echo "Harness Delegate Installation Complete"
  echo "============================================"
  echo ""
  echo "Next steps:"
  echo "  1. Verify in Harness UI: Account Settings → Delegates"
  echo "  2. Wait for status: Connected (2-5 minutes)"
  echo "  3. Test with a connector: Connectors → New → Kubernetes Cluster"
  echo ""
  echo "Useful commands:"
  echo "  # View pods"
  echo "  kubectl get pods -n $NAMESPACE"
  echo ""
  echo "  # View logs"
  echo "  kubectl logs -f -n $NAMESPACE -l harness.io/name=$RELEASE_NAME"
  echo ""
  echo "  # Restart delegate"
  echo "  kubectl rollout restart deployment/$RELEASE_NAME -n $NAMESPACE"
  echo ""
}

# Uninstall delegate
uninstall_delegate() {
  log_step "Uninstalling Harness Delegate..."

  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
  kubectl delete namespace "$NAMESPACE" || true

  log_info "Delegate uninstalled"
}

# Main
main() {
  local action="${1:-install}"

  case "$action" in
    install)
      echo ""
      echo "============================================"
      echo "Harness Delegate Installation"
      echo "============================================"
      echo ""

      check_prerequisites
      get_account_id "${2:-}"
      get_delegate_token "${3:-}"
      add_helm_repo
      create_namespace

      if [[ -f "$VALUES_FILE" ]]; then
        read -p "Use custom values file? (Y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
          install_delegate_custom
        else
          install_delegate
        fi
      else
        install_delegate
      fi

      wait_for_pods
      show_status
      show_next_steps
      ;;

    uninstall)
      uninstall_delegate
      ;;

    status)
      show_status
      ;;

    *)
      echo "Usage: $0 {install|uninstall|status} [ACCOUNT_ID] [DELEGATE_TOKEN]"
      echo ""
      echo "Environment variables:"
      echo "  HARNESS_ACCOUNT_ID      - Harness Account ID"
      echo "  HARNESS_DELEGATE_TOKEN  - Delegate Token"
      exit 1
      ;;
  esac
}

main "$@"
