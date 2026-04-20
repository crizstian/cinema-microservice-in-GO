#!/bin/bash
# Run benchmark tests for a service
# Usage: ./benchmark.sh <service>

set -euo pipefail

SERVICE="${1:?Usage: $0 <service>}"
BENCHTIME="${BENCHTIME:-1s}"

SERVICE_DIR="services/$SERVICE"

if [ ! -d "$SERVICE_DIR" ]; then
  echo "ERROR: Service directory not found: $SERVICE_DIR"
  exit 1
fi

echo "=== Running benchmarks for $SERVICE ==="
cd "$SERVICE_DIR"

PACKAGES=$(go list ./... | grep -v -E '(integration_tests|contracts|e2e)' || echo "./...")

set -o pipefail
go test -v -short -bench=. -benchmem -benchtime="$BENCHTIME" $PACKAGES 2>&1 | tee benchmark-output.txt

echo ""
echo "=== Benchmark Summary ==="
grep -E "^Benchmark" benchmark-output.txt || echo "No benchmarks found"

if command -v go-junit-report &> /dev/null; then
  go-junit-report < benchmark-output.txt > benchmark-report.xml 2>/dev/null || true
  echo "JUnit report: benchmark-report.xml"
fi

rm -f benchmark-output.txt
