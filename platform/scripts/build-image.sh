#!/usr/bin/env bash
#
# build-image.sh - Script genérico para construir imágenes Docker
#
# Uso:
#   ./scripts/build-image.sh [OPTIONS]
#
# Variables de entorno (con valores por defecto):
#   SERVICE       - Nombre del servicio (requerido)
#   VERSION       - Tag de la imagen (default: v0.0.0-dev)
#   REGISTRY      - Registro Docker (default: crizstian)
#   ORGANIZATION  - Organización/proyecto (default: cinema)
#   CONTEXT       - Contexto de build (default: ./$SERVICE)
#   DOCKERFILE    - Ruta al Dockerfile (default: $CONTEXT/Dockerfile)
#   PUSH          - Push al registry (default: false, usar "true" para activar)
#   BUILD_ARGS    - Argumentos adicionales para docker build
#
# Ejemplos:
#   SERVICE=booking-service VERSION=v1.0.0 ./scripts/build-image.sh
#   SERVICE=movie-service VERSION=v1.0.0 PUSH=true ./scripts/build-image.sh
#

set -e  # Exit on error

# ============================================================
# CONFIGURACIÓN
# ============================================================

# Valores por defecto
: "${VERSION:=v0.0.0-dev}"
: "${REGISTRY:=crizstian}"
: "${ORGANIZATION:=cinema}"
: "${PUSH:=false}"

# Validación de parámetros requeridos
if [ -z "$SERVICE" ]; then
    echo "❌ ERROR: SERVICE es requerido"
    echo ""
    echo "Uso: SERVICE=booking-service VERSION=v1.0.0 $0"
    exit 1
fi

# Configuración derivada
: "${CONTEXT:=./$SERVICE}"
: "${DOCKERFILE:=$CONTEXT/Dockerfile}"

# Nombre completo de la imagen
IMAGE_NAME="${REGISTRY}/${ORGANIZATION}/${SERVICE}"
IMAGE_TAG="${VERSION}"
IMAGE_FULL="${IMAGE_NAME}:${IMAGE_TAG}"

# ============================================================
# VALIDACIÓN
# ============================================================

if [ ! -d "$CONTEXT" ]; then
    echo "❌ ERROR: Contexto no existe: $CONTEXT"
    exit 1
fi

if [ ! -f "$DOCKERFILE" ]; then
    echo "❌ ERROR: Dockerfile no existe: $DOCKERFILE"
    exit 1
fi

# ============================================================
# BUILD
# ============================================================

echo "🔨 Construyendo imagen Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Servicio:    $SERVICE"
echo "  Versión:     $VERSION"
echo "  Imagen:      $IMAGE_FULL"
echo "  Contexto:    $CONTEXT"
echo "  Dockerfile:  $DOCKERFILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Build de la imagen
docker build \
    -t "$IMAGE_FULL" \
    -t "${IMAGE_NAME}:latest" \
    -f "$DOCKERFILE" \
    ${BUILD_ARGS} \
    "$CONTEXT"

echo ""
echo "✅ Imagen construida: $IMAGE_FULL"

# ============================================================
# PUSH (opcional)
# ============================================================

if [ "$PUSH" = "true" ]; then
    echo ""
    echo "📤 Pushing imagen al registry..."
    docker push "$IMAGE_FULL"
    docker push "${IMAGE_NAME}:latest"
    echo "✅ Push completado"
fi

echo ""
echo "🎉 Proceso completado exitosamente"
