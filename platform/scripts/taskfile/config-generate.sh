#!/bin/bash
# config-generate.sh
# Generates .env.local from config/services.yaml

set -e

CONFIG_FILE="platform/config/services.yaml"
ENV_FILE="platform/deploy/docker-compose/.env"

if ! command -v yq &> /dev/null; then
    echo "ERROR: yq is required. Install with: brew install yq"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: $CONFIG_FILE not found"
    exit 1
fi

echo "Generating $ENV_FILE from $CONFIG_FILE..."

cat > "$ENV_FILE" << 'HEADER'
# Auto-generated from platform/config/services.yaml
# DO NOT EDIT MANUALLY - Run: task config:generate
#
# Docker Compose auto-detects this file in its directory

HEADER

echo "# Service Ports" >> "$ENV_FILE"
for svc in $(yq '.services | keys | .[]' "$CONFIG_FILE"); do
    port=$(yq ".services.${svc}.port" "$CONFIG_FILE")
    echo "${svc^^}_PORT=${port}" >> "$ENV_FILE"
done

echo "" >> "$ENV_FILE"
echo "# Database Names" >> "$ENV_FILE"
for svc in $(yq '.services | keys | .[]' "$CONFIG_FILE"); do
    db=$(yq ".services.${svc}.dbName" "$CONFIG_FILE")
    echo "${svc^^}_DB=${db}" >> "$ENV_FILE"
done

echo "" >> "$ENV_FILE"
echo "# Images" >> "$ENV_FILE"
for svc in $(yq '.services | keys | .[]' "$CONFIG_FILE"); do
    image=$(yq ".services.${svc}.image" "$CONFIG_FILE")
    echo "${svc^^}_IMAGE=${image}" >> "$ENV_FILE"
done

echo "Generated $ENV_FILE"
cat "$ENV_FILE"
