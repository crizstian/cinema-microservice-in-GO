#!/bin/bash
# Code quality checks: complexity and duplication
# Usage: ./quality.sh <service> [check_type]
# check_type: complexity, duplication, all (default)

set -euo pipefail

SERVICE="${1:?Usage: $0 <service> [complexity|duplication|all]}"
CHECK_TYPE="${2:-all}"
MAX_COMPLEXITY="${MAX_COMPLEXITY:-15}"
MIN_TOKENS="${MIN_TOKENS:-100}"

SERVICE_DIR="services/$SERVICE"

if [ ! -d "$SERVICE_DIR" ]; then
  echo "ERROR: Service directory not found: $SERVICE_DIR"
  exit 1
fi

check_complexity() {
  echo "=== Complexity Analysis: $SERVICE ==="
  echo "Checking cyclomatic complexity (max: $MAX_COMPLEXITY)..."

  if ! command -v gocyclo &> /dev/null; then
    echo "Installing gocyclo..."
    go install github.com/fzipp/gocyclo/cmd/gocyclo@latest
  fi

  cd "$SERVICE_DIR"
  COMPLEX=$(gocyclo -over "$MAX_COMPLEXITY" . 2>/dev/null || true)

  if [ -n "$COMPLEX" ]; then
    echo "WARNING: Functions exceeding complexity threshold:"
    echo "$COMPLEX"
    echo ""
    echo "Consider refactoring these functions."
    return 1
  else
    echo "OK - No functions exceed complexity $MAX_COMPLEXITY"
    return 0
  fi
}

check_duplication() {
  echo "=== Code Duplication Check: $SERVICE ==="
  echo "Checking for duplicated code blocks (threshold: $MIN_TOKENS tokens)..."

  if ! command -v dupl &> /dev/null; then
    echo "Installing dupl..."
    go install github.com/mibk/dupl@latest
  fi

  cd "$SERVICE_DIR"
  DUPES=$(dupl -threshold "$MIN_TOKENS" -plumbing . 2>/dev/null || true)

  if [ -n "$DUPES" ]; then
    echo "WARNING: Duplicated code detected:"
    dupl -threshold "$MIN_TOKENS" .
    echo ""
    echo "Consider extracting common code to reduce duplication."
    return 1
  else
    echo "OK - No significant code duplication found"
    return 0
  fi
}

cd "$(git rev-parse --show-toplevel)"

EXIT_CODE=0

case "$CHECK_TYPE" in
  complexity)
    check_complexity || EXIT_CODE=1
    ;;
  duplication)
    check_duplication || EXIT_CODE=1
    ;;
  all|*)
    check_complexity || EXIT_CODE=1
    echo ""
    check_duplication || EXIT_CODE=1
    ;;
esac

exit $EXIT_CODE
