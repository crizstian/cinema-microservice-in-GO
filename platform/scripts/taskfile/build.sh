#!/bin/bash
# Build Docker image for a service with semantic versioning
# Usage: ./build.sh <service> [version] [--push]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SERVICE="${1:-booking}"
VERSION="${2:-}"
PUSH_FLAG="${3:-}"
REGISTRY="${REGISTRY:-docker.io/crizstian}"
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cd "$(git rev-parse --show-toplevel)"

if [ -z "$VERSION" ]; then
  VERSION=$("$SCRIPT_DIR/version.sh" "$SERVICE")
  echo "Using version from git tags: v$VERSION"
fi

IMAGE_NAME="$REGISTRY/${SERVICE}-service"

echo "=== Building Docker image for $SERVICE ==="
echo "Version: $VERSION"
echo "Image: $IMAGE_NAME"
echo ""

cd "services/$SERVICE"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w -X main.Version=${VERSION}" \
  -o "$SERVICE" \
  "./cmd/$SERVICE"
echo "Binary built: $(ls -lh "$SERVICE")"
cd - > /dev/null

docker build \
  --file platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME="$SERVICE" \
  --build-arg SERVICE_PORT=8000 \
  --build-arg VERSION="$VERSION" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --tag "$IMAGE_NAME:v$VERSION" \
  --tag "$IMAGE_NAME:latest" \
  .

echo ""
echo "Built: $IMAGE_NAME:v$VERSION"
echo "Built: $IMAGE_NAME:latest"

if [ "$PUSH_FLAG" = "--push" ]; then
  echo ""
  echo "Pushing images..."
  docker push "$IMAGE_NAME:v$VERSION"
  docker push "$IMAGE_NAME:latest"
  echo "Pushed: $IMAGE_NAME:v$VERSION"
fi
