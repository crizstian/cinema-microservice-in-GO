#!/usr/bin/env bash
# Run unit tests for a single service
# Usage: ./test-unit.sh <service_name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

SERVICE="${1:-booking}"

cd "${SERVICES_DIR}/${SERVICE}"

start_time=$(now)
ensure_test_results_dir

# Run tests and capture output
output=$(go test -v -race -short -cover \
  -coverprofile="${TEST_RESULTS_DIR}/${SERVICE}.out" \
  $(go list ./... | grep -v '/contracts' | grep -v '/integration' | grep -v '/e2e') 2>&1) || true

duration=$(duration "$start_time")

# Parse results
parse_test_results "$output"
coverage=$(get_coverage "${TEST_RESULTS_DIR}/${SERVICE}.out")
status=$(get_status_string "$TEST_FAILED")

# Print report
print_single_service_report "$SERVICE" "$status" "$TEST_PASSED" "$TEST_FAILED" "$TEST_SKIPPED" "$coverage" "$duration"

# Show output
echo ""
echo "$output"

# Exit with proper code
[ "$TEST_FAILED" -eq 0 ]
