#!/usr/bin/env bash
# Start test infrastructure (MongoDB + Redis)
# Usage: ./infra-up.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

cd "${PROJECT_ROOT}"

docker_compose --profile infra up -d
sleep 5
docker_compose exec -T mongo mongosh --eval "db.adminCommand('ping')" --quiet || true
docker_compose exec -T redis redis-cli ping || true
