#!/usr/bin/env bash
# Run unit tests for all services
# Usage: ./test-unit-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)
ensure_test_results_dir

# Get services
SERVICES=$(get_services)

# Arrays for summary
declare -A svc_status svc_passed svc_failed svc_skipped svc_coverage svc_duration

failed_services=""
for svc in $SERVICES; do
  print_section "Testing: $svc"

  svc_start=$(now)

  # Run tests
  output=$(cd "services/$svc" && go test -v -race -short -cover \
    -coverprofile="../../tests/test-results/coverage/${svc}.out" \
    $(go list ./... | grep -v '/contracts' | grep -v '/integration' | grep -v '/e2e') 2>&1) || true

  svc_duration[$svc]=$(duration "$svc_start")

  # Parse results
  parse_test_results "$output"
  svc_passed[$svc]=$TEST_PASSED
  svc_failed[$svc]=$TEST_FAILED
  svc_skipped[$svc]=$TEST_SKIPPED
  svc_coverage[$svc]=$(get_coverage "tests/test-results/coverage/${svc}.out")

  if [ "${svc_failed[$svc]}" -gt 0 ]; then
    svc_status[$svc]="❌ FAIL"
    failed_services="$failed_services $svc"
  else
    svc_status[$svc]="✅ PASS"
  fi

  echo "$output"
done

total_duration=$(duration "$start_time")

# Calculate totals
total_passed=0 total_failed=0 total_skipped=0
for svc in $SERVICES; do
  total_passed=$((total_passed + ${svc_passed[$svc]:-0}))
  total_failed=$((total_failed + ${svc_failed[$svc]:-0}))
  total_skipped=$((total_skipped + ${svc_skipped[$svc]:-0}))
done

# Final status
final_status=$(get_status_string "$total_failed")

# Print summary report
print_multi_service_header "UNIT TESTS SUMMARY REPORT"
for svc in $SERVICES; do
  print_service_row "$svc" "${svc_status[$svc]}" "${svc_passed[$svc]:-0}" \
    "${svc_failed[$svc]:-0}" "${svc_skipped[$svc]:-0}" \
    "${svc_coverage[$svc]:-N/A}" "${svc_duration[$svc]:-0}"
done
print_multi_service_footer "$final_status" "$total_passed" "$total_failed" "$total_skipped" "$total_duration"

# Exit with proper code
[ -z "$failed_services" ]
