#!/bin/bash
# Delete service from Kubernetes cluster
# Usage: ./delete.sh <service> <environment> [--force]
# Example: ./delete.sh booking dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE="${1:?Usage: $0 <service> <environment> [--force]}"
ENVIRONMENT="${2:?Usage: $0 <service> <environment> [--force]}"
FORCE="${3:-}"

NAMESPACE="cinema-${ENVIRONMENT}"

if [ "$FORCE" != "--force" ]; then
  echo "WARNING: This will delete $SERVICE from $NAMESPACE"
  read -p "Are you sure? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo "=== Deleting $SERVICE from $NAMESPACE ==="

kubectl delete deployment "$SERVICE" -n "$NAMESPACE" --ignore-not-found
kubectl delete service "$SERVICE" -n "$NAMESPACE" --ignore-not-found
kubectl delete serviceaccount "$SERVICE" -n "$NAMESPACE" --ignore-not-found
kubectl delete configmap "${SERVICE}-config" -n "$NAMESPACE" --ignore-not-found
kubectl delete secret "${SERVICE}-secrets" -n "$NAMESPACE" --ignore-not-found
kubectl delete hpa "$SERVICE" -n "$NAMESPACE" --ignore-not-found
kubectl delete pdb "$SERVICE" -n "$NAMESPACE" --ignore-not-found
kubectl delete networkpolicy "$SERVICE" -n "$NAMESPACE" --ignore-not-found
kubectl delete ingress "$SERVICE" -n "$NAMESPACE" --ignore-not-found

echo ""
echo "=== Done ==="
