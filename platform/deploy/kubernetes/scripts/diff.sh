#!/bin/bash
# Show diff between rendered manifests and cluster state
# Usage: ./diff.sh <service> <environment>
# Example: ./diff.sh booking dev

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE="${1:?Usage: $0 <service> <environment>}"
ENVIRONMENT="${2:?Usage: $0 <service> <environment>}"

MANIFESTS_DIR="${K8S_DIR}/rendered/${ENVIRONMENT}/${SERVICE}"

if [ ! -d "$MANIFESTS_DIR" ]; then
  echo "ERROR: Manifests not found. Run render.sh first."
  exit 1
fi

echo "=== Diff for $SERVICE ($ENVIRONMENT) ==="
echo ""

for manifest in "${MANIFESTS_DIR}"/*.yaml; do
  if [ -f "$manifest" ]; then
    filename=$(basename "$manifest")
    echo "--- $filename ---"
    kubectl diff -f "$manifest" 2>/dev/null || echo "(no changes or resource doesn't exist)"
    echo ""
  fi
done
