#!/bin/bash
set -euo pipefail

COMPOSE_FILE="platform/deploy/docker-compose/docker-compose.yml"

export ENV_PREFIX=dev
export MONGO_SERVERS="mongo1:27017,mongo2:27017,mongo3:27017"

docker compose -f "$COMPOSE_FILE" --profile dev up -d --build
echo "Waiting for services..."
sleep 10
docker compose -f "$COMPOSE_FILE" --profile dev ps
