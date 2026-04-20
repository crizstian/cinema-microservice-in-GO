#!/bin/bash
set -euo pipefail

# Health check script for cinema microservices
# Usage: ./health-check.sh [live|ready|all]
#
# Supports two modes:
# - Direct (localhost): When running on host or in same Docker network
# - Docker exec: When running in isolated devcontainer

MODE="${1:-live}"
TIMEOUT=5
EXIT_CODE=0

# Service definitions (from platform/config/services.yaml)
declare -A SERVICES=(
  ["booking"]=8001
  ["movie"]=8002
  ["cinema"]=8003
  ["user"]=8004
  ["seat"]=8005
  ["showtime"]=8006
  ["payment"]=8007
  ["notification"]=8008
)

# Detect how we can reach services:
# 1. localhost - running on host or port-forwarded
# 2. container - on same Docker network (cinema-dev-network)
# 3. docker - via docker exec (fallback)
# 4. none - no access
detect_access_mode() {
  if curl -s --connect-timeout 1 http://localhost:8002/health/live >/dev/null 2>&1; then
    echo "localhost"
  elif curl -s --connect-timeout 1 http://dev-movie:8002/health/live >/dev/null 2>&1; then
    echo "container"
  elif docker exec dev-movie wget -qO- -T 1 http://localhost:8002/health/live >/dev/null 2>&1; then
    echo "docker"
  else
    echo "none"
  fi
}

ACCESS_MODE=$(detect_access_mode)

check_service() {
  local name=$1
  local port=$2
  local endpoint=$3
  local response
  local container="dev-${name}"

  case "$ACCESS_MODE" in
    localhost)
      response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "http://localhost:${port}${endpoint}" 2>/dev/null) || true
      ;;
    container)
      response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "http://${container}:${port}${endpoint}" 2>/dev/null) || true
      ;;
    docker)
      if docker exec "$container" wget -qO- -T $TIMEOUT "http://localhost:${port}${endpoint}" >/dev/null 2>&1; then
        response="200"
      else
        response="000"
      fi
      ;;
    *)
      response="000"
      ;;
  esac

  if [ "$response" = "200" ]; then
    printf "  %-15s :%s  %-20s \033[32mOK\033[0m\n" "$name" "$port" "$endpoint"
    return 0
  else
    printf "  %-15s :%s  %-20s \033[31mFAIL (HTTP %s)\033[0m\n" "$name" "$port" "$endpoint" "${response:-000}"
    return 1
  fi
}

check_infra() {
  local name=$1
  local port=$2
  local endpoint=$3
  local container="dev-${name}"
  local response

  case "$ACCESS_MODE" in
    localhost)
      response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "http://localhost:${port}${endpoint}" 2>/dev/null) || true
      ;;
    container)
      response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $TIMEOUT "http://${container}:${port}${endpoint}" 2>/dev/null) || true
      ;;
    docker)
      if docker exec "$container" wget -qO- -T $TIMEOUT "http://localhost:${port}${endpoint}" >/dev/null 2>&1; then
        response="200"
      else
        response="000"
      fi
      ;;
    *)
      response="000"
      ;;
  esac

  if [ "$response" = "200" ]; then
    printf "  %-15s :%s  %-20s \033[32mOK\033[0m\n" "$name" "$port" "$endpoint"
    return 0
  else
    printf "  %-15s :%s  %-20s \033[33mN/A\033[0m\n" "$name" "$port" "$endpoint"
    return 0
  fi
}

check_mongo() {
  local port=$1
  if docker exec dev-mongo1 mongosh --port "$port" --eval "db.runCommand({ping:1})" >/dev/null 2>&1; then
    printf "  %-15s :%s  %-20s \033[32mOK\033[0m\n" "mongo" "$port" "ping"
    return 0
  else
    printf "  %-15s :%s  %-20s \033[33mN/A\033[0m\n" "mongo" "$port" "ping"
    return 0
  fi
}

check_redis() {
  if docker exec dev-redis redis-cli ping 2>/dev/null | grep -q PONG; then
    printf "  %-15s :%s  %-20s \033[32mOK\033[0m\n" "redis" "6379" "PING"
    return 0
  else
    printf "  %-15s :%s  %-20s \033[33mN/A\033[0m\n" "redis" "6379" "PING"
    return 0
  fi
}

echo ""
echo "=== Health Check: ${MODE^^} ==="
case "$ACCESS_MODE" in
  localhost)  echo "(via localhost - host/port-forwarded)" ;;
  container)  echo "(via docker network - cinema-dev-network)" ;;
  docker)     echo "(via docker exec - devcontainer isolated)" ;;
  *)          echo "(no services reachable - run 'task dev:up')" ;;
esac
echo ""

# Check based on mode
case "$MODE" in
  live)
    echo "Checking /health/live endpoints..."
    echo ""
    for name in booking movie cinema user seat showtime payment notification; do
      check_service "$name" "${SERVICES[$name]}" "/health/live" || EXIT_CODE=1
    done
    ;;

  ready)
    echo "Checking /health/ready endpoints..."
    echo ""
    for name in booking movie cinema user seat showtime payment notification; do
      check_service "$name" "${SERVICES[$name]}" "/health/ready" || EXIT_CODE=1
    done
    ;;

  all)
    echo "Microservices (liveness):"
    echo ""
    for name in booking movie cinema user seat showtime payment notification; do
      check_service "$name" "${SERVICES[$name]}" "/health/live" || EXIT_CODE=1
    done

    echo ""
    echo "Microservices (readiness):"
    echo ""
    for name in booking movie cinema user seat showtime payment notification; do
      check_service "$name" "${SERVICES[$name]}" "/health/ready" || EXIT_CODE=1
    done

    echo ""
    echo "Infrastructure:"
    echo ""
    check_infra "nats" "8222" "/healthz"
    check_mongo "27017"
    check_redis
    ;;

  *)
    echo "Usage: $0 [live|ready|all]"
    echo ""
    echo "  live   - Check /health/live endpoints (default)"
    echo "  ready  - Check /health/ready endpoints"
    echo "  all    - Check all endpoints + infrastructure"
    exit 1
    ;;
esac

echo ""

if [ $EXIT_CODE -eq 0 ]; then
  echo "=== All checks passed ==="
else
  echo "=== Some checks failed ==="
fi

exit $EXIT_CODE
