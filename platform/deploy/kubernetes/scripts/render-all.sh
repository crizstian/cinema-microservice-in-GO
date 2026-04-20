#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

ENVIRONMENT="${1:-dev}"
VERSION="${2:-latest}"

SERVICES=(booking movie cinema user seat showtime payment notification)

echo "Rendering all services for environment: $ENVIRONMENT, version: $VERSION"

for service in "${SERVICES[@]}"; do
    echo "=== Rendering: $service ==="
    "${K8S_DIR}/bin/render" \
        -service "$service" \
        -env "$ENVIRONMENT" \
        -version "$VERSION" \
        -base "$K8S_DIR" \
        -output "${K8S_DIR}/rendered/${ENVIRONMENT}/${service}"
done

echo "All services rendered to: ${K8S_DIR}/rendered/${ENVIRONMENT}/"
