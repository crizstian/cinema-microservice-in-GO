#!/usr/bin/env bash
# Check coverage threshold for all services
# Usage: ./test-coverage.sh [threshold]
# Default threshold: 80%

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/report.sh"

cd "${PROJECT_ROOT}"

THRESHOLD="${1:-80}"
start_time=$(now)
ensure_test_results_dir

print_banner "COVERAGE THRESHOLD CHECK (${THRESHOLD}%)"

SERVICES=$(get_services)
declare -A svc_coverage svc_status
failed_services=""
total_coverage=0
service_count=0

for svc in $SERVICES; do
  echo "  Checking coverage: $svc"

  coverage_file="${TEST_RESULTS_DIR}/coverage/${svc}.out"

  # Run tests with coverage if profile doesn't exist
  if [ ! -f "$coverage_file" ]; then
    (cd "services/$svc" && \
      go test -short -cover -coverprofile="../../tests/test-results/coverage/${svc}.out" \
        $(go list ./... | grep -v '/contracts' | grep -v '/integration' | grep -v '/e2e') 2>/dev/null) || true
  fi

  # Get coverage percentage
  if [ -f "$coverage_file" ]; then
    coverage=$(get_coverage "$coverage_file")
    coverage_num=$(echo "$coverage" | sed 's/%//')

    # Handle N/A case
    if [ "$coverage_num" = "N/A" ]; then
      coverage_num=0
    fi

    svc_coverage[$svc]="$coverage"
    total_coverage=$((total_coverage + ${coverage_num%.*}))
    service_count=$((service_count + 1))

    # Check threshold
    if [ "${coverage_num%.*}" -ge "$THRESHOLD" ]; then
      svc_status[$svc]="PASS"
    else
      svc_status[$svc]="FAIL"
      failed_services="$failed_services $svc"
    fi
  else
    svc_coverage[$svc]="N/A"
    svc_status[$svc]="SKIP"
  fi
done

duration=$(duration "$start_time")

# Calculate average
if [ "$service_count" -gt 0 ]; then
  avg_coverage=$((total_coverage / service_count))
else
  avg_coverage=0
fi

# Generate badges JSON
cat > "${TEST_RESULTS_DIR}/coverage-badges.json" << EOF
{
  "schemaVersion": 1,
  "label": "coverage",
  "message": "${avg_coverage}%",
  "color": $([ "$avg_coverage" -ge "$THRESHOLD" ] && echo '"brightgreen"' || echo '"red"')
}
EOF

# Print summary
echo ""
echo "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
echo "┃                         COVERAGE THRESHOLD REPORT                            ┃"
echo "┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  Threshold: %d%%                                                              ┃\n" "$THRESHOLD"
echo "┣━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
echo "┃  Service          ┃ Coverage   ┃ Status                                      ┃"
echo "┣━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━╋━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"

for svc in $SERVICES; do
  status_icon=$([ "${svc_status[$svc]}" = "PASS" ] && echo "PASS" || echo "FAIL")
  printf "┃  %-16s ┃ %-10s ┃ %-43s ┃\n" \
    "$svc" "${svc_coverage[$svc]:-N/A}" "$status_icon"
done

echo "┣━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫"
printf "┃  Average Coverage: %d%% | Duration: %ds                                      ┃\n" "$avg_coverage" "$duration"
echo "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
echo ""

# Generate HTML coverage report
echo "Generating HTML coverage report..."
for svc in $SERVICES; do
  coverage_file="${TEST_RESULTS_DIR}/coverage/${svc}.out"
  if [ -f "$coverage_file" ]; then
    go tool cover -html="$coverage_file" -o "${TEST_RESULTS_DIR}/coverage/${svc}.html" 2>/dev/null || true
  fi
done

echo "Coverage reports: ${TEST_RESULTS_DIR}/coverage/*.html"
echo "Badge JSON: ${TEST_RESULTS_DIR}/coverage-badges.json"
echo ""

# Exit with failure if any service is below threshold
if [ -n "$failed_services" ]; then
  echo "Services below ${THRESHOLD}% threshold:$failed_services"
  exit 1
fi

echo "All services meet the ${THRESHOLD}% coverage threshold!"
