#!/usr/bin/env bash
# CI pipeline: lint + unit tests + OpenAPI validation
# Usage: ./test-ci.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)
ensure_test_results_dir

print_banner "🔄 CI PIPELINE EXECUTION"

# Phase 1: Lint
print_phase "Phase 1: Linting"
lint_status="✅ PASS"
"${SCRIPT_DIR}/lint-go.sh" 2>&1 || lint_status="❌ FAIL"

# Phase 2: Unit Tests
print_phase "Phase 2: Unit Tests"

SERVICES=$(get_services)
declare -A svc_status svc_passed svc_failed svc_skipped svc_coverage

failed_services=""
for svc in $SERVICES; do
  echo "  Testing: $svc"

  # Run tests and capture
  output=$(cd "services/$svc" && \
    go test -v -race -short -cover -coverprofile="../../tests/test-results/coverage/${svc}.out" \
      $(go list ./... | grep -v '/contracts' | grep -v '/integration' | grep -v '/e2e') 2>&1) || true

  # Generate JUnit XML if go-junit-report is available
  echo "$output" | go-junit-report > "tests/test-results/${svc}-unit.xml" 2>/dev/null || true

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
done

# Phase 3: OpenAPI Validation
print_phase "Phase 3: OpenAPI Validation"
openapi_status="✅ PASS"
spectral lint services/*/api/openapi.yaml --format junit > tests/test-results/openapi.xml 2>/dev/null || openapi_status="⚠️  WARN"

duration=$(duration "$start_time")

# Calculate totals
total_passed=0 total_failed=0 total_skipped=0
for svc in $SERVICES; do
  total_passed=$((total_passed + ${svc_passed[$svc]:-0}))
  total_failed=$((total_failed + ${svc_failed[$svc]:-0}))
  total_skipped=$((total_skipped + ${svc_skipped[$svc]:-0}))
done
total_tests=$((total_passed + total_failed + total_skipped))

# Final status
final_status=$(get_status_string "$total_failed")

# Print summary report
echo ""
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃                         📊 CI PIPELINE SUMMARY REPORT                       ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃  PHASES                                                                     ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  %-20s │ %-55s ┃\n" "Lint" "$lint_status"
printf "┃  %-20s │ %-55s ┃\n" "OpenAPI Validation" "$openapi_status"
printf "┃  %-20s │ %-55s ┃\n" "Unit Tests" "$final_status"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃  SERVICE BREAKDOWN                                                          ┃"
echo "┣━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━┳━━━━━━┳━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃  Service          ┃ Status    ┃ Pass ┃ Fail ┃ Skip ┃ Coverage                ┃"
echo "┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━╋━━━━━━╋━━━━━━╋━━━━━━╋━━━━━━━━━━━━━━━━━━━━━━━━━┫"
for svc in $SERVICES; do
  printf "┃  %-16s ┃ %-9s ┃ %4s ┃ %4s ┃ %4s ┃ %-23s ┃\n" \
    "$svc" "${svc_status[$svc]}" "${svc_passed[$svc]:-0}" "${svc_failed[$svc]:-0}" \
    "${svc_skipped[$svc]:-0}" "${svc_coverage[$svc]:-N/A}"
done
echo "┣━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━┻━━━━━━┻━━━━━━┻━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  TOTAL: %d tests | ✅ %d passed | ❌ %d failed | ⏭️  %d skipped              ┃\n" \
  "$total_tests" "$total_passed" "$total_failed" "$total_skipped"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  Duration: %ds | Reports: tests/test-results/*.xml                        ┃\n" "$duration"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# Exit with proper code
[ -z "$failed_services" ]
