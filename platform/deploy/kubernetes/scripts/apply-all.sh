#!/bin/bash
# Apply all services to an environment
# Usage: ./apply-all.sh <environment> [--dry-run]
# Example: ./apply-all.sh dev --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ENVIRONMENT="${1:?Usage: $0 <environment> [--dry-run]}"
DRY_RUN="${2:-}"

SERVICES=(
  movie
  cinema
  user
  showtime
  seat
  payment
  notification
  booking  # Last because it depends on others
)

echo "=== Applying all services to $ENVIRONMENT ==="
echo ""

for service in "${SERVICES[@]}"; do
  "${SCRIPT_DIR}/apply.sh" "$service" "$ENVIRONMENT" "$DRY_RUN"
  echo ""
done

echo "=== All services applied ==="
