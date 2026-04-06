#!/usr/bin/env bash
#
# build-go-service.sh - Build optimizado para servicios Go usando Dockerfile genérico
#
# Este script reemplaza los Dockerfiles individuales por servicio,
# usando platform/docker/go-service.Dockerfile con build args.
#
# Uso:
#   SERVICE=booking VERSION=v1.0.0 ./platform/scripts/build-go-service.sh
#   SERVICE=movie VERSION=v1.0.0 PUSH=true ./platform/scripts/build-go-service.sh
#
# Variables de entorno:
#   SERVICE       - Nombre del servicio (booking, movie, payment, notification) [REQUERIDO]
#   VERSION       - Tag de la imagen (default: v0.0.0-dev)
#   REGISTRY      - Registro Docker (default: crizstian)
#   ORGANIZATION  - Organización/proyecto (default: cinema)
#   PUSH          - Push al registry (default: false)
#   SERVICE_PORT  - Puerto del servicio (default: 8000)
#

set -e

# ============================================================
# Configuración
# ============================================================

: "${SERVICE:?ERROR: SERVICE environment variable is required}"
: "${VERSION:=v0.0.0-dev}"
: "${REGISTRY:=crizstian}"
: "${ORGANIZATION:=cinema}"
: "${PUSH:=false}"
: "${SERVICE_PORT:=8000}"

# Derivar configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DOCKERFILE="$PROJECT_ROOT/platform/docker/go-service/Dockerfile"
CONTEXT="$PROJECT_ROOT/services/$SERVICE"
IMAGE_NAME="$REGISTRY/$ORGANIZATION/$SERVICE"
IMAGE_TAG="$IMAGE_NAME:$VERSION"
IMAGE_LATEST="$IMAGE_NAME:latest"

# Build metadata
BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

# ============================================================
# Validaciones
# ============================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Building Go Service: $SERVICE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration:"
echo "  Service:      $SERVICE"
echo "  Version:      $VERSION"
echo "  Image:        $IMAGE_TAG"
echo "  Context:      $CONTEXT"
echo "  Dockerfile:   $DOCKERFILE"
echo "  Port:         $SERVICE_PORT"
echo "  Build Date:   $BUILD_DATE"
echo "  VCS Ref:      $VCS_REF"
echo ""

# Validar que el contexto existe
if [ ! -d "$CONTEXT" ]; then
    echo "❌ ERROR: Service directory not found: $CONTEXT"
    exit 1
fi

# Validar que el Dockerfile existe
if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ ERROR: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

# Validar que go.mod existe
if [ ! -f "$CONTEXT/go.mod" ]; then
    echo "❌ ERROR: go.mod not found in $CONTEXT"
    exit 1
fi

# ============================================================
# Build
# ============================================================

echo "🔨 Building Docker image..."
echo ""

docker build \
    --no-cache \
    --file "$DOCKERFILE" \
    --build-arg SERVICE_NAME="$SERVICE" \
    --build-arg SERVICE_PORT="$SERVICE_PORT" \
    --build-arg VERSION="$VERSION" \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VCS_REF="$VCS_REF" \
    --tag "$IMAGE_TAG" \
    "$CONTEXT"

echo ""
echo "✅ Build successful!"
echo ""
echo "Image tags:"
echo "  - $IMAGE_TAG"
echo ""

# ============================================================
# Push (opcional)
# ============================================================

if [ "$PUSH" == "true" ]; then
    echo "📤 Pushing to registry..."
    echo ""

    docker push "$IMAGE_TAG"
    docker push "$IMAGE_LATEST"

    echo ""
    echo "✅ Push successful!"
    echo ""
else
    echo "ℹ️  Skipping push (use PUSH=true to push to registry)"
    echo ""
fi

# ============================================================
# Resumen
# ============================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Build Complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "To run locally:"
echo "  docker run --rm -p $SERVICE_PORT:$SERVICE_PORT \\"
echo "    -e SERVICE_PORT=$SERVICE_PORT \\"
echo "    $IMAGE_TAG"
echo ""
echo "To inspect:"
echo "  docker inspect $IMAGE_TAG"
echo ""
echo "To check size:"
echo "  docker images | grep $SERVICE"
echo ""
