#!/usr/bin/env bash
# Lint all Go services with go vet
# Usage: ./lint-go.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

cd "${PROJECT_ROOT}"

SERVICES=$(get_services)

failed=""
for svc in $SERVICES; do
  echo "=== $svc ==="
  (cd "services/$svc" && go vet ./...) || failed="$failed $svc"
done

[ -z "$failed" ] || { echo "FAILED:$failed"; exit 1; }
