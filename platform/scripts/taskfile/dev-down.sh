#!/bin/bash
set -euo pipefail

COMPOSE_FILE="platform/deploy/docker-compose/docker-compose.yml"
docker compose -f "$COMPOSE_FILE" --profile dev down -v
