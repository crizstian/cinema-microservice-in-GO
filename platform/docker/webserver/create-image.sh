#!/usr/bin/env bash
# ⚠️  DEPRECADO - Usar: make build SERVICE=webserver VERSION=vX.Y.Z

echo "⚠️  DEPRECADO: Usar 'make build SERVICE=webserver VERSION=v0.5'"
echo "Documentación: docs/DOCKER-BUILD.md"
echo ""

docker rm -f webserver:v0.5 2>/dev/null || true
docker rmi webserver:v0.5 2>/dev/null || true
docker image prune -f
docker volume prune -f

docker build -t webserver:v0.5 .
docker tag webserver:v0.5 crizstian/webserver:v0.5
docker push crizstian/webserver:v0.5
