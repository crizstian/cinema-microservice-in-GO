#!/usr/bin/env bash
# ⚠️  DEPRECADO - Usar: make build SERVICE=base_docker_image VERSION=vX.Y.Z

echo "⚠️  DEPRECADO: Usar 'make build SERVICE=base_docker_image VERSION=v0.2'"
echo "Documentación: docs/DOCKER-BUILD.md"
echo ""

docker rm -f cinemas-base-image:alpine-v0.2 2>/dev/null || true
docker rmi cinemas-base-image:alpine-v0.2 2>/dev/null || true
docker image prune -f
docker volume prune -f

docker build -t cinemas-base-image:alpine-v0.2 .
docker tag cinemas-base-image:alpine-v0.2 crizstian/cinemas-base-image:alpine-v0.2
docker push crizstian/cinemas-base-image:alpine-v0.2
