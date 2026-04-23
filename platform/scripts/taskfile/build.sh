#!/bin/bash
# Build Docker image for a service with semantic versioning
# Usage: ./build.sh <service> [version] [--push]
#
# This script:
# 1. Compiles Go binary locally (benefits from host Go cache)
# 2. Builds Docker image using pre-compiled binary (BINARY_SOURCE=prebuilt)
# 3. Optionally pushes to registry

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
SERVICE_DIR="services/$SERVICE"

echo "=== Building Docker image for $SERVICE ==="
echo "Version: $VERSION"
echo "Image: $IMAGE_NAME"
echo ""

# Step 1: Build Go binary locally
echo "=== Step 1: Compiling Go binary ==="
cd "$SERVICE_DIR"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go build -ldflags="-s -w -X main.Version=${VERSION} -X main.CommitSHA=${COMMIT_SHA} -X main.BuildDate=${BUILD_DATE}" \
  -o "$SERVICE" \
  "./cmd/$SERVICE"
echo "Binary built: $(ls -lh "$SERVICE")"
cd - > /dev/null

# Step 2: Build Docker image using pre-compiled binary
echo ""
echo "=== Step 2: Building Docker image (using pre-compiled binary) ==="
docker build \
  --file platform/docker/go-service/Dockerfile \
  --build-arg SERVICE_NAME="$SERVICE" \
  --build-arg SERVICE_PORT=8000 \
  --build-arg VERSION="$VERSION" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  --build-arg COMMIT_SHA="$COMMIT_SHA" \
  --build-arg BINARY_SOURCE=prebuilt \
  --tag "$IMAGE_NAME:v$VERSION" \
  --tag "$IMAGE_NAME:latest" \
  .

# Cleanup: remove local binary
rm -f "$SERVICE_DIR/$SERVICE"

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
