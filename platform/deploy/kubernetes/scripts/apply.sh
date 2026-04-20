#!/bin/bash
# Apply rendered manifests to Kubernetes cluster
# Usage: ./apply.sh <service> <environment> [--dry-run]
# Example: ./apply.sh booking dev --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE="${1:?Usage: $0 <service> <environment> [--dry-run]}"
ENVIRONMENT="${2:?Usage: $0 <service> <environment> [--dry-run]}"
DRY_RUN="${3:-}"

MANIFESTS_DIR="${K8S_DIR}/rendered/${ENVIRONMENT}/${SERVICE}"
NAMESPACE_FILE="${K8S_DIR}/rendered/${ENVIRONMENT}/namespace.yaml"

if [ ! -d "$MANIFESTS_DIR" ]; then
  echo "ERROR: Manifests not found. Run render.sh first."
  echo "Expected: $MANIFESTS_DIR"
  exit 1
fi

DRY_RUN_FLAG=""
if [ "$DRY_RUN" = "--dry-run" ]; then
  DRY_RUN_FLAG="--dry-run=client"
  echo "=== DRY RUN MODE ==="
fi

echo "=== Applying manifests for $SERVICE ($ENVIRONMENT) ==="
echo ""

# Apply namespace first if it exists
if [ -f "$NAMESPACE_FILE" ]; then
  echo "Applying namespace..."
  kubectl apply -f "$NAMESPACE_FILE" $DRY_RUN_FLAG
fi

# Apply in order: configmap, secret, service, deployment, hpa, pdb, networkpolicy
APPLY_ORDER=(
  "configmap.yaml"
  "secret.yaml"
  "service.yaml"
  "deployment.yaml"
  "hpa.yaml"
  "pdb.yaml"
  "networkpolicy.yaml"
)

for manifest in "${APPLY_ORDER[@]}"; do
  if [ -f "${MANIFESTS_DIR}/${manifest}" ]; then
    echo "Applying ${manifest}..."
    kubectl apply -f "${MANIFESTS_DIR}/${manifest}" $DRY_RUN_FLAG
  fi
done

echo ""
echo "=== Done ==="

if [ -z "$DRY_RUN_FLAG" ]; then
  echo "Verifying deployment..."
  kubectl rollout status deployment/"$SERVICE" -n "cinema-${ENVIRONMENT}" --timeout=120s || true
fi
