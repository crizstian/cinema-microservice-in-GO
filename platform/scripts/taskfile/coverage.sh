#!/usr/bin/env bash
# Generate combined coverage report
# Usage: ./coverage.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

start_time=$(now)
ensure_test_results_dir

print_banner "📈 COVERAGE REPORT GENERATION"

SERVICES=$(get_services)
declare -A svc_coverage

for svc in $SERVICES; do
  echo "  Analyzing: $svc"
  (cd "services/$svc" && \
    go test -short -coverprofile="../../tests/test-results/coverage/${svc}.out" \
      $(go list ./... | grep -v '/contracts' | grep -v '/integration' | grep -v '/e2e')) > /dev/null 2>&1 || true

  svc_coverage[$svc]=$(get_coverage "tests/test-results/coverage/${svc}.out")
done

echo ""
echo "  Combining coverage files..."
echo "mode: set" > tests/test-results/coverage/combined.out
tail -n +2 tests/test-results/coverage/*.out >> tests/test-results/coverage/combined.out 2>/dev/null || true
go tool cover -html=tests/test-results/coverage/combined.out -o tests/test-results/coverage.html 2>/dev/null || true

combined_coverage=$(get_coverage "tests/test-results/coverage/combined.out")
duration=$(duration "$start_time")

# Print summary report
print_coverage_header
for svc in $SERVICES; do
  cov="${svc_coverage[$svc]:-N/A}"
  indicator=$(get_coverage_indicator "$cov")
  print_coverage_row "$svc" "$cov" "$indicator"
done
print_coverage_footer "$combined_coverage" "$duration"
