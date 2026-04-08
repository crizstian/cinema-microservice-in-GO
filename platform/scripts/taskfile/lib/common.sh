#!/usr/bin/env bash
# Common functions for taskfile scripts
# Source this file: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# ============================================================
# COLORS AND FORMATTING
# ============================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================
# PATHS
# ============================================================

# Get the root directory of the project
get_project_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${script_dir}/../../../.."
}

PROJECT_ROOT="$(get_project_root)"
SCRIPTS_DIR="${PROJECT_ROOT}/platform/scripts/taskfile"
DOCKER_TESTING_DIR="${PROJECT_ROOT}/platform/docker/testing"
SERVICES_DIR="${PROJECT_ROOT}/services"
TEST_RESULTS_DIR="${PROJECT_ROOT}/tests/test-results"

# ============================================================
# SERVICE DISCOVERY
# ============================================================

# Get list of services that have go.mod
get_services() {
  find "${SERVICES_DIR}" -maxdepth 2 -name "go.mod" -exec dirname {} \; 2>/dev/null | \
    xargs -I{} basename {} | \
    tr '\n' ' ' | \
    sed 's/ $//'
}

# ============================================================
# TEST RESULT PARSING
# ============================================================

# Parse test output and return counts
# Usage: parse_test_results "$output"
# Sets: TEST_PASSED, TEST_FAILED, TEST_SKIPPED, TEST_TOTAL
parse_test_results() {
  local output="$1"
  # Match both top-level tests and subtests (subtests have leading whitespace)
  TEST_PASSED=$(echo "$output" | grep -cE "^\s*--- PASS" 2>/dev/null | tr -d '[:space:]') || TEST_PASSED=0
  TEST_FAILED=$(echo "$output" | grep -cE "^\s*--- FAIL" 2>/dev/null | tr -d '[:space:]') || TEST_FAILED=0
  TEST_SKIPPED=$(echo "$output" | grep -cE "^\s*--- SKIP" 2>/dev/null | tr -d '[:space:]') || TEST_SKIPPED=0
  TEST_TOTAL=$((TEST_PASSED + TEST_FAILED + TEST_SKIPPED))
}

# Get coverage percentage from coverage file
# Usage: get_coverage "path/to/coverage.out"
get_coverage() {
  local coverage_file="$1"
  go tool cover -func="$coverage_file" 2>/dev/null | grep total | awk '{print $3}' || echo "N/A"
}

# Determine test status string
# Usage: get_status_string $failed_count
get_status_string() {
  local failed="$1"
  if [ "$failed" -gt 0 ]; then
    echo "❌ FAIL"
  else
    echo "✅ PASS"
  fi
}

# Get coverage indicator emoji
# Usage: get_coverage_indicator "75.5%"
get_coverage_indicator() {
  local cov="$1"
  local cov_num
  cov_num=$(echo "$cov" | tr -d '%' 2>/dev/null) || cov_num=0

  if [ "$cov_num" = "N/A" ] 2>/dev/null; then
    echo "⚪"
  elif [ "${cov_num%.*}" -ge 70 ] 2>/dev/null; then
    echo "🟢"
  elif [ "${cov_num%.*}" -ge 50 ] 2>/dev/null; then
    echo "🟡"
  else
    echo "🔴"
  fi
}

# ============================================================
# DIRECTORY HELPERS
# ============================================================

# Ensure test-results directory exists
ensure_test_results_dir() {
  mkdir -p "${TEST_RESULTS_DIR}"
  mkdir -p "${TEST_RESULTS_DIR}/coverage"
}

# ============================================================
# DOCKER COMPOSE HELPERS
# ============================================================

readonly COMPOSE_FILE="${PROJECT_ROOT}/platform/deploy/docker-compose/docker-compose.yml"

docker_compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

# Wait for services to be healthy
# Usage: wait_for_services $count $timeout
wait_for_services() {
  local expected_count="${1:-8}"
  local timeout="${2:-90}"
  local profile="${ENV_PREFIX:-test}"

  for i in $(seq 1 "$timeout"); do
    local healthy
    healthy=$(docker_compose --profile "$profile" ps --format json 2>/dev/null | grep -c '"Health":"healthy"' || echo 0)
    if [ "$healthy" -ge "$expected_count" ]; then
      echo "  All $expected_count services healthy!"
      return 0
    fi
    printf "  %d/%d services healthy, waiting... (%d/%d)\r" "$healthy" "$expected_count" "$i" "$timeout"
    sleep 2
  done

  echo ""
  echo "  Services failed to become healthy"
  return 1
}

# ============================================================
# TIMING
# ============================================================

# Get current timestamp in seconds
now() {
  date +%s
}

# Calculate duration
# Usage: duration $start_time
duration() {
  local start="$1"
  local end
  end=$(now)
  echo $((end - start))
}
