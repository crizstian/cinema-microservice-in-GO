#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES=$(ls -d services/*/go.mod 2>/dev/null | xargs -I{} dirname {} | xargs -I{} basename {})

for service in $SERVICES; do
  echo "=== Building $service ==="
  "$SCRIPT_DIR/build.sh" "$service"
done

echo "All services built."
