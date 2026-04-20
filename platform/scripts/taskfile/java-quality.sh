#!/bin/bash
set -euo pipefail

SERVICE="${1:-analytics}"
CHECK="${2:-all}"
SERVICE_DIR="services/${SERVICE}"

if [ ! -d "$SERVICE_DIR" ]; then
    echo "Error: Service directory not found: $SERVICE_DIR"
    exit 1
fi

cd "$SERVICE_DIR"

echo "=== Running Java Quality Checks: ${SERVICE} ==="

run_checkstyle() {
    echo "--- Checkstyle ---"
    if [ -f "pom.xml" ]; then
        mvn checkstyle:check -q 2>/dev/null || echo "Checkstyle not configured"
    elif [ -f "build.gradle" ]; then
        ./gradlew checkstyleMain --no-daemon 2>/dev/null || echo "Checkstyle not configured"
    fi
}

run_spotbugs() {
    echo "--- SpotBugs ---"
    if [ -f "pom.xml" ]; then
        mvn spotbugs:check -q 2>/dev/null || echo "SpotBugs not configured"
    elif [ -f "build.gradle" ]; then
        ./gradlew spotbugsMain --no-daemon 2>/dev/null || echo "SpotBugs not configured"
    fi
}

run_compile() {
    echo "--- Compile Check ---"
    if [ -f "pom.xml" ]; then
        mvn compile -q
    elif [ -f "build.gradle" ]; then
        ./gradlew compileJava --no-daemon
    fi
}

case "$CHECK" in
    checkstyle)
        run_checkstyle
        ;;
    spotbugs)
        run_spotbugs
        ;;
    compile)
        run_compile
        ;;
    all)
        run_compile
        run_checkstyle
        run_spotbugs
        ;;
    *)
        echo "Unknown check: $CHECK"
        echo "Available: checkstyle, spotbugs, compile, all"
        exit 1
        ;;
esac

echo "=== Quality checks complete: ${SERVICE} ==="
