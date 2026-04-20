#!/bin/bash
set -euo pipefail

SERVICE="${1:-analytics}"
VERSION="${2:-latest}"
PUSH="${3:-}"

SERVICE_DIR="services/${SERVICE}"

if [ ! -d "$SERVICE_DIR" ]; then
    echo "Error: Service directory not found: $SERVICE_DIR"
    exit 1
fi

# Detect build tool
if [ -f "${SERVICE_DIR}/build.gradle" ]; then
    BUILD_TOOL="gradle"
elif [ -f "${SERVICE_DIR}/pom.xml" ]; then
    BUILD_TOOL="maven"
else
    echo "Error: No pom.xml or build.gradle found in $SERVICE_DIR"
    exit 1
fi

# Get version info
COMMIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Determine Docker registry
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"
IMAGE_NAME="cinema-${SERVICE}"
if [ -n "$DOCKER_REGISTRY" ]; then
    IMAGE_NAME="${DOCKER_REGISTRY}/${IMAGE_NAME}"
fi

# Detect service port from application config
if [ -f "${SERVICE_DIR}/src/main/resources/application.yml" ]; then
    SERVICE_PORT=$(grep -E "^\s*port:" "${SERVICE_DIR}/src/main/resources/application.yml" | head -1 | awk '{print $2}' || echo "8000")
elif [ -f "${SERVICE_DIR}/src/main/resources/application.properties" ]; then
    SERVICE_PORT=$(grep "quarkus.http.port" "${SERVICE_DIR}/src/main/resources/application.properties" | cut -d= -f2 || echo "8000")
else
    SERVICE_PORT="8000"
fi

echo "=== Building Java Service: ${SERVICE} ==="
echo "Build tool: ${BUILD_TOOL}"
echo "Version: ${VERSION}"
echo "Port: ${SERVICE_PORT}"
echo "Image: ${IMAGE_NAME}:${VERSION}"

docker build \
    -f platform/docker/java-service/Dockerfile \
    --build-arg SERVICE_NAME="${SERVICE}" \
    --build-arg BUILD_TOOL="${BUILD_TOOL}" \
    --build-arg SERVICE_PORT="${SERVICE_PORT}" \
    --build-arg VERSION="${VERSION}" \
    --build-arg COMMIT_SHA="${COMMIT_SHA}" \
    --build-arg BUILD_DATE="${BUILD_DATE}" \
    -t "${IMAGE_NAME}:${VERSION}" \
    -t "${IMAGE_NAME}:latest" \
    .

echo "=== Build complete: ${IMAGE_NAME}:${VERSION} ==="

if [ "$PUSH" = "--push" ]; then
    echo "=== Pushing ${IMAGE_NAME}:${VERSION} ==="
    docker push "${IMAGE_NAME}:${VERSION}"
    docker push "${IMAGE_NAME}:latest"
fi
