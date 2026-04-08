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

print_banner "🚀 E2E TEST EXECUTION"

# Clean start
echo "📦 Cleaning up previous containers..."
docker_compose down -v --remove-orphans 2>/dev/null || true

echo "🏗️  Starting services..."
docker_compose --profile full up -d --build --force-recreate

echo "⏳ Waiting for services to be healthy..."
if ! wait_for_services 8 90; then
  docker_compose --profile full ps
  docker_compose down -v
  exit 1
fi

echo ""
echo "📋 Service Status:"
docker_compose --profile full ps

echo ""
echo "🧪 Building and running E2E tests..."
docker build -t e2e-test-runner "${PROJECT_ROOT}/tests/integration"

# Capture test output
test_output=$(docker run --rm --network cinema-test-network e2e-test-runner 2>&1) || true

echo "$test_output"

# Parse results from test output
parse_test_results "$test_output"

# Cleanup
echo ""
echo "🧹 Cleaning up..."
docker_compose down -v

duration=$(duration "$start_time")
status=$(get_status_string "$TEST_FAILED")

# Print summary report
print_simple_report "E2E TESTS SUMMARY REPORT" "End-to-End Tests" \
  "$status" "$TEST_PASSED" "$TEST_FAILED" "$TEST_SKIPPED" \
  "Services Tested" "8 microservices" "$duration"

# Exit with proper code
[ "$TEST_FAILED" -eq 0 ]
