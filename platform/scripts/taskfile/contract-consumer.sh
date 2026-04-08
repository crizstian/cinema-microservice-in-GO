#!/usr/bin/env bash
# Run consumer contract tests
# Usage: ./contract-consumer.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)

print_banner "📝 CONTRACT CONSUMER TESTS"

output=$(cd services/booking && go test -v ./contracts/consumer/... 2>&1) || true
echo "$output"

parse_test_results "$output"
contracts=$(ls contracts/*.json 2>/dev/null | wc -l | tr -d '[:space:]') || contracts=0

duration=$(duration "$start_time")
status=$(get_status_string "$TEST_FAILED")

echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃                📊 CONTRACT CONSUMER SUMMARY                     ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  %-20s │ %-40s ┃\n" "Status" "$status"
printf "┃  %-20s │ %-40s ┃\n" "Tests Passed" "$TEST_PASSED"
printf "┃  %-20s │ %-40s ┃\n" "Tests Failed" "$TEST_FAILED"
printf "┃  %-20s │ %-40s ┃\n" "Contracts Generated" "$contracts"
printf "┃  %-20s │ %-40s ┃\n" "Duration" "${duration}s"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
