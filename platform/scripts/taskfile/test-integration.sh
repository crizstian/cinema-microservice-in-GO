#!/usr/bin/env bash
# Run integration tests
# Usage: ./test-integration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)
ensure_test_results_dir

print_section "Running Integration Tests"

# Run tests
output=$(cd tests/integration && go test -v -tags=integration \
  -coverprofile=../../tests/test-results/coverage/integration.out ./... 2>&1) || true

duration=$(duration "$start_time")

# Parse results
parse_test_results "$output"
coverage=$(get_coverage "tests/test-results/coverage/integration.out")
status=$(get_status_string "$TEST_FAILED")

echo "$output"

# Print report
print_simple_report "INTEGRATION TESTS SUMMARY REPORT" "Integration Tests" \
  "$status" "$TEST_PASSED" "$TEST_FAILED" "$TEST_SKIPPED" \
  "Coverage" "$coverage" "$duration"

# Exit with proper code
[ "$TEST_FAILED" -eq 0 ]
