#!/usr/bin/env bash
# Run E2E tests with full system
# Usage: ./test-e2e.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)
ensure_test_results_dir

print_banner "E2E TEST EXECUTION"

# Set test environment
export ENV_PREFIX=test
export MONGO_SERVERS="mongo:27017"
# Short TTL for hold expiration test (Test10)
export HOLD_TTL_SECONDS=5

# Clean start
echo "Cleaning up previous containers..."
docker_compose --profile test --profile e2e down -v --remove-orphans 2>/dev/null || true

# Stage 1: Start infrastructure
echo ""
echo "Stage 1: Starting infrastructure (MongoDB, Redis, NATS)..."
docker_compose --profile test up -d mongo redis-test nats

# Stage 2: Wait for MongoDB init
echo "Stage 2: Initializing MongoDB replica set..."
docker_compose --profile test up mongo-init-test
echo "  MongoDB initialized"

# Stage 3: Start all services
echo ""
echo "Stage 3: Starting microservices..."
docker_compose --profile test up -d --build

echo "Waiting for services to be healthy..."
if ! wait_for_services 8 120; then
  echo ""
  echo "Service Status:"
  docker_compose --profile test ps
  echo ""
  echo "Service Logs (last 50 lines):"
  docker_compose --profile test logs --tail=50
  docker_compose --profile test down -v
  exit 1
fi

echo ""
echo "Service Status:"
docker_compose --profile test ps

# Stage 4: Run E2E tests
echo ""
echo "Stage 4: Running E2E tests..."
test_output=$(docker_compose --profile test --profile e2e run --rm e2e-runner 2>&1) || true

echo "$test_output"

# Parse results from test output
parse_test_results "$test_output"

# Cleanup
echo ""
echo "Cleaning up..."
docker_compose --profile test --profile e2e down -v

duration=$(duration "$start_time")
status=$(get_status_string "$TEST_FAILED")

# Print summary report
print_simple_report "E2E TESTS SUMMARY REPORT" "End-to-End Tests" \
  "$status" "$TEST_PASSED" "$TEST_FAILED" "$TEST_SKIPPED" \
  "Services Tested" "8 microservices" "$duration"

# Exit with proper code
[ "$TEST_FAILED" -eq 0 ]
