#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

SERVICE="${1:-}"
ENVIRONMENT="${2:-dev}"
VERSION="${3:-latest}"

if [[ -z "$SERVICE" ]]; then
    echo "Usage: $0 <service> [environment] [version]"
    echo "  service:     booking, movie, cinema, user, seat, showtime, payment, notification"
    echo "  environment: dev (default), staging, prod"
    echo "  version:     latest (default) or specific version"
    exit 1
fi

OUTPUT_DIR="${K8S_DIR}/rendered/${ENVIRONMENT}/${SERVICE}"

"${K8S_DIR}/bin/render" \
    -service "$SERVICE" \
    -env "$ENVIRONMENT" \
    -version "$VERSION" \
    -base "$K8S_DIR" \
    -output "$OUTPUT_DIR"
