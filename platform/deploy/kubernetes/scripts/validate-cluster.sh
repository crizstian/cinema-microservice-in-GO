#!/bin/bash
# Validate Kubernetes cluster prerequisites
# Usage: ./validate-cluster.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

check_pass() { echo -e "  ${GREEN}✓${NC} $1"; }
check_fail() { echo -e "  ${RED}✗${NC} $1"; ((ERRORS++)); }
check_warn() { echo -e "  ${YELLOW}!${NC} $1"; ((WARNINGS++)); }

echo ""
echo "=============================================="
echo "  Kubernetes Cluster Validation"
echo "=============================================="
echo ""

# 1. Check kubectl
echo "1. Tools:"
if command -v kubectl &>/dev/null; then
  VERSION=$(kubectl version --client -o json 2>/dev/null | grep -o '"gitVersion": "[^"]*"' | head -1 | cut -d'"' -f4)
  check_pass "kubectl installed ($VERSION)"
else
  check_fail "kubectl not installed"
fi

if command -v task &>/dev/null; then
  check_pass "task installed"
else
  check_warn "task not installed (optional)"
fi

# 2. Check cluster connectivity
echo ""
echo "2. Cluster Access:"
if kubectl cluster-info &>/dev/null; then
  CONTEXT=$(kubectl config current-context 2>/dev/null)
  check_pass "Connected to cluster ($CONTEXT)"
else
  check_fail "Cannot connect to cluster"
fi

# 3. Check namespaces
echo ""
echo "3. Namespaces:"
for ns in ingress-nginx mongodb observability; do
  if kubectl get namespace "$ns" &>/dev/null; then
    check_pass "$ns namespace exists"
  else
    check_warn "$ns namespace not found (will be created)"
  fi
done

# 4. Check infrastructure
echo ""
echo "4. Infrastructure:"

# Ingress Controller
if kubectl get deployment -n ingress-nginx ingress-nginx-controller &>/dev/null; then
  READY=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$READY" -gt 0 ]; then
    check_pass "Ingress Controller running ($READY replicas)"
  else
    check_warn "Ingress Controller deployed but not ready"
  fi
else
  check_warn "Ingress Controller not deployed"
fi

# MongoDB
if kubectl get pods -n mongodb -l app=mongodb &>/dev/null 2>&1; then
  READY=$(kubectl get pods -n mongodb -l app=mongodb -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Unknown")
  if [ "$READY" = "Running" ]; then
    check_pass "MongoDB running"
  else
    check_warn "MongoDB status: $READY"
  fi
else
  check_warn "MongoDB not deployed"
fi

# Jaeger
if kubectl get deployment -n observability jaeger &>/dev/null; then
  READY=$(kubectl get deployment -n observability jaeger -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "$READY" -gt 0 ]; then
    check_pass "Jaeger running"
  else
    check_warn "Jaeger deployed but not ready"
  fi
else
  check_warn "Jaeger not deployed"
fi

# 5. Check storage
echo ""
echo "5. Storage:"
if kubectl get storageclass &>/dev/null; then
  DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null)
  if [ -n "$DEFAULT_SC" ]; then
    check_pass "Default StorageClass: $DEFAULT_SC"
  else
    check_warn "No default StorageClass (may need to specify)"
  fi
else
  check_warn "Cannot list StorageClasses"
fi

# 6. Check resources
echo ""
echo "6. Cluster Resources:"
NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
if [ "$NODES" -gt 0 ]; then
  check_pass "$NODES node(s) available"

  # Check node status
  NOT_READY=$(kubectl get nodes --no-headers 2>/dev/null | grep -v " Ready " | wc -l)
  if [ "$NOT_READY" -gt 0 ]; then
    check_warn "$NOT_READY node(s) not ready"
  fi
else
  check_fail "No nodes available"
fi

# 7. Check RBAC permissions
echo ""
echo "7. RBAC Permissions:"
if kubectl auth can-i create deployments --all-namespaces &>/dev/null; then
  check_pass "Can create deployments"
else
  check_fail "Cannot create deployments"
fi

if kubectl auth can-i create services --all-namespaces &>/dev/null; then
  check_pass "Can create services"
else
  check_fail "Cannot create services"
fi

# Summary
echo ""
echo "=============================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "  ${GREEN}All checks passed!${NC}"
elif [ $ERRORS -eq 0 ]; then
  echo -e "  ${YELLOW}Passed with $WARNINGS warning(s)${NC}"
else
  echo -e "  ${RED}Failed with $ERRORS error(s), $WARNINGS warning(s)${NC}"
fi
echo "=============================================="
echo ""

exit $ERRORS
