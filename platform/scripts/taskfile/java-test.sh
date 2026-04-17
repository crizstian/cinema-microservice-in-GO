#!/bin/bash
set -euo pipefail

SERVICE="${1:-analytics}"
SERVICE_DIR="services/${SERVICE}"

if [ ! -d "$SERVICE_DIR" ]; then
    echo "Error: Service directory not found: $SERVICE_DIR"
    exit 1
fi

cd "$SERVICE_DIR"

echo "=== Running Java Tests: ${SERVICE} ==="

if [ -f "build.gradle" ]; then
    echo "Build tool: Gradle"
    if [ -f "gradlew" ]; then
        chmod +x gradlew
        ./gradlew test --no-daemon
    else
        gradle test
    fi
elif [ -f "pom.xml" ]; then
    echo "Build tool: Maven"
    mvn test
else
    echo "Error: No pom.xml or build.gradle found"
    exit 1
fi

echo "=== Tests complete: ${SERVICE} ==="
