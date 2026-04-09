#!/bin/bash
set -euo pipefail

SERVICE="${1:-booking}"
TAG="${2:-$(cat VERSION 2>/dev/null || echo "0.0.0-dev")}"
REGISTRY="${REGISTRY:-docker.io/crizstian/cinema}"
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

docker build \
  --file platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME="$SERVICE" \
  --build-arg SERVICE_PORT=8000 \
  --build-arg VERSION="$TAG" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --tag "$REGISTRY/$SERVICE:$TAG" \
  --tag "$REGISTRY/$SERVICE:latest" \
  .

echo "Built: $REGISTRY/$SERVICE:$TAG"
