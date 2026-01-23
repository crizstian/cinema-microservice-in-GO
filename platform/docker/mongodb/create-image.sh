#!/usr/bin/env bash
# ⚠️  DEPRECADO - Usar: make build SERVICE=cinemas-db VERSION=vX.Y.Z

echo "⚠️  DEPRECADO: Usar 'make build SERVICE=cinemas-db VERSION=v0.1'"
echo "Documentación: docs/DOCKER-BUILD.md"
echo ""

docker rm -f cinemas-db:v0.1 2>/dev/null || true
docker rmi cinemas-db:v0.1 2>/dev/null || true
docker image prune -f
docker volume prune -f

docker build -t cinemas-db:v0.1 .
docker tag cinemas-db:v0.1 crizstian/cinemas-db:v0.1
docker push crizstian/cinemas-db:v0.1
