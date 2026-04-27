#!/bin/bash
#
# reset-demo.sh - Reset demo environment for repeatable Harness demos
#
# Usage:
#   ./reset-demo.sh [quick|full]
#
# Options:
#   quick  - Fast reset: clean pods and revert git (default)
#   full   - Full reset: includes GitOps sync and namespace cleanup
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="${NAMESPACE:-cinema-dev}"
ARGOCD_APP="${ARGOCD_APP:-cinema-services}"
GIT_BRANCH="${GIT_BRANCH:-main}"

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

header() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              HARNESS DEMO RESET                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Mode: $1"
    echo "║  Namespace: $NAMESPACE"
    echo "║  Branch: $GIT_BRANCH"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        log_error "git not found"
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_warn "Cannot connect to Kubernetes cluster"
        log_warn "Skipping Kubernetes operations"
        return 1
    fi

    log_success "Prerequisites OK"
    return 0
}

reset_git() {
    log_info "Resetting Git state..."

    # Revert demo-specific files first
    DEMO_FILES=(
        "services/movie/internal/api/movies.go"
        "services/booking/internal/api/booking.go"
        "services/movie/internal/models/movies.go"
    )

    for file in "${DEMO_FILES[@]}"; do
        if [ -f "$file" ]; then
            git checkout -- "$file" 2>/dev/null && log_info "Reverted: $file"
        fi
    done

    # Discard any remaining local changes
    git checkout -- . 2>/dev/null || true

    # Fetch latest from remote
    git fetch origin "$GIT_BRANCH" --quiet

    # Reset to remote branch
    git checkout "$GIT_BRANCH" 2>/dev/null || git checkout -b "$GIT_BRANCH" "origin/$GIT_BRANCH"
    git reset --hard "origin/$GIT_BRANCH"

    log_success "Git reset to origin/$GIT_BRANCH"
}

clean_kubernetes() {
    log_info "Cleaning Kubernetes namespace: $NAMESPACE..."

    # Delete all pods to force fresh deployment
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        kubectl delete pods --all -n "$NAMESPACE" --grace-period=0 --force 2>/dev/null || true
        log_success "Pods deleted in $NAMESPACE"
    else
        log_warn "Namespace $NAMESPACE not found, skipping"
    fi
}

sync_argocd() {
    log_info "Syncing ArgoCD application: $ARGOCD_APP..."

    # Check if argocd CLI is available
    if command -v argocd &> /dev/null; then
        argocd app sync "$ARGOCD_APP" --prune --force 2>/dev/null || true
        log_success "ArgoCD sync triggered"
    else
        log_warn "argocd CLI not found, skipping sync"
        log_info "Sync manually via ArgoCD UI or: kubectl -n argocd exec -it deployment/argocd-server -- argocd app sync $ARGOCD_APP"
    fi
}

verify_delegate() {
    log_info "Verifying Harness delegate connectivity..."

    # Check for delegate pods
    DELEGATE_PODS=$(kubectl get pods -A -l app.kubernetes.io/name=harness-delegate 2>/dev/null | grep -c Running || echo "0")

    if [ "$DELEGATE_PODS" -gt 0 ]; then
        log_success "Delegate running ($DELEGATE_PODS pod(s))"
    else
        log_warn "No running delegate found"
        log_info "Check delegate status in Harness UI"
    fi
}

verify_gitops_agent() {
    log_info "Verifying GitOps agent..."

    AGENT_PODS=$(kubectl get pods -n argocd -l app.kubernetes.io/name=gitops-agent 2>/dev/null | grep -c Running || echo "0")

    if [ "$AGENT_PODS" -gt 0 ]; then
        log_success "GitOps agent running"
    else
        log_warn "GitOps agent not found or not running"
    fi
}

print_checklist() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              PRE-DEMO CHECKLIST                              ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  [ ] Verify delegate is connected in Harness UI             ║"
    echo "║  [ ] Open browser tabs:                                      ║"
    echo "║      - Harness Deployments page                              ║"
    echo "║      - Pipeline Studio (CICD_Go_ShiftLeft)                   ║"
    echo "║      - ArgoCD Applications                                   ║"
    echo "║      - GitHub repository                                     ║"
    echo "║  [ ] Test a quick pipeline run with: booking                 ║"
    echo "║  [ ] Verify GitOps agent sync status                         ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Demo URLs:"
    echo "  Harness: https://app.harness.io/ng/account/EeRjnXTnS4GrLG5VNNJZUw/all/orgs/sandbox/projects/CristianRamirez/deployments"
    echo "  Pipeline: https://app.harness.io/ng/account/EeRjnXTnS4GrLG5VNNJZUw/all/orgs/sandbox/projects/CristianRamirez/pipelines/CICD_Go_ShiftLeft"
    echo ""
}

quick_reset() {
    header "QUICK RESET"

    HAS_K8S=true
    check_prerequisites || HAS_K8S=false

    reset_git

    if [ "$HAS_K8S" = true ]; then
        clean_kubernetes
        verify_delegate
    fi

    log_success "Quick reset complete!"
    print_checklist
}

full_reset() {
    header "FULL RESET"

    HAS_K8S=true
    check_prerequisites || HAS_K8S=false

    reset_git

    if [ "$HAS_K8S" = true ]; then
        clean_kubernetes
        sync_argocd
        verify_delegate
        verify_gitops_agent

        log_info "Waiting for pods to stabilize..."
        sleep 10

        log_info "Current pod status in $NAMESPACE:"
        kubectl get pods -n "$NAMESPACE" 2>/dev/null || true
    fi

    log_success "Full reset complete!"
    print_checklist
}

# Main
case "${1:-quick}" in
    quick)
        quick_reset
        ;;
    full)
        full_reset
        ;;
    *)
        echo "Usage: $0 [quick|full]"
        echo "  quick - Fast reset (default)"
        echo "  full  - Full reset with GitOps sync"
        exit 1
        ;;
esac
